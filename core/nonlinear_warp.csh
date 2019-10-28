#!/bin/csh

set program = $0;
set program = $program:t

# force using FSL version 5.0.9
setenv FSLDIR /data/nil-bluearc/hershey/unix/software/fsl
set fslbin = ${FSLDIR}/bin

# usage
if (${#argv} < 1 || ${#argv} > 5 ) then
	echo "Usage: $program <patid.params> [study.params] [options]"
	echo "e.g.,  $program  LD_01.params   ../LD_MTD.params"
	echo "e.g.,  $program  LD_01.params   ../LD_MTD.params -sz"
	echo "N.B.:  This script must be run from the patid folder."
	echo "options:  -redo"
	echo "          -noblur = use unblurred version of preprocessed data"
	exit 1
endif
# date
# uname -a

# defaults
@ useblur = 1
@ redo = 1

if ( ${#argv} > 2 ) then
	# parse options
	@ i = 2
	while ( $i <= ${#argv} )
		set check_opt = $argv[$i]
		if ( "$check_opt" == '-noblur' ) then
			echo 'WARNING: using unsmoothed data'
			@ useblur = 0
		endif
		if ( "$check_opt" == '-redo' ) then
			@ redo = 1
		endif
		@ i++
	end
endif

# source .params files
set prmfile = $1
if (! -e $prmfile) then
	echo $program": "$prmfile" not found"
	exit -1
endif
# echo OK
source $prmfile

#source
if ( $#argv > 1 ) then
	set instructions = $2
	if (! -e $instructions) then
		echo $program": "$instructions" not found"
		exit -1
	endif
	# cat $instructions
	source $instructions
endif

set out_space = ${fnirt_ref:t:r:r}

if ( ! -d atlas || ! -d "asl"$irun[1] ) then
	echo ""
	echo "ERROR: This is probably not the patid directory for "$patid","
	echo "       run this script from the patid directory for "$patid
	exit 1
endif

if (! ${?blur} ) set blur = 0

# check blur options
if ($blur == 0 || $useblur == 0) then
	set blurstr = ""
else
	set blurstr = `echo $blur | gawk '{printf("_g%d", int(10.0*$1 + 0.5))}'`		# logic in gauss_4dfp.c
endif


# if not set in .params, set these as the 4dfp-suite default values
if (! ${?out_img_ext}) set out_img_ext = "on_"${out_space}"_via_fnirt"
if (! ${?func_warp_interp}) then
	set func_warp_interp = ""
else
	set func_warp_interp = "--interp="$func_warp_interp
endif
set dfnd_warp_interp = "--interp=nn"

set patid1 = $patid
if ( ${?day1_patid} ) then
	cp -r ../${day1_patid}/atlas/fnirt ./atlas

	pushd atlas/fnirt

	set mprlst = `ls *_mpr_n?_111_t88.nii.gz`
	set mpr111 = $mprlst[1]:r:r
	set mpr333 = `echo $mpr111 | sed "s/111_t88/333_t88/"`

	popd

	goto EPI_to_ATL
endif

pushd atlas

# assume there is a 111 t88-space image output from avgmpr_4dfp
# get a list of them (in case patid was processed more than once with different number of mprs)
set atlmpr_list = ( `ls -t $patid"_mpr_n"*"_111_t88.4dfp.img"` )
if ( $status ) then

	echo ""
	echo "ERROR: didn't find any images named like "$patid"_mpr_n"'?'"_111_t88.4dfp.img"
	echo "       in the atlas directory."
	exit 1
endif

# get the latest one
set mpr111 = $atlmpr_list[1]:r:r

# make a fnirt directory for working
if ( ! -d fnirt ) mkdir fnirt
cd fnirt

# link 111 mpr
foreach ext ( img img.rec ifh hdr )
	ln -s ../$mpr111.4dfp.$ext ./
end

# mask 111 mpr
# maskimg_4dfp $mpr111 $REFDIR/711-2B_mask_g5_111z $mpr111"_brainmasked"
nifti_4dfp -n $mpr111 $mpr111
bet $mpr111 $mpr111"_brainmasked"

# resample 111 mpr into 333
set mpr333 = `echo $mpr111 | sed "s/111_t88/333_t88/"`
if ( $redo | ! -e $mpr333.nii.gz ) then
	t4img_4dfp none $mpr111 $mpr333 -O333
	# make a nii.gz for 111 and 333 mprs
	foreach img ( $mpr111 $mpr111"_brainmasked" $mpr333 )
		if ( ! -e $img.nii.gz ) then
			niftigz_4dfp -n $img $img.nii
		endif
	end
endif

# flirt (linear) warp mpr111 to MNI152
if ( $redo || ! -e $mpr111"_brainmasked_to_MNI152_flirt".mat) then
	$fslbin/flirt -ref ${fnirt_ref} -in $mpr111"_brainmasked" -omat $mpr111"_brainmasked_to_${out_space}_flirt".mat
endif

# fnirt (non-linear) warp mpr111 to MNI152 using default FSL fnirt T1_2_MNI152_2mm config options
if ( $redo || ! -e $mpr111"_to_MNI152_fnirt_coeff".nii.gz ) then
	$fslbin/fnirt --in=$mpr111 --aff=$mpr111"_brainmasked_to_${out_space}_flirt".mat --cout=$mpr111"_to_"${out_space}"_fnirt_coeff" --config=${fnirt_cnf}
endif

# write out $mpr111 in MNI152 space
if ( $redo || ! -e $mpr111"_on_"${out_space}"_via_fnirt".nii.gz ) then
	$fslbin/applywarp --ref=${fnirt_ref} --in=$mpr111 --warp=$mpr111"_to_"${out_space}"_fnirt_coeff" --out=$mpr111"_on_"${out_space}"_via_fnirt"
endif

# flirt 333 mpr to 111 mpr
if ( $redo || ! -e $mpr333"_to_"$mpr111"_flirt".mat ) then
	$fslbin/flirt -ref $mpr111 -in $mpr333 -omat $mpr333"_to_"$mpr111"_flirt".mat -dof 6
endif

popd

EPI_to_ATL:

foreach run ( $irun )
	pushd asl${run}
	set func_root = ${patid}_a${run}_xr3d_atl

	if ( $redo || ! -e ${func_root}_on_CAPIIO.nii.gz ) then
		niftigz_4dfp -n ${func_root} ${func_root}_on_CAPIIO
	endif

	# func img to MNI152 via mpr111_to_MNI152 fnirt warp and mpr333_to_mpr111 flirt warp
	if ( $redo || ! -e ${func_root}_${out_img_ext}.nii.gz ) then
		$fslbin/applywarp \
			--ref=${fnirt_ref} \
			--in=${func_root}_on_CAPIIO \
			--warp=../atlas/fnirt/$mpr111"_to_"${out_space}"_fnirt_coeff" \
			--premat=../atlas/fnirt/$mpr333"_to_"$mpr111"_flirt".mat \
			--out=${func_root}_${out_img_ext} \
			$func_warp_interp

		niftigz_4dfp -4 ${func_root}_${out_img_ext} ${func_root}_nlin
	endif

	popd
end

# warp defined mask to MNI152_3mm
if ( $redo || ! -e atlas/${patid}_asl_xr3d_atl_dfnd_on_${out_space}_via_fnirt.nii.gz ) then
	pushd atlas

	set aslroot = ${patid}_asl_xr3d_atl
	set dfnd_img = ${aslroot}_dfnd
	set dfnd_img_nlin = ${aslroot}_nlin_dfnd
	nifti_4dfp -n $dfnd_img ${dfnd_img}_on_CAPIIO
	$fslbin/applywarp --ref=${fnirt_ref} --in=${dfnd_img}_on_CAPIIO --warp=../atlas/fnirt/$mpr111"_to_"${out_space}"_fnirt_coeff" --premat=../atlas/fnirt/$mpr333"_to_"$mpr111"_flirt".mat --out=${dfnd_img_nlin} $dfnd_warp_interp
	fslmaths ${dfnd_img_nlin} -mas ${fnirt_ref:r:r}_mask ${dfnd_img_nlin}m
	niftigz_4dfp -4 ${dfnd_img_nlin}m  ${dfnd_img_nlin}m

	popd
endif

exit 0
