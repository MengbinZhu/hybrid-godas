#!/usr/bin/env python3
import omf
from multiprocessing import Pool
import os
import numpy as np
import bisect
import math
import netCDF4 as nc

cwd=os.path.dirname(os.path.realpath(__file__))
vtgrid_file=cwd+"/../../DATA/grid/Vertical_coordinate.nc"
lvls=nc.Dataset(vtgrid_file, 'r').variables["Layer"][:]

def smooth(counts, vals):
    smooth_w = args.smooth
    wndw=np.zeros(smooth_w*2 + 1)
    for i in range(len(wndw)):
        wndw[i] = (smooth_w+1-abs(i-smooth_w))/(smooth_w+1)

    newVals = np.copy(vals)
    for i in range(vals.size):
        w = 0.0
        v = 0.0
        for j in range(len(wndw)):
            k=i+j-smooth_w
            if k < 0 or k >= vals.size:
                continue
            w += counts[k]*wndw[j]
            v += vals[k]*counts[k]*wndw[j]
        newVals[i] = v*1.0/w
    return newVals


def processExp(e):
    data=[]
    for d in plotTypes:
        d2={
            "count"     : np.zeros(lvls.shape),
            "inc_mean"  : np.zeros(lvls.shape),
            "inc_mean2" : np.zeros(lvls.shape),
            "inc_sprd2" : np.zeros(lvls.shape),
            "val"       : np.zeros(lvls.shape),
            "err"       : np.zeros(lvls.shape)}
        data.append(d2)


    for f in e:
        omfs,mem = omf.read(f)
        
        # a correction to the RMSE for standard deviation
        c=(mem+1.0)/mem

        # mask the omfs by region / qc / obs type
        masks={}
        for m in omf.masks:
            masks[m] = omf.masks[m](omfs)

        m_valid = masks['q_valid']
        m_depth = np.logical_and (omfs.depth >= args.mindepth, omfs.depth <= args.maxdepth)
        m_hr = np.logical_and(omfs.hr >= args.hr[0], omfs.hr <= args.hr[1])
        if args.plat is not None:
             m_plat = omfs.plat == args.plat
        else:
            m_plat = omfs.plat > 0

        cnt=-1
        for p in plotTypes:
            cnt+=1

            mask=None
            for m in p['masks']:
                mask = masks[m] if mask is None else (mask & masks[m])
            obs = omfs[ m_valid & mask & m_depth & m_hr & m_plat]


            for d,v,e,i_m,i_s in zip(
                    obs.depth.values, obs.val.values,
                    obs.err.values, obs.inc_mean.values, obs.inc_sprd.values):
                idx=bisect.bisect_left(lvls, d)

                count=data[cnt]['count'][idx]+1
                data[cnt]['count'][idx] = count
                data[cnt]['inc_mean'][idx]  += (i_m    - data[cnt]['inc_mean'][idx])/count
                data[cnt]['inc_mean2'][idx] += (i_m**2 - data[cnt]['inc_mean2'][idx])/count
                data[cnt]['inc_sprd2'][idx] += (c*i_s**2 - data[cnt]['inc_sprd2'][idx])/count
                data[cnt]['val'][idx] += (v - data[cnt]['val'][idx])/count
    return data
 


