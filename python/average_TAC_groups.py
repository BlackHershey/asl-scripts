import argparse
import csv
import numpy as np
import pandas as pd
import re

from glob import glob
from matplotlib import pyplot as plt
from os.path import abspath, basename, join
from scipy.stats import binned_statistic

pdvars = 1
outdir = '/net/zfs-black/BLACK/black/MPDP/fnirt_sym/cbf/worse_side_L/voi_analysis'

parser = argparse.ArgumentParser()
parser.add_argument('grouping_file')
args = parser.parse_args()

df = pd.read_csv(args.grouping_file, usecols=[0,2], names=['patid', 'group'], header=0)
print(df)

pdvars_label = '_pdvars' if pdvars else ''


REGIONS = [ basename(roi).split('.')[0] for roi in glob(join(outdir, 'ldopa*.4dfp.img')) ]

#bins = np.arange(-20, 92, 2)
#bins = np.array([-30] + list(range(0, 30, 2)) + list(range(30, 95, 5)))
bins = np.array([-30, 0, 4] + list(range(6, 20, 2)) + list(range(20, 95, 5))) # bin 0-4 minutes + start 5-minute bins at 20 min (email 1/11)
for region in REGIONS:
	print(region)

	if 'midbrain_roi_0p05' in region:
		y_lims = (45, 60)
	elif 'midbrain' in region:
		y_lims = (30, 50)
	else:
		y_lims = (35, 65)

	figure, axes = plt.subplots(nrows=3, ncols=1, figsize=(11,8), sharex=True, sharey=True)
	for i, group in enumerate(df.groupby('group', sort=False)):
		g, data = group

		means = []
		stds = []

		x = []
		y = []
		for idx, row in data.iterrows():
			patid = row['patid']
	
			if patid == 'MPD106_s1':
				continue

			tac_file = join(patid, '{}_{}_tac{}.csv'.format(patid, region, pdvars_label))
			x1, y1 = np.genfromtxt(tac_file, delimiter=',', usecols=(1,2), skip_header=1, unpack=True).tolist()

			fmt = open(join(patid, 'movement', 'pdvars.format')).readlines()[0]
			x1, y1 = zip(*[ (val[0], val[1]) for i, val in enumerate(zip(x1, y1)) if fmt[i] != 'x' ])

			x += x1
			y += y1

		means_x = binned_statistic(x, x, statistic='mean', bins=bins).statistic
		means_y = binned_statistic(x, y, statistic='mean', bins=bins).statistic
		counts_y = binned_statistic(x, y, statistic='count', bins=bins).statistic
		stds_y = binned_statistic(x, y, statistic=lambda x: np.std(x), bins=bins).statistic
	
		with open(join(outdir, 'binned_average_tac_{}_group{}.csv'.format(region, g)), 'w') as f:
			writer = csv.writer(f)
			writer.writerow(['mean_bin_time', 'mean_roi_val', 'std_roi_val', 'n'])
			writer.writerows(zip(means_x, means_y, stds_y, counts_y))

		marker_sizes = [ 2000* (n / sum(counts_y)) for n in counts_y ]

		axes[i].scatter(means_x, means_y, s=marker_sizes, alpha=.5)
		axes[i].set_title('UPDRS ' + g)
		axes[i].axhline(means_y[0])
		axes[i].set_ylabel('rCBF')

	#plt.errorbar(means_x, means_y, yerr=stds_y, capsize=2)

	plt.xlabel('Minutes since infusion')
	plt.xlim(-20,90)
	plt.ylim(y_lims[0], y_lims[1])
	#plt.show()
	plt.savefig(join(outdir, 'grouped_binned_average_{}_tac_moco.png'.format(region)))








