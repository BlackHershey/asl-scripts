import argparse
import csv
import dicom
import os
import re
import sys

from datetime import datetime, timedelta
from os.path import join, exists
from pcasl_cbf import get_num_frames

SCAN_START_FILE = 'scan_start_times.csv'
CBF_PAIR_FILE = 'cbf_pair_times.csv'


def write_csv(header, rows, outfile):
	with open(outfile, 'wb') as f:
		writer = csv.writer(f)
		writer.writerow(header)
		for row in rows:
			writer.writerow(row)


def read_csv(infile):
	content_times = []
	with open(infile, 'rb') as f:
		reader = csv.reader(f)
		for row in reader:
			content_times.append(tuple(row))
	return content_times


# for all dicom images in a study 99 folder, get list of tuples containing series number and content time
def get_content_time_table(patid, rerun=False):
	if not rerun and exists(SCAN_START_FILE):
		return read_csv(SCAN_START_FILE)

	os.chdir('study99')
	dicom_headers = [ f for f in os.listdir('.') if f.endswith('.dcm') ]

	content_times = []
	for header_file in dicom_headers:
		ds = dicom.read_file(header_file)
		# protocol name for scan is not a top-level named attribute; it's nested in lists a few levels down
		# chose to just convert header to string for ease of checking
		# relies on assumption that search string should never appear in other types of scans)
		if 'pcasl_3D_tgse_3mm_SEG2by2' in str(ds):
			content_times.append((patid, ds.InstanceNumber, ds.ContentTime)) # instance number here is number of scan out of all scans

	content_times = [ (tup[0], idx+1, tup[2]) for idx, tup in enumerate(sorted(content_times)) ] # renumber for asl scans only
	write_csv(['patid', 'asl_run', 'start_time'], sorted(content_times), join('..', SCAN_START_FILE))
	return content_times


def get_cbf_time_table(patient_dir, rerun=False):
	os.chdir(patient_dir)

	if not rerun and exists(CBF_PAIR_FILE):
		return read_csv(CBF_PAIR_FILE)

	patid = os.getcwd().strip(os.sep).split(os.sep)[-1] # remove trailing slash, split on file separator, then get patid (current directory name)
	content_times = get_content_time_table(patid, rerun)

	cbf_pair_times = []
	for asl_run in range(1, len(content_times) + 1):
		os.chdir(patient_dir)
		os.chdir('asl' + str(asl_run))
		content_time =  datetime.strptime(content_times[asl_run-1][-1], '%H%M%S.%f') # get time string from tuple and convert to datetime
		cbf_images = [ f for f in os.listdir('.') if f.endswith('_cbf.4dfp.ifh') ]
		if cbf_images:
			for cbf_pair in range(1, get_num_frames(cbf_images[0]) + 1):
				pair_time = content_time + timedelta(seconds=((cbf_pair * 2) + 1) * 16.92)
				cbf_pair_times.append((patid, asl_run, cbf_pair, pair_time.strftime('%H:%M:%S.%f')))

	write_csv(['patid', 'asl_run', 'cbf_pair', 'time'], cbf_pair_times, join('..', CBF_PAIR_FILE))
	return cbf_pair_times


if __name__ == '__main__':
	parser = argparse.ArgumentParser(description='generate time tables for scan starts and cbf pairs')
	parser.add_argument('patdir', help='patient scan session directory to generate time tables for')
	parser.add_argument('-r', '--rerun', action='store_true', help='regenerate time tables')
	args = parser.parse_args()

	get_cbf_time_table(args.patdir, args.rerun)