import sys
import numpy as np

import matplotlib
matplotlib.use('Qt4Agg') # must be set prior to pyplot import
from matplotlib import pyplot

from os import chdir, getcwd, listdir
from os.path import join


def plot_mvmt(patid):
    rdat_files = [ f for f in listdir(getcwd()) if f.endswith('.rdat') ]
    rdat_files.sort() # put them in order of asl runs (1-7)

    figure, axes = pyplot.subplots(len(rdat_files), sharex=True, sharey=True, figsize=(12.8,9.6))
    figure.suptitle('Movement per frame per run')

    for i, rdat in enumerate(rdat_files):
        data = [ [] for _ in range(6) ]
        with open(rdat, 'r') as f:
            for line in f:
                if line.startswith('#'):
                    continue

                frame_data = line.split()
                for j in range(6):
                    data[j].append(float(frame_data[j+1]))

        for d in data:
            axes[i].plot(d)
            axes[i].set_xlim(0,35) # remove axis padding
            axes[i].set_ylim(-2.5,2.5)
            axes[i].set_xticks(np.arange(0, 35, 1), minor=True)
            axes[i].set_yticks(np.arange(-2.5, 3, .5), minor=True)
            axes[i].set_ylabel('asl' + str(i+1))

    pyplot.yticks(np.arange(-2, 3, 1))
    pyplot.figlegend(['dx (mm)', 'dy (mm)', 'dz (mm)', 'rotx (deg)', 'roty (deg)', 'rotz (deg)'])
    pyplot.savefig('mvmt_per_frame_all_runs_plot.png')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        print('Usage: {} <patid>'.format(sys.argv[0]))

    plot_mvmt(sys.argv[1])
