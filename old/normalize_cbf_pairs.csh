#!/bin/csh

alias MATH 'set \!:1 = `echo "\!:3-$" | bc -l`'

if ( ${#argv} < 3 ) then
	echo "Usage: normalize_cbf_pairs.csh <patid> <label> <maskimg> [redo]"
	exit 1
endif

@ redo = 0
if ( ${#argv} == 4 ) then 
	@ redo = $4
endif

set patid = $1
set label = $2
set maskimg = $3

if ( $label != "_shifted" && $label != "_scaled" ) then
	echo "Label argument must be either '_shifted' or '_scaled'"
	exit 1
endif

pushd ${patid}
source ${patid}.params

@ i = 1
while ( $i <= ${#irun} )
    pushd asl${irun[$i]}

    set img = ${patid}_a{${irun[$i]}}_xr3d_atl_brainmasked_cbf

    if ( $redo || ! -e ${img}${label}_msk.4dfp.img ) then
        set num_frames = `cat ${img}.4dfp.ifh | grep 'matrix size' | tail -1 | awk '{print $5}'`

        if (-e  ${img}${label}.lst) /bin/rm ${img}${label}.lst
        touch ${img}${label}.lst

        @ frame = 1
        while ( $frame <= $num_frames )
            extract_frame_4dfp ${img} $frame
		
			set smoothmode = `cat ../pair_global_numbers_WB.csv | grep ${patid},${irun[$i]},${frame}, | cut -d , -f7`
			
			@ shift_const = 0
			@ scale_factor = 1
			if ( $label == "_shifted" ) then
				MATH shift_const = "50" - $smoothmode
			else
				MATH scale_factor = "50" / $smoothmode
			endif

            scale_4dfp ${img}_frame${frame} $scale_factor -b$shift_const

            echo ${img}_frame${frame}.4dfp.img >> ${img}${label}.lst

            @ frame++
        end

        paste_4dfp ${img}${label}.lst ${img}${label} -a
		maskimg_4dfp -1 ${img}${label} $maskimg ${img}${label}_msk
        /bin/rm ${img}_frame*
		
    endif

    popd
    @ i++
end
popd
