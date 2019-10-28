from subprocess import call
from cycler import cycler
from pcasl_cbf import get_num_frames
import argparse
import re
import matplotlib
matplotlib.use('Qt4Agg') # must be set prior to pyplot import
from matplotlib import pyplot
import numpy as np
from os import chdir, getcwd, listdir, remove
from os.path import join, exists

PROJECT_DIR = '/net/zfs-black/BLACK/black/MPDP'

def make_per_run_histograms(patids):
    colors = pyplot.rcParams['axes.prop_cycle'].by_key()['color']
    pyplot.rc('axes', prop_cycle=(cycler('linestyle', ['-', ':']) * cycler('color', colors)))

    for patid in patids:
        chdir(join(PROJECT_DIR, patid))
        asl_runs = [ d for d in listdir(getcwd()) if d.startswith('asl') ]
        asl_runs.sort()

        for run in asl_runs:
            chdir(run)

            hist_img = '_'.join([patid, run, 'per-frame_histogram_shifted.png'])
            # if exists(hist_img):
            #     chdir('..')
            #     continue

            img = '_'.join([patid, 'a' + run[-1], 'xr3d_atl_brainmasked_cbf_shifted_msk'])

            num_frames = get_num_frames(img + '.4dfp.ifh')
            frames = range(1, num_frames+1)
            for i in frames:
                hist_file = '.'.join([img + '_vol' + str(i), 'hist'])
                call(['img_hist_4dfp', img, '-h', '-r-61to121', '-b183', '-m../atlas/' + patid +'_asl_xr3d_atl_dfndm.4dfp.img', '-f' + str(i)])

                data = [ [], [] ]
                with open(hist_file, 'r') as f:
                    for line in f:
                        if line.startswith('#'):
                            continue

                        line_arr = line.split()
                        data[0].append(float(line_arr[0]))
                        data[1].append(float(line_arr[1]))

                pyplot.plot(data[0], data[1])
                remove(hist_file)

            pyplot.xlim(-60,120) # remove axis padding
            pyplot.ylim(0,2000) # remove axis padding
            pyplot.figlegend(['frame' + str(i) for i in frames])
            pyplot.show()
            #pyplot.savefig('_'.join([patid, run, 'per-frame_histogram_shifted.png']))
            pyplot.close()
            chdir('..')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='plot intensity histogram for each aslrun')
    parser.add_argument('-p', '--patids', nargs='+', help='limit plot to certain participants (default is to include all)')
    args = parser.parse_args()

    patids = args.patids if args.patids else [ d for d in listdir(PROJECT_DIR) if re.match('MPD\d{3}', d) ]

    make_per_run_histograms(patids)
