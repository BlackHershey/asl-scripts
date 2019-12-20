import argparse
import pcasl_timing

from datetime import datetime, timedelta
from os import chdir, getcwd
from os.path import split
from subprocess import call, PIPE, run
from weighted_average import gen_weighted_average


def post_infusion_cbf_avg(cbf_conc_img, output_trailer, infusion_time, fmtfile=None):
	patient_dir, conc_img = split(cbf_conc_img)

	infusion_time = datetime.strptime(infusion_time, '%H%M%S')
	cbf_time_table = pcasl_timing.get_cbf_time_table(getcwd(), infusion_time)

	before = next((idx for idx, tup in enumerate(cbf_time_table) if float(tup[-1]) >= 15), 0)
	during = next((idx for idx, tup in enumerate(cbf_time_table[before:]) if float(tup[-1]) >= 40), 0)
	after = len(cbf_time_table) - before - during

	timing_fmt = ''.join([str(before), 'x', str(during), '+', str(after), 'x'])

	# create pdvars-weighted post-LD average
	gen_weighted_average(cbf_conc_img, trailer=output_trailer, fmtstr=timing_fmt)

	# create motion scrubbed (pdvars) post-LD average
	if fmtfile:
		fmt1 = list(run(['format2lst', '-e', timing_fmt], stdout=PIPE).stdout.decode())
		fmt2 = list(open(fmtfile).readlines()[0])
		timing_fmt = ''.join([ ('x' if v1 == 'x' else v2) for v1,v2 in zip(fmt1, fmt2) ])
		output_trailer += '_moco'
	call(['actmapf_4dfp', timing_fmt, cbf_conc_img, '-a' + output_trailer])


if __name__ == '__main__':
	parser = argparse.ArgumentParser(description='generate average image for cbf frames within 15-40 minute period after infusion')
	parser.add_argument('cbf_conc_img', help='conc image containing cbf images for all asl runs')
	parser.add_argument('output_trailer', help='trailer to append to output image root (e.g. 15-40min_after_infusion)')
	parser.add_argument('infusion_time', help='infusion time string in format hhmmss')
	parser.add_argument('--fmtfile', help='addtional fmtfile (pdvars/fd) to use when creating average')
	args = parser.parse_args()

	post_infusion_cbf_avg(args.cbf_conc_img, args.output_trailer, args.infusion_time, args.fmtfile)