if __name__=="__main__":
    import argparse
    from glob import glob
    import matplotlib
    matplotlib.use('agg')
    import matplotlib.pyplot as plt

    # read in command line arguments
    parser = argparse.ArgumentParser(description=(
        "Process ensemble Observation minus Forecast (OmF) statistics "
        "as regionally binned profiles"))
    parser.add_argument('path', nargs="+", help=(
        "path to one or more experiment directories"))
    parser.add_argument('-mindepth', type=float, default='5', help=(
        "minimum profile depth (Default %(default)s)"))
    parser.add_argument('-maxdepth', type=float, default='500', help=(
        "maximum plot depth (Default %(default)s)"))
    parser.add_argument('-start', default="00000000", help=(
        "start date in YYYYMMDD format"))
    parser.add_argument('-end', default="99999999", help=(
        "end date in YYYYMMDD format"))
    parser.add_argument('-hr',nargs=2,type=int,default=(-9e10,9e10))
    parser.add_argument('-out', default="./omf_profile", help=(
        "output directory for generated plots (Default: %(default)s)"))
    parser.add_argument('-label', help=(
        "A comma separated list of labels to use for the plot lines"))
    parser.add_argument('-threads', type=int, default=4, help=(
        "number of threads to use when reading input files. (Default: %(default)s)"))
    parser.add_argument('-smooth', type=int, default=2, help=(
        "size of half width of window used in weighted smoothing of profile"))
    parser.add_argument('-plat',type=int)

    args = parser.parse_args()
    args.path = [os.path.abspath(p) for p in args.path]
    if args.label is not None:
        args.label = args.label.split(',')
    else:
        args.label = [p.split('/')[-1] for p in args.path]
    print(args)

    # configure the plot types
    plotTypes=[]
    for r in omf.region_list:
        for v in ( ('insitu-temp', 'insitu T', 'o_temp'),
                   ('insitu-salt', 'insitu S', 'o_salt')):
            plotTypes.append( {
                'title' : v[1] + ' ('+r[1]+')',
                'masks' : (v[2],) + r[2],
                'fn'    : '{0}/#p#/#p#_{0}_{1}'.format(v[0],r[0])})
            
    # get a list of files for each experiment, and the overlapping set of dates
    efiles=[]
    validDates=None
    for exp in args.path:
        # get list of files, keeping only those within the date range
        files = glob(exp + '/output/omf/????/*.nc')
        files = sorted([f for f in files if args.start <= f.split('/')[-1][:8] <= args.end])
        efiles.append(files)
        dates = set([f.split('/')[-1][:8] for f in files])
        validDates = dates if (validDates is None) else validDates.intersection(dates)
    print("Using overlapping dates {} to {}".format(min(validDates), max(validDates)))

    # only keep the overlapping dates
    for idx, exp in enumerate(efiles):
        efiles[idx] = [f for f in exp if f.split('/')[-1][:8] in validDates]

    # sanity check to make sure each experiment will plot the same number of files
    for e in efiles:
        if len(e) != len(efiles[0]):
            print("number of files to plot does not match for all experiments")
            sys.exit(1)

    # process all the experiment files
    pool = Pool(args.threads)
    allData=pool.map(processExp, efiles)
    pool.close()
    pool.join()


    # plot the plots
    cnt=-1
    for p in plotTypes:
        cnt+=1
        for p2 in ('bias','rmsd'):
            filename=args.out+'/'+p['fn'].replace('#p#',p2)+'.png'
            dirname=os.path.dirname(filename)
            if not os.path.exists(dirname):
                os.makedirs(dirname)
            print(filename)

            plt.figure(figsize=(4.5,9))
            plt.title('{} {}'.format(p2, p['title']))
            plt.gca().grid(True)
            plt.ylim(args.maxdepth, 0)

            enum=-1
            for e in args.path:
                enum+=1
                data=allData[enum][cnt]
                if p2 == 'rmsd':
                    plt.plot(np.sqrt(smooth(data['count'],data['inc_mean2'])), 
                             lvls, 'C{}'.format(enum),label=args.label[enum])
                    plt.plot(np.sqrt(smooth(data['count'],data['inc_sprd2'])),
                             lvls, 'C{}'.format(enum), ls='--')
                    plt.axvline(x=0.0, color='black')
                elif p2 == 'bias':
                    plt.plot(smooth(data['count'],data['inc_mean']), lvls, 'C{}'.format(enum))
                    plt.axvline(x=0.0, color='black')


            plt.annotate('profiles: {}'.format(int(np.max(allData[0][cnt]['count']))),
                         xy=(6,30), xycoords='figure points')
            plt.annotate("{} to {}".format(min(validDates), max(validDates)), xy=(300,30),
                         xycoords='figure points', horizontalalignment='right')


            plt.legend()
            plt.savefig(filename)
            plt.close('all')
