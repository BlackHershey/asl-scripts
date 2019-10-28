import argparse
import csv
import math
import matplotlib
import matplotlib.pyplot as plt
import nibabel as nb
import numpy as np
import os
import os.path

from glob import glob

study_dir = '/net/zfs-black/BLACK/black/MPDP'
subjects = [ 'MPD109_s1', 'MPD111_s1', 'MPD104_s1' ]

tag_start = 0
ctl_start = 1

legend = ['tag', 'ctl']
plt.rcParams['axes.grid'] = True

def plot_with_errorbar(ax, data, start_idx, n, dvars):
	data = data[start_idx::2]
	error = [ math.sqrt(np.sum(d) / n) for d in dvars[start_idx::2 ] ]
	ax.plot(data, label=legend[start_idx])
	ax.errorbar(range(len(data)), data, yerr=error, capsize=2)


def plot_with_weights(ax, data, start_idx, n, dvars):
	data = data[start_idx::2]
	weights = [ 1 / (np.sum(d) / n ) for d in dvars[start_idx::2] ]
	marker_sizes = [ 2000* (w / sum(weights)) for w in weights ]
	ax.plot(data, label=legend[start_idx])
	ax.scatter(range(start_idx, len(data), 2), data) #, s=marker_sizes, alpha=.5)


def plot_connected_points(ax, data, start_idx, step=1):
	idxs = range(start_idx, len(data), step)
	data = data[start_idx::step]
	ax.plot(idxs, data, marker='o', label=legend[start_idx])
	return data


def plot_baseline_signal(errorbar):
	baseline_csvs = glob(os.path.join(study_dir, 'baseline_signal*.csv'))
	for f in baseline_csvs:
		os.remove(f)


	for sub in subjects:
		imgroot = sub + '_a1_xr3d_atl_brainmasked{}.4dfp.img'
		img = os.path.join(study_dir, sub, 'asl1', imgroot.format(''))
		cbfimg = os.path.join(study_dir, sub, 'asl1', imgroot.format('_cbf'))
		preblurred = os.path.join(study_dir, sub, 'movement', '{}_a1_xr3d_atl_msk_b100.4dfp.img'.format(sub))
		mask = os.path.join(study_dir, sub, 'atlas', '{}_FSWB_on_CAPIIO_333.4dfp.img'.format(sub))

		imgdata = nb.load(img).get_data()
		cbf_imgdata = nb.load(cbfimg).get_data()
		preblurdata = nb.load(preblurred).get_data()
		mskdata = nb.load(mask).get_data()

		n_mask_voxels = np.sum(mskdata)

		for region,x,y,z in [ ('acc', 26, 13, 24), ('vent', 26, 30, 27) ]:
			timecourse = imgdata[x,y,z,2:]
			cbfdata = cbf_imgdata[x,y,z,:]

			dvars = [np.nan, np.nan]
			for frame in range(4, imgdata.shape[3]):
				dvars.append(math.sqrt(
					np.sum((preblurdata[:,:,:,frame] - preblurdata[:,:,:,frame-1]) ** 2) / n_mask_voxels
				))

			fd = []
			with open(os.path.join(study_dir, sub, 'movement', '{}_xr3d.FD'.format(sub))) as f:
				reader = csv.reader(f, delimiter='\t')
				next(reader) # skip M0 FD
				next(reader) # skip dummy frame FD
				for line in reader:
					if float(line[0]) == 500:
						break
					fd.append(float(line[0]))


			fig, axes = plt.subplots(4, 1, figsize=(10,10))

			med = np.median(timecourse)
			for label, idx in [ ('tag', 0), ('ctl', 1) ]:

				for ax, tup in enumerate([('CBF', (-20,100), cbfdata, 1), ('Voxel_intensity', (med-25, med+25), timecourse, 2), ('DVARS', (0,15), dvars, 2), ('FD', (0,2), fd, 1)]):
					axes[ax].set_ylabel(tup[0])

					step = tup[3]
					if step == 1 and idx != 0:
						continue # FD/CBF are not separated by tag/ctl so only plot once


					idxs = range(idx, len(tup[2]), step)
					data = tup[2][idx::step]
					axes[ax].plot(idxs, data, marker='o', label=legend[idx])

					with open(os.path.join(study_dir, 'baseline_signal_{}.csv'.format(tup[0])), 'a') as f:
						writer = csv.writer(f)
						writer.writerows([ [sub, region, label, d] for d in data ])

					axes[ax].margins(x=0)
					axes[ax].set_xticks(range(0, len(tup[2]), 2))
					axes[ax].set_ylim(tup[1][0], tup[1][-1])

			plt.suptitle(sub + '_asl1_' + region)
			axes[1].legend()
			axes[2].legend()

			#plt.show()
			plt.savefig(os.path.join(study_dir, sub, 'asl1', '{}_a1_{}_baseline_signal.png'.format(sub, region)))



if __name__ == '__main__':
	parser = argparse.ArgumentParser()
	parser.add_argument('-e', '--errorbar', action='store_true', help='plot with DVARS as error bar; default is weighted point size')
	args = parser.parse_args()

	plot_baseline_signal(args.errorbar)
