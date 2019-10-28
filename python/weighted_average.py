import argparse
import nibabel as nib
import numpy as np
from subprocess import call

def calc_weights(datfile, fmtstr=None):
	measures = np.genfromtxt(datfile)
	measures[measures == 500] = np.inf

	if fmtstr:
		exclude_idx = [ i for i, c in enumerate(fmtstr) if c == 'x' ]
		measures[exclude_idx] = np.inf

	c = sum(1. / measures)
	weights = (c / measures)
	weights /= sum(weights)

	return weights


def calc_weighted_average(images, datfile, outroot, fmtstr=None):
	weights = calc_weights(datfile, fmtstr)
	weights_file = 'movement/{}_weights.txt'.format(outroot)
	np.savetxt(weights_file, weights)

	if not fmtstr:
		fmtstr = '{}+'.format(len(weights))

	if len(images) > 1:
		call(['conc_4dfp', '-w', outroot] + images)
		infile = outroot + '.conc'
	else:
		infile = images[0]

	scaleby = np.count_nonzero(weights)
	cmd = ['actmapf_4dfp', '-aavg_moco_wt', '-w' + weights_file, '-c' + str(scaleby), fmtstr, infile]
	print(' '.join(cmd))
	call(cmd)


if __name__ == '__main__':
	parser = argparse.ArgumentParser(description='')
	parser.add_argument('--images', nargs='+', required=True)
	parser.add_argument('--datfile', required=True)
	parser.add_argument('--outroot', required=True)
	parser.add_argument('--fmtstr')
	args = parser.parse_args()

	calc_weighted_average(args.images, args.datfile, args.outroot, args.fmtstr)
