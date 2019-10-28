import argparse
import matplotlib.pyplot as plt
import nibabel as nb
import numpy as np
import os

from glob import glob

study_dir = '/net/zfs-black/BLACK/black/MPDP/fnirt_sym'

parser = argparse.ArgumentParser()
parser.add_argument('roi_img', help='4dfp ROI image')
parser.add_argument('--indir', default=study_dir, help='study directory (default MPDP/fnirt+smoothing)')
args = parser.parse_args()

cbf_imgs = glob(os.path.join(args.indir, 'MPD*_s1', 'asl1', '*_cbf_shifted_msk.4dfp.img'))

legend = []
x = []
y = []
y_err = []

for img in cbf_imgs:
	imgdata = nb.load(img).get_data()
	maskdata = nb.load(args.roi_img).get_data()
	msk_idx = np.where(maskdata == 1)

	imgdata = imgdata[msk_idx[:-1]] # remove 4th dimension

	legend.append(os.path.basename(img).split('_')[0])
	x.append(range(imgdata.shape[1]))
	y.append(np.mean(imgdata, axis=0))
	y_err.append(np.std(imgdata, axis=0))


nrows, ncols = (4,3)
fig, axes = plt.subplots(nrows, ncols, figsize=(nrows*4,ncols*4), sharex=True, sharey=True)

for i, (key, ax) in enumerate(zip(sorted(legend), axes.flatten())):
	ax.plot(x[i], y[i], label=key)
	ax.errorbar(x[i], y[i], yerr=y_err[i], label=key, capsize=2)
	ax.legend()

plt.show()
