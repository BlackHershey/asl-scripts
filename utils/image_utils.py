import nibabel as nib


def get_num_frames(ifh):
    header_vars = {}
    with open(ifh) as f:
        for line in f:
            if line.startswith('matrix size [4]'):
                return int(line.split(':=')[-1])
    return 0 # if no 4th dimension in header, not a 4D image
