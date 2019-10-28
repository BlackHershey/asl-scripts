import numpy as np
import os

from glob import glob
from shutil import copyfile
from subprocess import run


study_dir = '/net/zfs-black/BLACK/black/MPDP'
analysis_dir = '/net/zfs-black/BLACK/black/MPDP/fnirt_sym'

data = np.genfromtxt(os.path.join(study_dir, 'mpdp_updrs_demo.csv'), usecols=(0,4), delimiter=',', dtype='str')

for sub, worse_hand in data:
	scans = glob(os.path.join(analysis_dir, sub + '_s1', '*ldopa*.nii*'))
	scans += glob(os.path.join(analysis_dir, sub + '_s1', 'asl1', '*_avg_moco.nii*'))

	for scan in scans:
		print(scan)
		imgroot, ext = os.path.splitext(scan)
		outfile = '{}_worseL{}'.format(imgroot, ext)

		if worse_hand == 'R':
			copyfile(scan, outfile) # if worse hand is R, worse brain is already on L
		else:
			run(['fslswapdim', scan, '-x', 'y', 'z', outfile]) # for L worse hand, swap L/R to put worse brain side on L
			outfile += '.gz'
		
		os.symlink(outfile, os.path.join(analysis_dir, 'cbf', os.path.basename(outfile)))
