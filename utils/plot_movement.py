import sys
import numpy as np

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
            pyplot.plot(d)
        axes.set_xlim(0,35) # remove axis padding
        axes.set_ylim(-2.5,2.5)
        axes.set_xticks(np.arange(0, 35, 1), minor=True)
        axes.set_yticks(np.arange(-2.5, 3, .5), minor=True)
        run_label = next(s for s in rdat.split('_') if s != patid)
        axes.set_ylabel(run_label)

    pyplot.yticks(np.arange(-2, 3, 1))
    pyplot.figlegend(['dx (mm)', 'dy (mm)', 'dz (mm)', 'rotx (deg)', 'roty (deg)', 'rotz (deg)'])
    pyplot.savefig('mvmt_per_frame_all_runs_plot.png')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        print('Usage: {} <patid>'.format(sys.argv[0]))

    plot_mvmt(sys.argv[1])
