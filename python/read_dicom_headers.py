import dicom
import sys

from os import listdir
from os.path import join


# for all dicom images in a series 99 folder, get list of tuples containing series number and content time
def read_dicom_headers(series99_dir):
	dicom_headers = [ f for f in listdir(series99_dir) if f.endswith('.dcm') ]
	
	content_times = []
	for header_file in dicom_headers:
		ds = dicom.read_file(join(series99_dir, header_file))
		# protocol name for scan is not a top-level named attribute; it's nested in lists a few levels down
		# chose to just convert header to string for ease of checking
		# relies on assumption that search string should never appear in other types of scans)
		if 'pcasl_3D_tgse_3mm_SEG2by2' in str(ds): 
			content_times.append((ds.InstanceNumber, ds.ContentTime))

	return content_times


if __name__ == '__main__':
	print(read_dicom_headers(sys.argv[1]))
	

