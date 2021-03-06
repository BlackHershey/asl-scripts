import argparse
import numpy as np
import pydicom
import os
import re
import sys
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'utils')) # add asl-scripts/utils to path for image_utils import below

from datetime import datetime, timedelta
from glob import glob
from image_utils import get_num_frames
from os.path import join, exists

SCAN_START_FILE = 'scan_start_times.csv'
CBF_PAIR_FILE = 'cbf_pair_times.csv'
INFUSION_FILE = '../MPDP_infusion_times.csv'

# for all dicom images in a study 99 folder, get list of tuples containing series number and content time
def get_content_time_table(patid, inpath, rerun=False):
	if not rerun and exists(SCAN_START_FILE):
		return np.genfromtxt(SCAN_START_FILE, delimiter=',', skip_header=1, usecols=(1,2))

	dicom_headers = glob(join(inpath, 'study99', '*.dcm'))

	content_times = [['patid', 'asl_run', 'start_time']]
	for header_file in dicom_headers:
		ds = pydicom.read_file(header_file)
		# protocol name for scan is not a top-level named attribute; it's nested in lists a few levels down
		# chose to just convert header to string for ease of checking
		# relies on assumption that search string should never appear in other types of scans)
		if 'pcasl_3D_tgse_3mm_SEG2by2' in str(ds):
			content_times.append((patid, ds.InstanceNumber, ds.ContentTime)) # instance number here is number of scan out of all scans

	content_times = [ (tup[0], idx+1, tup[2]) for idx, tup in enumerate(sorted(content_times)) ] # renumber for asl scans only

	np.savetxt(SCAN_START_FILE, content_times, fmt='%s', delimeter=',')
	return content_times


def get_infusion_time(patid):
	with open(INFUSION_FILE) as f:
		for line in f:
			if not line.startswith(patid):
				continue
			return datetime.strptime(line.split(',')[-1], '%H:%M:%S')
	return None


def get_cbf_time_table(patid, inpath=os.getcwd(), rerun=False):
	if not rerun and exists(CBF_PAIR_FILE):
		return np.genfromtxt(CBF_PAIR_FILE, delimiter=',', skip_header=1, usecols=(1,2,4))

	infusion_time = get_infusion_time(patid)
	content_times = get_content_time_table(patid, inpath, rerun)

	cbf_pair_times = []
	for asl_run in range(1, len(content_times) + 1):
		content_time =  datetime.strptime(content_times[asl_run-1][-1], '%H%M%S.%f') # get time string from tuple and convert to datetime
		cbf_images = glob(join('asl' + str(asl_run), '*nlin*_cbf_shifted.4dfp.ifh'))
		if cbf_images:
			for cbf_pair in range(1, get_num_frames(cbf_images[0]) + 1):
				pair_time = content_time + timedelta(seconds=((cbf_pair * 2) + 1) * 16.92)
				time_since_infusion = (pair_time - infusion_time).total_seconds() / 60
				cbf_pair_times.append((patid, asl_run, cbf_pair, pair_time.strftime('%H:%M:%S.%f'), time_since_infusion))
	np.savetxt(CBF_PAIR_FILE, cbf_pair_times, fmt='%s', delimeter=',')

	return cbf_pair_times


if __name__ == '__main__':
	parser = argparse.ArgumentParser(description='generate time tables for scan starts and cbf pairs')
	parser.add_argument('patdir', help='patient scan session directory to generate time tables for')
	parser.add_argument('-i', '--inpath', help='directory containing sorted dicoms (if separate rawdata directory')
	parser.add_argument('-r', '--rerun', action='store_true', help='regenerate time tables')
	args = parser.parse_args()

	get_cbf_time_table(args.patdir, args.inpath, args.rerun)
