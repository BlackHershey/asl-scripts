#!/bin/csh

set scripts_dir = /net/zfs-black/BLACK/black/git/asl-scripts

set program = $0; set program = $program:t
if (${#argv} != 2) then
	echo "usage:	"$program" params_file instructions_file"
	exit 1
endif
set params_file = $1
echo "params_file="$params_file

if (! -e $params_file) then
	echo $program": "$params_file not found
	exit -1
endif
source $params_file
set instructions_file = ""
if (${#argv} > 1) then
	set instructions_file = $2
	if (! -e $instructions_file) then
		echo $program": "$instructions_file not found
		exit -1
	endif
	cat $instructions_file
	source $instructions_file
endif

if ( ! ${?redo} ) @ redo = 0

set pdvars_label = ""
set preblur_str = ""
if ( ! ${?anat_aveb} ) set anat_aveb = 0
if ( ! $anat_aveb ) then
	set pdvars_label = "_msk_b${anat_aveb}0"
	set preblur_str = "--preblur ${anat_aveb}"
endif

set crit_str = ""
if ( ! ${?anat_avet} ) set anat_avet = 500
set crit_str = "--crit ${anat_avet}"

if ( ! ${?normalize_cbf} ) then
	set norm_label = ""
	set normalize_cbf = 0
else if ( $normalize_cbf == 1 ) then
	set norm_label = "_shifted"
else if ( $normalize_cbf == 2 ) then
	set norm_label = "_scaled"
endif

if ( ! -e ${FSdir}/scripts/recon-all.done ) then
	echo "Error: freesurfer segmentation needed to process subject. Skipping subject..."
	exit 1
endif

if ( ! ${?day1_patid} ) then
	set day1_patid = $patid
	set day1_path = ${cwd}/atlas # FIXME
endif

set T1_str = ""
if ( -e ${patid}_T1.nii.gz ) then
	set T1 = `fslstats ${patid}_T1.nii.gz -k ../cbf/T1_sphere.nii.gz -M`
	set T1_str = "--T1 $T1"
endif

set atl_label = ""
set reg_label = "_xr3d_atl"
if ( ! ${?nonlinear} ) @ nonlinear = 0
if ( $nonlinear ) then
	set atl_label = "on_"${fnirt_ref:t:r:r}"_via_fnirt"
	set reg_label = "_xr3d_atl_nlin"``
endif


# Preprocess pcasl (run pcasl_pp.csh)
if ( $redo || ! -e asl1/${patid}_a1_xr3d_atl.4dfp.img ) then
	${scripts_dir}/pcasl_pp.csh \
		$params_file \
		$instructions_file
endif

# generate region masks
set target =  $target:t
if ( $redo || ! -e atlas/${patid}_aparc+aseg_on_${target}_333.4dfp.img ) then
	Generate_FS_Masks_AZS.csh $params_file $instructions_file
endif

# calculate pdvars / weights
if ( $redo || ! -e movement/pdvars.dat ) then
	if ( -e movement/pdvars.dat ) then
		/bin/rm movement/pdvars.dat
	endif

	@ i = 1
	while ( $i <= ${#irun} )
		pushd asl${irun[$i]}
		python2 ${scripts_dir}/python/weighted_dvars.py \
			${patid}_a${irun[$i]}_xr3d_atl.4dfp.img \
			${day1_path}/${day1_patid}_FSWB_on_${target}_333.4dfp.img \
			${preblur_str} \
			${crit_str}
		@ i++
		popd
	end

	# pushd movement
	# gawk '{c="+";if ($1 > crit)c="x"; printf ("%s",c)}' crit=${anat_avet} pdvars.dat > pdvars.format
	# popd
endif

# make movement plot
if ( $redo || ! -e movement/mvmt_per_frame_all_runs_plot.png ) then
	pushd movement
	python2 ${scripts_dir}/python/plot_movement.py $patid
	popd
endif

if ( $nonlinear && ( $redo || ! -e atlas/fnirt ) ) then
	if ( -e atlas/fnirt ) then
		/bin/rm -r atlas/fnirt
	endif
	${scripts_dir}/nonlinear_warp.csh $params_file $instructions_file -3mm
endif

# loop over asl scans for each subject, make cbf images
set smooth_str = ""
if ( ! ${?smoothing_kernel} ) set smoothing_kernel = ()
if ( ${#smoothing_kernel} ) then
	set smooth_str = "--smoothing_kernel $smoothing_kernel"
endif

@ i = 1
while ( $i <= ${#irun} )
	if ( $redo || ! -e asl${irun[$i]}/${patid}_a${irun[$i]}${reg_label}_brainmasked_cbf.4dfp.img ) then
		pushd asl${irun[$i]}

		maskimg_4dfp -1 ${patid}_a${irun[$i]}${reg_label} ../atlas/${patid}_asl${reg_label}_dfndm ${patid}_a${irun[$i]}${reg_label}_brainmasked
		nifti_4dfp -n ${patid}_a${irun[$i]}${reg_label}_brainmasked ${patid}_a${irun[$i]}${reg_label}_brainmasked

		python3 ${scripts_dir}/python/pcasl_cbf_v2.py \
			${patid} \
			${i} \
			${patid}_a${irun[$i]}${reg_label}_brainmasked.nii \
			$smooth_str \
			$T1_str

		foreach trailer ( "" "_avg" )
			nifti_4dfp -4 ${patid}_a${irun[$i]}${reg_label}_brainmasked_cbf${trailer} ${patid}_a${irun[$i]}${reg_label}_brainmasked_cbf${trailer}
		end

		popd
	endif
	@ i++
end

# make cbf global number tables and noramlize cbf pairs (WB/GM/WM, pair-wise and average)
foreach region ( FSWB GM WM )
	if ( $redo || ! -e pair_global_numbers_${region}.csv ) then
		set region_mask = ${day1_path}/${day1_patid}_${region}_on_${target}_333
		set outroot = ${region_mask}_${atl_label}
		if ( $nonlinear ) then
			if (! -e ${outroot}.4dfp.img) then
				set warp = `ls ${day1_path}/fnirt/*mpr*111*to*coeff.nii.gz`
				set premat = `ls  ${day1_path}/fnirt/*mpr*333*to*mpr*111*.mat`

				nifti_4dfp -n $region_mask $region_mask
				$fslbin/applywarp \
					--ref=$fnirt_ref \
					--in=$region_mask.nii \
	-				--warp=$warp \
					--premat=$premat \
					--out=$outroot \
					--interp=nn
				niftigz_4dfp -4 $outroot $outroot
			endif
			set region_mask = $outroot
		endif

		if ( ! -e ${region_mask}.nii.gz ) niftigz_4dfp -n ${region_mask} ${region_mask}

		set shift_str = ""
		if ( $region == "FSWB" ) then
			set region_mask = ${day1_path}/${day1_patid}_asl${reg_label}_dfndm
			set region = "WB"
			set shift_str = "--shift "$normalize_cbf
		endif

		set global_num_outfile = pair_global_numbers_${region}.csv
		echo 'patid,run,frame,smoothmode' > $global_num_outfile
		@ i = 1
		while ( $i <= ${#irun} )
			pushd asl${irun[$i]}
				python3 ${scripts_dir}/python/normalize_cbf_pairs.py \
					${patid}_a${irun[$i]}${reg_label}_brainmasked_cbf.nii \
					--mask ${region_mask}.nii.gz\
					$shift_str \
					| tee -a ../${global_num_outfile}

				set normalized_img = ${patid}_a${irun[$i]}${reg_label}_brainmasked_cbf${norm_label}
				if ( -e ${normalized_img}.nii ) then
					nifti_4dfp -4 $normalized_img $normalized_img
				endif
			popd
			@ i++
		end
	endif
end

# make average run images
pushd movement
set weight_file = pdvars_weights.txt
cut -f2 pdvars.dat > $weight_file
popd

@ i = 1
while ( $i <= ${#irun} )
	set format_str = `cat movement/${patid}_a${irun[$i]}*${pdvars_label}_pdvars.format`

	pushd asl${irun[$i]}
	if ( $redo || ! -e ${patid}_a${irun[$i]}${reg_label}_brainmasked_cbf${norm_label}_avg_moco.4dfp.img ) then
		actmapf_4dfp -aavg_moco \
			$format_str \
			${patid}_a${irun[$i]}${reg_label}_brainmasked_cbf${norm_label}
	endif
	# if ( $redo || ! -e ${patid}_a${irun[$i]}${reg_label}_brainmasked_cbf${norm_label}_avgw.4dfp.img ) then
		set num_frames =  `echo $format_str | wc -m`
		set start_frame =
		cut -f2 ../movement/pdvars.dat | sed -n ""
		actmapf_4dfp -aavgw \
			${num_frames}+ \
			${patid}_a${irun[$i]}${reg_label}_brainmasked_cbf${norm_label} \
			-w../movement/$weight_file \
			-c$num_frames # scale by num frames to undo averaging (we actually want sum of weights)
	# endif
	popd
	@ i++
end

# get list of cbf images
set run_list = ""
@ i = 1
while ( $i <= ${#irun} )
	set run_list = ( ${run_list} asl${irun[$i]}/${patid}_a${irun[$i]}${reg_label}_brainmasked_cbf${norm_label} )
	@ i++
end

# make histograms
python2 ${scripts_dir}/python/make_histograms.py \
	$run_list \
	-m atlas/${patid}_asl${reg_label}_dfndm \
	-r $redo

# make cbf conc
if ( ${#irun} > 1 && ($redo || ! -e ${patid}_asl${reg_label}_brainmasked_cbf${norm_label}.conc) ) then
	conc_4dfp \
		${patid}_asl${reg_label}_brainmasked_cbf${norm_label} \
		"${run_list}" \
		-w
endif

exit 0