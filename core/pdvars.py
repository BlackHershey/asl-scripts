import argparse
import csv
import nibabel as nib
import numpy as np
import re

from glob import glob
from math import ceil
from os import remove
from sys import stderr, exit
from subprocess import call

# Given a pcasl_pp preprocessed image, calculate weighting for the tag/control pairs based on DVARS-calculated motion
def calculate_pdvars(img, mask_img, preblur=None, crit=5.5):
	imgroot = img.split('.')[0] # remove '.4dfp.img'

	# preblur image prior to dvars if fwhm specified
	if preblur:
		masked_outfile = imgroot + '_msk'
		call(['maskimg_4dfp', '-1', imgroot, mask_img, masked_outfile])
		imgroot = masked_outfile
		call(['imgblur_4dfp', imgroot, str(preblur)])
		imgroot += '_b' + str(int(ceil(10*preblur)))

	imgdata = nib.load(imgroot + '.4dfp.img').get_data()
	maskdata = nib.load(mask_img).get_data().squeeze()

	inmask = imgdata[np.where(maskdata > 0)]
	M = np.sum(maskdata)

	# loop over all pairs of control and tag frames
	# see emails from Tanenbaum 10/26/18
	# frame 0 is the M0 image and frame 1 is a dummy frame that should be discarded
	# p = t/2
	pdvars2 = []

	for t in range(2, imgdata.shape[-1]-1, 2):
		prev_vol = inmask[:, t-1]
		curr_vol = inmask[:, t]
		next_vol = inmask[:, t+1]
		pdvars2_p = np.sum(((curr_vol - prev_vol) ** 2) + ((next_vol - curr_vol) ** 2))
		pdvars2.append(pdvars2_p / float(M))

	one_over_pdvars2 = [1/p2 for p2 in pdvars2]
	c = sum(one_over_pdvars2)
	# See Kevin's and Avi's emails 10 Feb 2022 -- this formula fixes an error in Tanenbaum et al 2015.
	wp = one_over_pdvars2/c

	#pdvars2 = np.array([ max(pdvars2[i:i+2]) for i in range(0,len(pdvars2),2) ]) # take the max DVARS of the frames in a pair
	pdvars = np.sqrt(pdvars2)
	#pdvars = np.insert(pdvars, [0, len(pdvars)], [500,500]) # set first and last frames intentionally high  

	##### npdvars
	npdvars2 = []
	for t in range(2, imgdata.shape[-1]-1, 2):
		curr_T = inmask[:, t]
		curr_C = inmask[:, t+1]
		backward_T = inmask[:, t-2]
		backward_C = inmask[:, t-1]
			
		if t == 2:
			forward_T = inmask[:, t+2]
			forward_C = inmask[:, t+3]
			t_t = np.sum((forward_T - curr_T) ** 2) / inmask.shape[0]
			c_c = np.sum(((forward_C - curr_C) ** 2) + ((curr_C - backward_C) ** 2)) / (2 * inmask.shape[0]) 
			npdvars2.append(1/max(t_t, c_c))
		else:
			if t < imgdata.shape[-1]-2:
				forward_T = inmask[:, t+2]
				forward_C = inmask[:, t+3]
				t_t = np.sum(((forward_T - curr_T) ** 2) + ((curr_T - backward_T) ** 2)) / (2 * inmask.shape[0]) 
				c_c = np.sum(((forward_C - curr_C) ** 2) + ((curr_C - backward_C) ** 2)) / (2 * inmask.shape[0]) 
				npdvars2.append(1/max(t_t, c_c))
			else:
				t_t = np.sum((curr_T - backward_T) ** 2) / inmask.shape[0]
				c_c = np.sum((curr_C - backward_C) ** 2) / inmask.shape[0]
				npdvars2.append(1/max(t_t, c_c))

	#The proportionality constant should be adjusted to make the sum of all weights = 1.
	npdvars2 = npdvars2 / (np.sum(npdvars2))

	with open('../movement/npdvars2.dat', 'wb') as f:
		np.savetxt(f, npdvars2, fmt='%s')

	with open('../movement/pdvars.dat', 'ab') as f:
		np.savetxt(f, pdvars, fmt='%s')
	with open('../movement/weights_pdvars.dat', 'ab') as f:
		np.savetxt(f, wp, fmt='%s')

	format_str = ''.join([ ('x' if v > crit else '+') for v in pdvars ])
	with open('../movement/{}_pdvars.format'.format(imgroot), 'w') as f:
		f.write(format_str)

	# cleanup preblurred image
	if preblur:
		for f in glob(masked_outfile + '*.4dfp.*'):
			remove(f)


if __name__ == '__main__':
	parser = argparse.ArgumentParser('Calculate pDVARS for cbf pairs')
	parser.add_argument('img')
	parser.add_argument('mask_img')
	parser.add_argument('-b', '--preblur', type=float, help='fwhm for blurring in mm')
	parser.add_argument('-c', '--crit', type=float, help='pdvars criteria for frame exclusion')
	args = parser.parse_args()

	calculate_pdvars(args.img, args.mask_img, args.preblur, args.crit)
