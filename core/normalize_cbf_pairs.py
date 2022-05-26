import argparse
import matplotlib.pyplot as plt
import nibabel as nb
import numpy as np
import numpy.polynomial.polynomial as poly
import re


def shift_mode(cbfimg, shift_type=0, maskimg=None, redo=False, line_fit_range_percent=0.15):
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
		c,b,a = coeff
		parab_max = c - (b**2/(4*a))
		smooth_mode = -b / (2*a)
		print(','.join(map(str, [patid, aslrun, frame+1, smooth_mode])))

		if shift_type == 0: # none
			continue

		if shift_type == 1: # additive
			trailer = 'shifted'
			frame_data += (50 - smooth_mode)

		if shift_type == 2: # multiplicative
			trailer = 'scaled'
			frame_data *= (50 / smooth_mode)

		else: # scale and shift
			trailer = 'shiftscaled'
			line_fit_range_max = parab_max/2.0 + parab_max*line_fit_range_percent
			line_fit_range_min = parab_max/2.0 - parab_max*line_fit_range_percent
			y_in_range = np.where((line_fit_range_min < hist) & (hist < line_fit_range_max)) 
			x_left = np.where(bins[y_in_range] < smooth_mode)
			x_right = np.where(smooth_mode < bins[y_in_range])
			m1, b1 = np.polyfit(bins[y_in_range][x_left], hist[y_in_range][x_left], 1)
			m2, b2 = np.polyfit(bins[y_in_range][x_right], hist[y_in_range][x_right], 1)
			x1 = (parab_max/2 - b1) / m1
			x2 = (parab_max/2 - b2) / m2
			width = x2-x1
			frame_data -= smooth_mode
			frame_data = (frame_data/width)*17
			frame_data += 50

		norm_frame[in_mask] = frame_data
		norm_data[:,:,:,frame] = norm_frame

	if not shift_type:
		return

	normimg = nb.Nifti1Image(norm_data, img.affine, nb.Nifti1Header())
	nb.save(normimg, '{}_{}.nii'.format(imgroot, trailer))


if __name__ == '__main__':
	parser = argparse.ArgumentParser()
	parser.add_argument('cbf_img')
	parser.add_argument('--shift', dest='shift_type', type=int, choices=[0, 1, 2, 3], default=0, help='0 = none, 1 = additive, 2 = multiplicative, 3 = scale_shift')
	parser.add_argument('--mask', dest='mask_img')
	parser.add_argument('--redo', action='store_true')

	args = parser.parse_args()
	shift_mode(args.cbf_img, args.shift_type, args.mask_img, args.redo)
