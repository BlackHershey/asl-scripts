import argparse
import csv
import glob
import matplotlib as mpl
import matplotlib.pyplot as plt
import nibabel as nb
import numpy as np
import re
import seaborn as sns

from os import chdir

parser = argparse.ArgumentParser()
parser.add_argument('study_dir')
parser.add_argument('-p', '--plot_params', nargs='+')
parser.add_argument('-l', '--log_scale', action='store_true')
parser.add_argument('-z', '--zoom', action='store_true')
args = parser.parse_args()



chdir(args.study_dir)

peak_images = glob.glob('effect*/images/*Peak*4dfp.img')

inputs = {
	'worst': {
		'ke': np.log(2) / 5,
		'thalfeq': 5,
		'EC50': 1200,
		'n': 49
	},
	'IV': {
		'ke': np.log(2) / 20,
		'EC50': 940,
		'thalfeq': 20,
		'n': 18
	},
	'III': {
			'ke': np.log(2) / 28,
			'thalfeq': 28,
			'EC50': 600,
			'n': 7
		},
	'II': {
			'ke': np.log(2) / 78,
			'thalfeq': 78,
			'EC50': 290,
			'n': 7
		},
	'I': {
			'ke': np.log(2) / 133,
			'thalfeq': 133,
			'EC50': 200,
			'n': 2
		},
	'best': {
		'ke': np.log(2)/ 277,
		'thalfeq': 277,
		'EC50': 100,
		'n': 1
	}
}

fig_order = [ 'med', 'hi', 'lo' ]

params =  [ 'thalfeq', 'ke' ]
results = { param: { Cp: { hy: {} for hy in reversed(list(inputs.keys())) } for Cp in ['lo', 'med', 'hi'] } for param in params }

for img in peak_images:

	hy, Cp, param = re.search('effect_(\w+)_Cp_(\w+)/images/BIP_hysteresis_test_Cp_\w+_(\w+)_Peak.4dfp.img', img).groups()

	if param not in params:
		continue

	data = nb.load(img).get_data().flatten()

	results[param][Cp][hy] = data

trailer = '_cat'

yticks = np.arange(-3,1)
for param, Cps in results.items():
	if args.plot_params and param not in args.plot_params:
		continue
	
	rows = []
	fig, axes = plt.subplots(nrows=3, figsize=(12,8), sharex=True, sharey=False)

	for Cp, hys in Cps.items():
		dataset = []
		invals = []
		for hy, data in hys.items():

			for item in data:
				rows.append([param, Cp, hy, item])

			print(Cp, hy, np.mean(data))
			inval = inputs[hy][param]
			if args.log_scale:
				data = np.log10(data)
				inval = np.log10(inval)
			dataset.append(data)
			invals.append(inval)


		idx = fig_order.index(Cp)

		axes[idx].violinplot(dataset, positions=range(len(dataset)), showmeans=True)
		axes[idx].scatter(range(len(invals)), invals)

		if args.log_scale:
			axes[idx].set_yticks(yticks)
			axes[idx].set_yticklabels(10.0 ** yticks)
			trailer += '_logy' if 'logy' not in trailer else ''

		if args.zoom:
			axes[idx].set_ylim(0,.2)
			trailer += '_zoom'

		axes[idx].set_ylabel(Cp)

	axes[-1].set_xticks(range(len(hys.keys())))
	axes[-1].set_xticklabels(hys.keys())
	axes[0].set_title(param)
	plt.show()
	#plt.savefig('{}{}.png'.format(param, trailer))

	with open('{}{}.csv'.format(param, trailer), 'w', newline='') as f:
		csv.writer(f).writerows(rows)

