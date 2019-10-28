import csv
import numpy as np
import re

from glob import glob
from matplotlib import pyplot as plt
from os.path import abspath, basename, join
from scipy.stats import binned_statistic

pdvars = 1

pdvars_label = '_pdvars' if pdvars else ''

EXCLUSIONS = ['MPD106_s1', 'MPD128_s1', 'MPD129_s1']

REGIONS = [ basename(roi).split('.')[0] for roi in glob('cbf/worse_side_L/voi_analysis/*.4dfp.img') ]

#bins = np.arange(-20, 92, 2)
#bins = np.array([-30] + list(range(0, 30, 2)) + list(range(30, 95, 5)))
bins = np.array([-30, 0, 4] + list(range(6, 20, 2)) + list(range(20, 95, 5))) # bin 0-4 minutes + start 5-minute bins at 20 min (email 1/11)
for region in REGIONS:
	if 'midbrain_roi_0p05' in region:
		y_lims = (46, 56)
	elif 'midbrain' in region:
		y_lims = (30, 50)
	else:
		y_lims = (35, 65)

	patids = [ basename(abspath(d)) for d in glob('MPD*_s1/') ]
	
	means = []
	stds = []

	x = []
	y = []
	for patid in patids:
		if patid in EXCLUSIONS:
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
	
	with open('binned_average_tac_{}.csv'.format(region), 'w') as f:
		writer = csv.writer(f)
		writer.writerow(['mean_bin_time', 'mean_roi_val', 'std_roi_val', 'n'])
		writer.writerows(zip(means_x, means_y, stds_y, counts_y))

	marker_sizes = [ 2000* (n / sum(counts_y)) for n in counts_y ]

	plt.figure(figsize=(10,4))

	plt.scatter(means_x, means_y, s=marker_sizes, alpha=.5)
	plt.axhline(means_y[0], color='gray')
	#plt.errorbar(means_x, means_y, yerr=stds_y, capsize=2)

	plt.xlabel('Minutes since infusion')
	plt.xlim(-20,90)
	plt.ylim(y_lims[0], y_lims[1])
	plt.ylabel('rCBF')
	plt.title('Average {} TAC'.format(region))
	plt.savefig('binned_average_{}_tac_moco.png'.format(region))
