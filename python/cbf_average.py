import argparse
import pcasl_timing

from datetime import datetime, timedelta
from os import chdir, getcwd
from os.path import split
from subprocess import call


def post_infusion_cbf_avg(cbf_conc_img, output_root_trailer, infusion_time):
	patient_dir, conc_img = split(cbf_conc_img)
	chdir(patient_dir)

	infusion_time = datetime.strptime(infusion_time, '%H%M%S')
	cbf_time_table = pcasl_timing.get_cbf_time_table(getcwd(), infusion_time)

	before = next((idx for idx, tup in enumerate(cbf_time_table) if float(tup[-1]) >= 15), 0)
	during = next((idx for idx, tup in enumerate(cbf_time_table[before:]) if float(tup[-1]) >= 40), 0)
	after = len(cbf_time_table) - before - during

	format_str = ''.join([str(before), 'x', str(during), '+', str(after), 'x'])
	call(['actmapf_4dfp', format_str, conc_img, '-a' + output_root_trailer])


if __name__ == '__main__':
	parser = argparse.ArgumentParser(description='generate average image for cbf frames within 15-40 minute period after infusion')
	parser.add_argument('cbf_conc_img', help='conc image containing cbf images for all asl runs')
	parser.add_argument('output_root_trailer', help='trailer to append to output image root (e.g. 15-40min_after_infusion)')
	parser.add_argument('infusion_time', help='infusion time string in format hhmmss')
	args = parser.parse_args()

	post_infusion_cbf_avg(args.cbf_conc_img, args.output_root_trailer, args.infusion_time)
