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
def gen_pcasl_perfusion_img(pcasl_4dfp_img):
    img_root = pcasl_4dfp_img.split('.', 1)[0] # grab image name up to first .
    num_frames = get_num_frames(img_root + '.4dfp.ifh')

    perfusion_images = []
    # for evey 2 frames (skipping first 2 frames, M0 and dummy), subtract control from tag
    for i in range(2, num_frames, 2):
        img_idx = len(perfusion_images)
        format_str = ''.join([str(i), 'x-+', str(num_frames-i-2), 'x'])
        call(['actmapf_4dfp', '-aperf' + str(img_idx), format_str, pcasl_4dfp_img])
        perfusion_images.append(img_root + '_perf' + str(img_idx))

    # write individual perfusion image filenames to list to be used below
    img_lst = img_root + '_perf.lst'
    with open(img_lst, 'wb') as f:
        f.write('\n'.join(perfusion_images))

    call(['paste_4dfp', '-a', img_lst, img_root + '_perf']) # combine individual perfusion images into one multi-frame image
    return


if __name__ == '__main__':
    gen_pcasl_perfusion_img(argv[1])
