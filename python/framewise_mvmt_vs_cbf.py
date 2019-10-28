import argparse
import csv
import re
import matplotlib.ticker
import seaborn as sns

from glob import glob
from matplotlib import pyplot as plt
from os.path import abspath, basename, join

def read_CBF_numbers(patid, mask='WB'):
	pair_file = join(patid, 'pair_global_numbers_{}.csv'.format(mask))
	cbf = []
	with open(pair_file, 'r') as f:
	    reader = csv.reader(f)
	    next(reader) # skip header row
	    for row in reader:
	        cbf.append(float(row[6]))
	return cbf


def read_mvmt_numbers(patid, filename):
	value_file = join(patid, 'movement', filename)
	return [ float(line.split('\t')[0]) for line in open(value_file).readlines() ]

parser = argparse.ArgumentParser()
parser.add_argument('--patids', nargs='+', help='select which subjects to include in plot (default is all first session)')
parser.add_argument('--cbf_lims', nargs=2, default=[0,130], type=int, help='axis limits for cbf plots')
parser.add_argument('--dvars_lims', nargs=2, default=[0,16], type=int, help='axis limits for dvars plots')
args = parser.parse_args()
print(args)

all_mvmt = {
	'FD': {},
	'DVARS': {}
}

fd_ticks = [.2, .5, 1, 2, 10] 
dvars_max_lim = 16

if args.patids:
	patids = args.patids
	trailer = '_' + '_'.join(patids)
else:
	patids = sorted([ basename(abspath(d)) for d in glob('MPD*_s1/') ])
	trailer = ''

sns.set_palette(sns.color_palette('husl', len(patids)))

for mvmt_type in ['FD', 'DVARS']:
	for region in ['GM', 'WM']:
		fig, ax1 = plt.subplots()
		ax1.set_xlabel(mvmt_type)
		ax1.set_ylabel(' '.join([region, 'CBF']))
		
		legend = []
		for patid in patids:
			if re.match('MPD1(06|10)', patid):
				continue

			legend.append(patid)

			if mvmt_type == 'DVARS':
				mvmt = read_mvmt_numbers(patid, 'pdvars.dat')
			else:
				mvmt = []
				# read in FD and store max of pairs in y1
				fd_frames = read_mvmt_numbers(patid, '{}_xr3d.FD'.format(patid))
				for i in range(2, len(fd_frames), 2):
					if fd_frames[i] == 500:
						continue
					mvmt.append(max(fd_frames[i:i+2]))

			cbf = read_CBF_numbers(patid, region)
			ax1.scatter(mvmt, cbf)

			all_mvmt[mvmt_type][patid] = mvmt
		
		if mvmt_type == 'FD':
			ax1.set_xscale('log')
			ax1.set_xticks(fd_ticks)
			ax1.get_xaxis().set_major_formatter(matplotlib.ticker.ScalarFormatter())
		else:
			ax1.set_xlim(args.dvars_lims[0], args.dvars_lims[1])

		ax1.set_ylim(args.cbf_lims[0], args.cbf_lims[1])
		ax1.legend(legend)
		plt.savefig('pairwise_{}_vs_{}-cbf{}.png'.format(mvmt_type.lower(), region.lower(), trailer))


legend = []
fig, ax1 = plt.subplots()
for patid in patids:
	if re.match('MPD1(06|10)', patid):
		continue
	legend.append(patid)
	ax1.scatter(all_mvmt['FD'][patid], all_mvmt['DVARS'][patid])

ax1.set_xscale('log')
ax1.set_xticks(fd_ticks)
ax1.set_ylim(0, dvars_max_lim)
ax1.set_xlabel('FD')
ax1.set_ylabel('pDVARS')
ax1.get_xaxis().set_major_formatter(matplotlib.ticker.ScalarFormatter())
ax1.legend(legend)
#plt.show()
#ax1.scatter(all_mvmt['FD'], all_mvmt['DVARS'])
plt.savefig('pairwise_fd_vs_dvars{}.png'.format(trailer))

"""
for region_label, cbf_values in [('GM', gm_cbf), ('WM', wm_cbf)]:
	plot(fd_pairs, cbf_values, 'FD', region_label)
	plot(dvars, cbf_values, 'DVARS', region_label)
"""



