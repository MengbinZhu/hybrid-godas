#!/bin/bash
# MOM6-GODAS data assimilation cycle script
set -e

# setup environemnt
if [ -z "${MOAB_SUBMITDIR}" ]; then
    exp_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
else
    exp_dir=$MOAB_SUBMITDIR
fi
source $exp_dir/config/config.DAcycle
cd $exp_dir


# get the date we are about to start from
# note that that forecast could have finished, but the 
# DA might not have, so pick up from the appropriate place
if [ ! -f "last_date_fcst" ]; then 
    echo "$date_start" > last_date_fcst 
    echo "$date_start" > last_date_da
fi
last_date_fcst=$(cat last_date_fcst)
last_date_da=$(cat last_date_da)
if [ $(date -d $last_date_fcst +%s) -gt $(date -d $last_date_da +%s) ]; then
    date_cur=$last_date_da
else
    date_cur=$last_date_fcst
fi
echo "Resuming experiment from $date_cur"


# if the user is running this from the command line, submit the job to MOAB and quit
function submitJob()
{
    echo "Submitting job to MOAB..."
    echo "  account: $moab_acct"
    echo "  nodes:   $moab_nodes"
    echo "  runtime: $moab_walltime"
    echo "  queue:   $moab_queue"    
    cd $exp_dir
    msub $exp_dir/run_DAcycle.sh -N MOM6_GODAS_DACYCLE -E -A $moab_acct -l partition=c3,nodes=$moab_nodes,walltime=$moab_walltime -q $moab_queue -j oe -o $exp_dir/logs/dacycle_$date_cur.log -d $exp_dir
}
if [ -z "${MOAB_JOBNAME}" ]; then
    submitJob
    exit
fi


# otherwise, this is a job running under MOAB, continue with the da cycle
#------------------------------------------------------------

# run the forecast
if [ $(date +%s -d $last_date_fcst) -eq $(date +%s -d $date_cur) ]; then
    fcst_start=$date_cur
    fcst_len=$da_interval
    fcst_out_interval=1
    fcst_out_da=1
    fcst_out_dir=$exp_dir/bkg/
    (. $root_dir/run/subscripts/run_fcst.sh)
fi


# run the DA step
t=$(($da_interval-1))
date_ana=$(date "+%Y%m%d" -d "$date_cur + $t day")
date_obs_end=$date_ana
date_obs_start=$date_cur
(. $root_dir/run/subscripts/run_da.sh)

cp last_date_fcst last_date_da

# submit another job if we aren't done yet
date_cur=$(date "+%Y-%m-%d" -d "$date_cur + $da_interval day")
if [ $(date +%s -d $date_cur) -le $(date +%s -d $date_end) ]; then submitJob; fi