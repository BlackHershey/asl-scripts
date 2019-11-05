import argparse
import re
import matplotlib.pyplot as plt

from cycler import cycler
from image_utils import get_num_frames
import numpy as np
from os import chdir, getcwd, remove
from os.path import exists, split, basename
from subprocess import call


def read_hist_file(hist_file):
    data = [ [], [] ]
    with open(hist_file, 'r') as f:
        for line in f:
            if line.startswith('#'):
                continue

            line_arr = line.split()
            data[0].append(float(line_arr[0]))
            data[1].append(float(line_arr[1]))
    return data


def make_all_runs_histograms(imgs, mask, redo):
    asl_runs = []
    img_root = ''
    for img in imgs:
        directory, filename = split(img)
        asl_runs.append(basename(directory))

        chdir(directory) # change to current image's directory

        img_root = filename.split('.')[0]
        hist_file = '.'.join([img_root, 'hist'])
        if redo or not exists(hist_file):
            mask_str = '-m' + mask if mask else ''
            call(['img_hist_4dfp', filename, '-h', '-r-61to121', '-b183', mask_str])

        data = read_hist_file(hist_file)
        plt.plot(data[0], data[1])

        chdir('..')

    plt.xlim(-60,120) # remove axis padding
    plt.figlegend(asl_runs)
    plt.savefig(re.sub('a\d', 'asl', img_root) + '_histogram.png')
    plt.close()


def make_per_run_histograms(imgs, mask, redo):
    initial_dir = getcwd()

    for img in imgs:
        directory, filename = split(img)
        chdir(directory) # change to current image's directory

        img_root = filename.split('.')[0]
        hist_img = '_'.join([img_root, 'histogram.png'])
        if not redo and exists(hist_img):
            chdir(initial_dir)
            continue

        num_frames = get_num_frames(img_root + '.4dfp.ifh')
        frames = range(1, num_frames+1)
        for i in frames:
            hist_file = '.'.join([img_root + '_vol' + str(i), 'hist'])
            mask_str = '-m' + mask if mask else ''
            call(['img_hist_4dfp', img_root, '-h', '-r-61to121', '-b183', '-f' + str(i), mask_str])

            data = read_hist_file(hist_file)
            plt.plot(data[0], data[1])

            remove(hist_file)

        plt.xlim(-50,100) # remove axis padding
        plt.ylim(0,2000) # remove axis padding
        plt.figlegend(['frame' + str(i) for i in frames])
        plt.savefig(hist_img)
        plt.close()
        chdir(initial_dir)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='plot intensity histogram for each aslrun')
    parser.add_argument('images', metavar='image', nargs='+', help='list of images to create histograms for')
    parser.add_argument('-m', '--mask')
    parser.add_argument('-r', '--redo', nargs='?', type=int, choices=[0,1], const=1, default=0)
    args = parser.parse_args()

    colors = plt.rcParams['axes.prop_cycle'].by_key()['color']
    plt.rc('axes', prop_cycle=(cycler('linestyle', ['-', ':']) * cycler('color', colors)))

    make_all_runs_histograms(args.images, args.mask, args.redo)
    make_per_run_histograms(args.images, args.mask, args.redo)
