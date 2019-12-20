from subprocess import Popen, PIPE
import argparse
import csv
import re
import matplotlib
matplotlib.use('Qt4Agg') # must be set prior to pyplot import
from matplotlib import pyplot
import numpy as np
from os import chdir, getcwd, listdir
from os.path import join, exists

PROJECT_DIR = '/net/zfs-black/BLACK/black/MPDP'
SCRIPT_DIR = '/net/zfs-black/BLACK/black/git/asl-scripts'

def plot_mvmt_vs_cbf(patids):
    mvmt_avgs = []
    cbf_avgs = []

    for patid in patids:
        chdir(join(PROJECT_DIR, patid))

        asl_runs = []
        with open('avg_global_numbers.csv', 'rb') as f:
            reader = csv.reader(f)
            next(reader) # skip header row
            for row in reader:
                asl_runs.append(row[1])
                cbf_avgs.append(float(row[2]))

        chdir('movement')
        asl_runs_options = '(' + '|'.join(asl_runs) + ')'
        rdat_files = [ f for f in listdir(getcwd()) if re.match(patid + '_a' + asl_runs_options + '_xr3d.rdat$', f) ]
        rdat_files.sort() # put them in order of asl runs (1-7)

        for rdat in rdat_files:
            p = Popen(['tail', '-1', rdat], stdout=PIPE)
            last_line = p.communicate()[0] # get stdout from call to tail
            mvmt_avgs.append(float(last_line.split()[-1])) # avg mvmt measure is last item in line

    pyplot.scatter(mvmt_avgs, cbf_avgs)
    pyplot.plot(np.unique(mvmt_avgs), np.poly1d(np.polyfit(mvmt_avgs, cbf_avgs, 1))(np.unique(mvmt_avgs)))
    pyplot.xlabel('Overall movement (per run)')
    pyplot.ylabel('gCBF mode (per run)')
    print('r = {}'.format(np.corrcoef(mvmt_avgs, cbf_avgs)[1,0]))
    chdir(PROJECT_DIR)
    pyplot.savefig('mvmt_vs_cbf.png')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='plot movement data against global cbf value for each run')
    parser.add_argument('-i', '--include', nargs='+', help='limit plot to certain participants (default is to include all)')
    args = parser.parse_args()

    patids = args.include if args.include else [ d for d in listdir(PROJECT_DIR) if re.match('MPD\d{3}', d) ]
    plot_mvmt_vs_cbf(patids)
