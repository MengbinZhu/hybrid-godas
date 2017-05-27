#!/bin/bash
# TODO, list the env vars it is expecting

# required environment variables
#------------------------------------------------------------
# root_dir            =
# work_dir            =
# exp_dir             =
#
# fcst_start          = start date of forecast (YYYY-MM-DD), hour is assumed to be 00Z
# fcst_len            = length of forecast in days
# fcst_out_interval   = 
# fcst_out_da         =
# fcst_out_dir


echo ""
echo "============================================================"
echo "   Running MOM6 forecast..."
echo "============================================================"

# check required environment variables
envvars="root_dir work_dir exp_dir fcst_start fcst_len fcst_out_interval fcst_out_da fcst_out_dir"
for v in ${envvars}; do
    if [ -z "${!v}" ]; then echo "ERROR: env var $v not set."; exit 1; fi
    echo "  $v = ${!v}"
done
echo ""

# setup the environment
. $root_dir/config/env


# are we running a restart?
restart="r"
if [ ! -d "$exp_dir/RESTART" ]; then
    echo "Initializing NEW experiment without restart on $fcst_start"
    restart="n"
fi


# what are the dates we are running
fcst_end=$(date "+%Y-%m-%d" -d "$fcst_start + $fcst_len day")
echo "Running forecast from $fcst_start 00Z to $fcst_end 00Z"


# Setup the working directory
#------------------------------------------------------------
work_dir=$work_dir/fcst
rm -rf $work_dir
mkdir -p $work_dir
cd $work_dir
mkdir -p OUTPUT
mkdir -p RESTART
ln -s $root_dir/build/MOM6 .

# namelist files
cp $exp_dir/config/mom/* .
. ./input.nml.sh > input.nml

# static input files
mkdir -p INPUT
ln -s $root_dir/run/config/mom_input/* INPUT/

# restart files
if [ "$restart" = 'r' ]; then
    ln -s $exp_dir/RESTART/* INPUT/
fi

# Prepare the forcing files
mkdir -p FORC
cd FORC
(. $root_dir/tools/prep_forcing.sh $fcst_start $fcst_end)
cd ..


# run the forecast
#------------------------------------------------------------
aprun -n $PBS_NP MOM6


# Move the output files
#------------------------------------------------------------
fdate=$(date "+%Y%m%d" -d "$fcst_end - 1 day")
while [ $(date -d $fdate +%s) -ge $(date -d $fcst_start +%s) ]
do
    out_dir=$(date -d $fdate "+$fcst_out_dir")
    mkdir -p $out_dir
    pfx=$work_dir/$(date "+%Y%m%d" -d "$fcst_start")
    
    src_file=$pfx.ocean_daily_$(date "+%Y_%m_%d" -d "$fdate").nc
    dst_file=$out_dir/$(date "+%Y%m%d" -d "$fdate").nc
    mv $src_file $dst_file

    if [ $fcst_out_da = "1" ]; then
	src_file=$pfx.ocean_daily_da_$(date "+%Y_%m_%d" -d "$fdate").nc
	dst_file=$out_dir/$(date "+%Y%m%d" -d "$fdate")_da.nc
	mv $src_file $dst_file
    fi

    fdate=$(date "+%Y%m%d" -d "$fdate - $fcst_out_interval day")
done

# move the restart files
rm -rf $exp_dir/RESTART_old
if [ -d $exp_dir/RESTART ]; then mv $exp_dir/RESTART $exp_dir/RESTART_old; fi
mv $work_dir/RESTART $exp_dir/RESTART


# update the "last_date" file
echo $fcst_end > $exp_dir/last_date_fcst

# clean up working directory
rm -rf $work_dir