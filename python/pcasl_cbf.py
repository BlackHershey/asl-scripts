from math import exp
from os import remove
from os.path import exists
from subprocess import call
from sys import argv

# Read key-value pairs from header and extract number of frames
def get_num_frames(ifh):
    header_vars = {}
    with open(ifh) as f:
        for line in f:
            key, value = [ s.strip() for s in line.split(':=') ]
            header_vars[key] = value
    dims = header_vars['number of dimensions']
    return int(header_vars['matrix size [{}]'.format(dims)])


# Convert pcasl 4dfp image into perfusion image
def gen_pcasl_perfusion_img(pcasl_4dfp_img, mask_img):
    # mask images prior to generating perfusion images
    brainmasked_img = '_'.join([pcasl_4dfp_img, 'brainmasked'])
    call(['maskimg_4dfp', '-1', pcasl_4dfp_img, mask_img, brainmasked_img])

    num_frames = get_num_frames(brainmasked_img + '.4dfp.ifh')

    perfusion_images = []
    # for evey 2 frames (skipping first 2 frames, M0 and dummy), subtract control from tag
    for i in range(2, num_frames, 2):
        img_idx = len(perfusion_images)
        format_str = ''.join([str(i), 'x-+', str(num_frames-i-2), 'x'])
        call(['actmapf_4dfp', '-aperf' + str(img_idx), format_str, brainmasked_img])
        perfusion_images.append(brainmasked_img + '_perf' + str(img_idx))

    # write individual perfusion image filenames to list to be used below
    img_lst = brainmasked_img + '_perf.lst'
    with open(img_lst, 'wb') as f:
        f.write('\n'.join(perfusion_images))

    # TODO: remove individual perfusion images after we create combined image
    call(['paste_4dfp', '-a', img_lst, brainmasked_img + '_perf']) # combine individual perfusion images into one multi-frame image


def calculate_cbf(pcasl_4dfp_img, mask_img):
    img_root = pcasl_4dfp_img.split('.', 1)[0] # grab image name up to first .

    gen_pcasl_perfusion_img(img_root, mask_img)
    img_root += '_brainmasked' # all operations from here on use _brainmasked file generated in perfusion creation step

    # cbf calculation constants
    R1a = .606
    partition_coeff = .9 # g/ml
    tag_eff = .80
    post_label_delay = 2 # seconds
    rf_blocks = 82
    label_pulse = .0184 * rf_blocks # seconds

    c = (partition_coeff * R1a) / (2 * tag_eff * (exp(-post_label_delay * R1a) - exp(-(label_pulse + post_label_delay) * R1a)))
    call(['extract_frame_4dfp', img_root, '1']) # extracts first frame (M0) into <pcasl_4dfp_img>_frame1
    call(['imgopr_4dfp', '-r' + img_root + '_cbf', '-c' + str(c), img_root + '_perf', img_root + '_frame1']) # divide multi-frame perfusion image by M0 and multiply by constant to get cbf


if __name__ == '__main__':
    if len(argv) != 3:
        print('usage: python pcasl_cbf.py <pcasl_4dfp_img> <mask_img>')
        exit(1)
    calculate_cbf(argv[1], argv[2])
