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

	# loop over all control and tag frames
	pdvars2 = []
	for t in range(4, imgdata.shape[-1]-2, 1):
		prev_vol = inmask[:, t-2]
		curr_vol = inmask[:, t]
		next_vol = inmask[:, t+2]

		pdvars2_p = np.sum(((curr_vol - prev_vol) ** 2) + ((next_vol - curr_vol) ** 2))
		pdvars2.append(pdvars2_p / float(M))

	pdvars2 = np.array([ max(pdvars2[i:i+2]) for i in range(0,len(pdvars2),2) ]) # take the max DVARS of the frames in a pair
	pdvars = np.sqrt(pdvars2)
	pdvars = np.insert(pdvars, [0, len(pdvars)], [500,500]) # set first and last frames intentionally high

	with open('../movement/pdvars.dat', 'ab') as f:
		np.savetxt(f, pdvars, fmt='%s')

	format_str = ''.join([ ('x' if v > crit else '+') for v in pdvars ])
	with open('../movement/{}_pdvars.format'.format(imgroot), 'w') as f:
		f.write(format_str)

	# cleanup preblurred image
	if preblur:
		for f in glob(masked_outfile + '*.4dfp.*'):
			remove(f)


if __name__ == '__main__':
	parser = argparse.ArgumentParser('Calculate weights for cbf pairs based on DVARS')
	parser.add_argument('img')
	parser.add_argument('mask_img')
	parser.add_argument('-b', '--preblur', type=float, help='fwhm for blurring in mm')
	parser.add_argument('-c', '--crit', type=float, help='pdvars criteria for frame exclusion')
	args = parser.parse_args()

	calculate_pdvars(args.img, args.mask_img, args.preblur, args.crit)
