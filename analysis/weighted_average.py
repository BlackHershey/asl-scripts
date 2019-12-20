import argparse
import nibabel as nib
import numpy as np
import os

from subprocess import call

PDVARS_DAT = 'movement/pdvars.dat'


def calc_weights(datfile, outroot, fmtstr=None):
	measures = np.genfromtxt(datfile, usecols=0)
	measures[measures == 500] = np.inf

	if fmtstr:
		exclude_idx = [ i for i, c in enumerate(fmtstr) if c == 'x' ]
		measures[exclude_idx] = np.inf

	print(measures)

	c = sum(1. / measures)
	weights = (c / measures)
	weights /= sum(weights)

	print(weights)
	weights_file = 'movement/{}_weights.txt'.format(outroot)
	np.savetxt(weights_file, weights)

	return weights, weights_file


def gen_weighted_average(infile, datfile=PDVARS_DAT, trailer=None, fmtstr=None):
	outroot = os.path.basename(infile).split('.')[0]
	if trailer:
		outroot = outroot + '_' + trailer

	weights, weights_file = calc_weights(datfile, outroot, fmtstr)

	if not fmtstr:
		fmtstr = '{}+'.format(len(weights))

	scaleby = np.count_nonzero(weights)
	cmd = ['actmapf_4dfp', '-a{}avg_moco_wt'.format(trailer + '_' if trailer else ''), '-w' + weights_file, '-c' + str(scaleby), fmtstr, infile]
	print(' '.join(cmd))
	call(cmd)


if __name__ == '__main__':
	parser = argparse.ArgumentParser()
	parser.add_argument('img', help='single run 4dfp image or conc file') # FIXME: figure out if it makes sense to allow single 4dfp image given datfile issue
	parser.add_argument('--datfile', default=PDVARS_DAT)
	parser.add_argument('--trailer', help='label to append to output file names')
	parser.add_argument('--fmtstr', help='expanded format str')
	args = parser.parse_args()

	gen_weighted_average(args.img, args.datfile, args.trailer, args.fmtstr)
