import argparse
import csv
import numpy as np
import sys

from matplotlib import pyplot as plt
from os.path import basename, exists, join, splitext
from subprocess import call

DEFAULT_TIMING_FILE = 'cbf_pair_times.csv'

def extract_col(filename, col, delimiter=None):
	l = []
	with open(filename, 'r') as f:
		next(f) # skip header line
		for line in f:
			if not line.startswith('#'):
				l.append(float(line.split(delimiter)[col]))
	return np.array(l)


def get_aberrant_frames(fmtfile):
	fmt = open(join('movement', fmtfile)).readlines()[0]
	return [ i for i, char in enumerate(fmt) if char == '+' ]


def time_activity_curve(img, roi, roi_label, ax, timing_file=DEFAULT_TIMING_FILE, pdvars=False, sleep=False, avg_overlay=False, write_csv=True, dat_file=None, save=True):
	if not dat_file:
		dat_file = '_'.join([splitext(basename(img))[0], roi_label]) + '.dat' # remove ".4dfp.img" or ".conc" extension and replace with ".dat"
		if not exists(dat_file) or True:
			with open(dat_file, 'wb') as f:
				call(['qnt_4dfp', img, roi, '-s'], stdout=f)
	patid = dat_file[:9]

	asl_run = extract_col(timing_file, 1, ',')
	x = extract_col(timing_file, 4, ',')
	y = extract_col(dat_file, 1)
	pdvars_vals = [ float(line.split('\t')[0]) for line in open(join('movement', 'pdvars.dat')).readlines() ]

	x_ab, y_ab = [], []
	if pdvars or sleep:
		fmtfile = 'pdvars.format' if pdvars else 'sleep.format'
		fmt = open(join('movement', fmtfile)).readlines()[0]
		normal_frames = [ i for i, char in enumerate(fmt) if char == '+' ]
		aberrant_frames = [ i for i in range(len(fmt)) if i not in normal_frames ]

		x_ab = x[aberrant_frames]
		x = x[normal_frames]
		y_ab = y[aberrant_frames]
		y = y[normal_frames]
		asl_run_ab = asl_run[aberrant_frames]
		asl_run = asl_run[normal_frames]

	print(np.where(asl_run==1))
	print(y)
	predrug_mean = np.average(y[np.where(asl_run==1)])
	run_idx = np.where(asl_run[:-1] != asl_run[1:])[0] + 1 # get indices where new runs start
	run_midpt = [ np.median(l) for l in np.split(x, run_idx) ] # can't call median directly b/c np doesn't like sublists of different lengths
	run_avg = [ np.mean(l) for l in np.split(y, run_idx) ] # ditto for mean

	plt.axhline(predrug_mean, color='gray')

	if x_ab != [] and y_ab != []:
		ax.plot(x_ab, y_ab, 'o', color='gray', markerfacecolor='white', markersize=5)

	ax.plot(x, y, 'o--', linewidth=.5, markerfacecolor='white', markersize=5)

	if avg_overlay:
		plt.plot(run_midpt, run_avg, '-o', markersize=4)

	ax.set_xlim(-30,120)
	ax.set_ylim(0,100)
	ax.set_title('{} rCBF for {}'.format(roi_label, patid))
	ax.set_xlabel('Minutes since infusion')

	if save:
		if pdvars:
			trailer = '_pdvars'
		elif sleep:
			trailer = '_sleep'
		else:
			trailer = ''

		tac_root = '{}_{}_tac{}'.format(patid, roi_label, trailer)
		plt.savefig(tac_root + '.png')
		with open(tac_root + '.csv', 'w') as f:
			writer = csv.writer(f)
			writer.writerow(['patid', 'min_since_infusion', roi_label + '_rCBF', 'pdvars'])
			for time, r_cbf, mvmt in zip(x,y, pdvars_vals):
				writer.writerow([patid, time, r_cbf, mvmt])
	return


if __name__ == '__main__':
	parser = argparse.ArgumentParser()
	parser.add_argument('img_file', help='4dfp or conc input file')
	parser.add_argument('roi_img')
	parser.add_argument('roi_label', help='roi name for y axis label')
	parser.add_argument('-t', '--timing_file', default=DEFAULT_TIMING_FILE, help='optionally supplied pair timing file (default is cbf_pair_times.csv')
	parser.add_argument('-p', '--pdvars', action='store_true', help='remove pdvars frames according to fmtfile')
	parser.add_argument('-s', '--sleep', action='store_true', help='plot asleep frames separately (according to movement/sleep.format)')
	parser.add_argument('-a', '--avg_overlay', action='store_true', help='overlay run averages over framewise timecourse')
	parser.add_argument('--save', action='store_true', help='save graphs and CSVs')
	args = parser.parse_args()

	fig, ax = plt.subplots()
	time_activity_curve(args.img_file, args.roi_img, args.roi_label, ax, args.timing_file, args.pdvars, args.sleep, args.avg_overlay, args.save)
