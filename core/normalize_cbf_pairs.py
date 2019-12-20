import argparse
import matplotlib.pyplot as plt
import nibabel as nb
import numpy as np
import numpy.polynomial.polynomial as poly
import re


def shift_mode(cbfimg, shift_type=0, maskimg=None, redo=False):
	imgroot = cbfimg.split('.')[0]

	patid, aslrun = re.search('(\w+)_a(\w+)_xr3d', cbfimg).groups()

	img = nb.load(cbfimg)
	imgdata = img.get_data()

	maskdata = nb.load(maskimg).get_data() if maskimg else np.ones_like(imgdata)
	maskdata = np.squeeze(maskdata)

	stats = []
	norm_data = np.empty_like(imgdata)
	for frame in range(imgdata.shape[-1]):
		frame_data = (imgdata[:,:,:,frame])
		norm_frame = np.zeros_like(frame_data)

		in_mask = np.where(maskdata > 0)
		frame_data = frame_data[in_mask]
		bins = np.arange(-61, 121, 1)
		hist, _ = np.histogram(frame_data, bins=bins)

		mode = hist.max()
		fit_idx = np.where(hist >= .7*mode)

		coeff = poly.polyfit(bins[fit_idx], hist[fit_idx], 2)
		_,b,a = coeff

		smooth_mode = -b / (2*a)
		print(','.join(map(str, [patid, aslrun, frame+1, smooth_mode])))

		if shift_type == 0: # none
			continue

		if shift_type == 1: # additive
			trailer = 'shifted'
			frame_data += (50 - smooth_mode)
		else: # multiplicative
			trailer = 'scaled'
			frame_data *= (50 / smooth_mode)

		norm_frame[in_mask] = frame_data
		norm_data[:,:,:,frame] = norm_frame

	if not shift_type:
		return

	normimg = nb.Nifti1Image(norm_data, img.affine, nb.Nifti1Header())
	nb.save(normimg, '{}_{}.nii'.format(imgroot, trailer))


if __name__ == '__main__':
	parser = argparse.ArgumentParser()
	parser.add_argument('cbf_img')
	parser.add_argument('--shift', dest='shift_type', type=int, choices=[0, 1, 2], default=0, help='0 = none, 1 = additive, 2 = multiplicative')
	parser.add_argument('--mask', dest='mask_img')
	parser.add_argument('--redo', action='store_true')

	args = parser.parse_args()
	shift_mode(args.cbf_img, args.shift_type, args.mask_img, args.redo)
