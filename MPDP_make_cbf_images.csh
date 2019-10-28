#!/bin/csh

set study_dir = $cwd
set scripts_dir = /net/zfs-black/BLACK/black/git/asl-scripts

set patids = `find . -maxdepth 1 -type d -name "MPD*_s1"`
set exclusions = ( MPD106_s1 MPD129_s1 MPD128_s1 )

# force using FSL version 5.0.9
setenv FSLDIR /data/nil-bluearc/hershey/unix/software/fsl
set fslbin = ${FSLDIR}/bin

set post_ldopa_avg_label = "post_ldopa_avg"

@ redo = 0
@ normalize_cbf = 1 # 0 = none, 1 = additive, 2 = multiplicative
set smoothing_kernel = ( 1 3 1 )

set ldopa_effect_average_list = ""
set ldopa_pre_average_list = ""
set ldopa_post_average_list = ""
set dfnd_list = ""
set fswb_list = ""

set preblur = 10
set preblur_label = ""
if ( $preblur ) then
	set preblur_label = "_msk_b${preblur}0"
endif


@ num_infusion_times = `cat MPDP_infusion_times.csv | wc -l` - 1
if ( ${#patids} > $num_infusion_times ) then
	echo "Error: infusion time missing for at least one subject. Please update MPDP_infusion_times.csv"
	exit 1
endif

set smoothstr = ""
if ( ${#smoothing_kernel} ) then
	set smooth_str = "--smoothing_kernel $smoothing_kernel"
endif

# make cbf folder with images for every subject
if ( ! -d cbf ) mkdir cbf

# extract select variables from instructions file
#set target = `cat MPDP_instructions.txt | grep target | cut -d "=" -f 2`
#set target =  $target:t
#set nonlinear = `cat MPDP_instructions.txt | grep nonlinear | awk '{print $4}'`

foreach patid ( ${patids} )
	echo "Processing patid: $patid"
	set norm_label = ""
	if ( $normalize_cbf == 1 ) then
		set norm_label = "_shifted"
	else if ( $normalize_cbf == 2 ) then
		set norm_label = "_scaled"
	endif

	# source .params file
	source ${patid}/${patid}.params
	source MPDP_instructions.txt

	if ( ! -e ${FSdir}/scripts/recon-all.done ) then
		echo "Error: freesurfer segmentation needed to process subject. Skipping subject..."
		continue
	endif

	set patid1 = $patid
	if ( ${?day1_patid} ) then
		set patid1 = $day1_patid
	endif

	set T1_str = ""
	if ( -e ${patid}_T1.nii.gz ) then
		set T1 = `fslstats ${patid}_T1.nii.gz -k ${study_dir}/cbf/T1_sphere.nii.gz -M`
		set T1_str = "--T1 $T1"
	endif

	# run pcasl_pp.csh
	if ( $redo || ! -e ${study_dir}/${patid}/asl1/${patid}_a1_xr3d_atl.4dfp.img ) then
		pushd ${study_dir}/${patid}
		${scripts_dir}/pcasl_pp.csh \
			${patid}.params \
			../MPDP_instructions.txt
		popd
	endif

	# generate region masks
	set target = `cat MPDP_instructions.txt | grep target | cut -d "=" -f 2`
	set target =  $target:t
	if ( $redo || ! -e ${patid}/atlas/${patid}_aparc+aseg_on_${target}_333.4dfp.img ) then
		pushd ${study_dir}/${patid}
		Generate_FS_Masks_AZS.csh ${patid}.params ../MPDP_instructions.txt
		popd
	endif



	# calculate pdvars / weights
	if ( $redo || ! -e ${study_dir}/${patid}/movement/pdvars.dat ) then
		pushd ${study_dir}/${patid}

		if ( -e movement/pdvars.dat ) then
			/bin/rm movement/pdvars.dat
		endif

		@ i = 1
		while ( $i <= ${#irun} )
			pushd asl${irun[$i]}
			python2 ${scripts_dir}/python/weighted_dvars.py \
				${patid}_a${irun[$i]}_xr3d_atl.4dfp.img \
				${study_dir}/${patid1}/atlas/${patid1}_FSWB_on_${target}_333.4dfp.img \
				--preblur $preblur
			@ i++
			popd
		end

		pushd movement
		gawk '{c="+";if ($1 > crit)c="x"; printf ("%s",c)}' crit=5.5 pdvars.dat > pdvars.format
		popd

		popd

	endif

	# make movement plot
	if ( $redo || ! -e ${study_dir}/${patid}/movement/mvmt_per_frame_all_runs_plot.png ) then
		pushd ${study_dir}/${patid}/movement
		python2 ${scripts_dir}/python/plot_movement.py $patid
		popd
	endif

	if ( $nonlinear && ( $redo || ! -e ${study_dir}/${patid}/atlas/fnirt ) ) then
		pushd $patid
		if ( -e atlas/fnirt ) then
			/bin/rm -r atlas/fnirt
		endif

		set redo_str = ""
		if ( $redo ) then
			set redo_str = '-redo'
		endif

		${scripts_dir}/nonlinear_warp.csh ${patid}.params ../MPDP_instructions.txt $redo_str
		popd
	endif

	set atl_label = ""
	set reg_label = "_xr3d_atl"
	if ( $nonlinear ) then
		set atl_label = "on_"${fnirt_ref:t:r:r}"_via_fnirt"
		set reg_label = "_xr3d_atl_nlin"
	endif

	# loop over asl scans for each subject, make cbf images
	@ i = 1
	while ( $i <= ${#irun} )
		if ( $redo || ! -e ${patid}/asl${irun[$i]}/${patid}_a${irun[$i]}${reg_label}_brainmasked_cbf.4dfp.img ) then
			pushd ${patid}/asl${irun[$i]}

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


	# make pair time tables
	set inpath_str = ""
	if ( ${?inpath} ) then
		set inpath_str = "--inpath ${inpath}"
	endif
	set infusion_time = `cat ${study_dir}/MPDP_infusion_times.csv | grep ${patid} | cut -d"," -f2 | sed "s/://g"`
	if ( $redo || ! -e ${patid}/cbf_pair_times.csv ) then
		pushd $patid
		python2 ${scripts_dir}/python/pcasl_timing.py \
			${patid} \
			${infusion_time} \
			${inpath_str} \
			-r
		popd
	endif

	# make cbf global number tables (WB/GM/WM, pair-wise and average)
	pushd $patid
	foreach region ( FSWB GM WM )
		if ( $redo || ! -e ${study_dir}/${patid}/pair_global_numbers_${region}.csv ) then
			set region_mask = ${study_dir}/${patid1}/atlas/${patid1}_${region}_on_${target}_333
			if region
			set outroot = ${region_mask}_${atl_label}
			if ( $nonlinear && ! -e ${outroot}.4dfp.img) then
				set warp = `ls ${study_dir}/${patid1}/atlas/fnirt/*mpr*111*to*coeff.nii.gz`
				set premat = `ls  ${study_dir}/${patid1}/atlas/fnirt/*mpr*333*to*mpr*111*.mat`

				nifti_4dfp -n $region_mask $region_mask
				$fslbin/applywarp \
					--ref=$fnirt_ref \
					--in=$region_mask.nii \
-					--warp=$warp \
					--premat=$premat \
					--out=$outroot \
					--interp=nn
				niftigz_4dfp -4 $outroot $outroot
				set region_mask = $outroot
			endif

			set shift_str = ""
			if ( $region == "FSWB" ) then
				set region_mask = ${study_dir}/${patid1}/atlas/${patid1}_asl${reg_label}_dfndm
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
	popd

	# make average run images
	@ i = 1
	while ( $i <= ${#irun} )
		if ( $redo || ! -e ${study_dir}/${patid}/asl${irun[$i]}/${patid}_a${irun[$i]}${reg_label}_brainmasked_cbf${norm_label}_avg_moco.4dfp.img ) then
			pushd ${patid}/asl${irun[$i]}
			set format_str = `cat ../movement/${patid}_a${irun[$i]}_xr3d_atl${preblur_label}_pdvars.format`
			actmapf_4dfp -aavg_moco \
				$format_str \
				${patid}_a${irun[$i]}${reg_label}_brainmasked_cbf${norm_label}

			set avg_moco = ${patid}_a${irun[$i]}${reg_label}_brainmasked_cbf${norm_label}_avg_moco
			nifti_4dfp -n $avg_moco $avg_moco
			popd
		endif
		@ i++
	end

	# get list of cbf images
	set run_list = ""
	@ i = 1
	while ( $i <= ${#irun} )
		set run_list = ( ${run_list} ${study_dir}/${patid}/asl${irun[$i]}/${patid}_a${irun[$i]}${reg_label}_brainmasked_cbf${norm_label} )
		@ i++
	end

	# make histograms
	python2 ${scripts_dir}/python/make_histograms.py \
		$run_list \
		-m ${study_dir}/${patid}/atlas/${patid}_asl${reg_label}_dfndm \
		-r $redo

	# make cbf conc
	if ( $redo || ! -e ${study_dir}/${patid}/${patid}_asl${reg_label}_brainmasked_cbf${norm_label}.conc ) then
		pushd ${study_dir}/${patid}
		conc_4dfp \
			${patid}_asl${reg_label}_brainmasked_cbf${norm_label} \
			"${run_list}" \
			-w
		popd
	endif


	# make 15-40 minute CBF average, CBF ldopa post minus pre image
	if ( $redo || ! -e ${study_dir}/${patid}/${patid}_asl${reg_label}_brainmasked_cbf${norm_label}_ldopa_post_minus_pre.4dfp.img ) then
		# get infusion time
		set infusion_time = `cat ${study_dir}/MPDP_infusion_times.csv | grep ${patid} | cut -d"," -f2 | sed "s/://g"`
		pushd ${study_dir}/${patid}
		python3 ${scripts_dir}/python/cbf_average.py \
			./${patid}_asl${reg_label}_brainmasked_cbf${norm_label}.conc \
			${post_ldopa_avg_label} \
			${infusion_time} \
			--fmtfile movement/pdvars.format
		imgopr_4dfp \
			-s${patid}_asl${reg_label}_brainmasked_cbf${norm_label}_ldopa_post_minus_pre \
			${patid}_asl${reg_label}_brainmasked_cbf${norm_label}_${post_ldopa_avg_label} \
			asl${irun[1]}/${patid}_a${irun[1]}${reg_label}_brainmasked_cbf${norm_label}_avg_moco
		foreach img ( ${patid}_asl${reg_label}_brainmasked_cbf${norm_label}_${post_ldopa_avg_label} ${patid}_asl${reg_label}_brainmasked_cbf${norm_label}_ldopa_post_minus_pre )
			nifti_4dfp -n ${img} ${img}.nii
			ln -s ${study_dir}/${patid}/${img}.nii ${study_dir}/cbf/${img}.nii
		end
		popd
	endif

	# make average lists (excluding excluded subjects and second sessions)
	if ( $patid =~ "*_s1" && ! ( "${exclusions}" =~ "*${patid}*") ) then
		echo $patid
		set ldopa_effect_average_list = ( ${ldopa_effect_average_list} ../${patid}/${patid}_asl${reg_label}_brainmasked_cbf${norm_label}_ldopa_post_minus_pre )
		set ldopa_pre_average_list = ( ${ldopa_pre_average_list} ../${patid}/asl${irun[1]}/${patid}_a${irun[1]}${reg_label}_brainmasked_cbf${norm_label}_avg_moco )
		set ldopa_post_average_list = ( ${ldopa_post_average_list} ../${patid}/${patid}_asl${reg_label}_brainmasked_cbf${norm_label}_${post_ldopa_avg_label} )
		set dfnd_list = ( ${dfnd_list} ../${patid}/atlas/${patid}_asl${reg_label}_dfndm.4dfp.img )
		set fswb_list = ( $fswb_list ../${patid}/atlas/${patid}_FSWB_on_${target}_333_${atl_label}.4dfp.img )
	endif
end

# # create combined global number files for all subjects (WB, GM, WM)
# foreach region ( WB GM WM )
# 	find . -type f -name "pair_global_numbers_${region}.csv" -exec awk 'FNR==1 && NR!=1{next;}{print}' {} + > all_pair_global_numbers_${region}.csv
# 	find . -type f -name "avg_global_numbers_${region}.csv" -exec awk 'FNR==1 && NR!=1{next;}{print}' {} + > all_avg_global_numbers_${region}.csv
# end


pushd cbf

# make voi files and plots
#if ( ! -e voi_analysis ) then
#	mkdir voi_analysis
#endif

#pushd voi_analysis
#${scripts_dir}/gen_activity_curves.csh $redo
#python3 ${scripts_dir}/python/average_TAC.py
#popd


# make average images
imgopr_4dfp -eMPDP_pre_ldopa_cbf_average${norm_label} ${ldopa_pre_average_list}
imgopr_4dfp -eMPDP_post_ldopa_cbf_average${norm_label} ${ldopa_post_average_list}
imgopr_4dfp -eMPDP_ldopa_effect_cbf_average${norm_label} ${ldopa_effect_average_list}

#make FSWB mask

# sum FSWB images
imgopr_4dfp -as1_FSWB_sum $fswb_list

# multiply dfnd images
imgopr_4dfp -ps1_dfnd_product $dfnd_list

# mask FSWB sum by dfnd images, burned-in mask value of 1.0
maskimg_4dfp s1_FSWB_sum s1_dfnd_product s1_FSWB_temp
maskimg_4dfp -v1.0 s1_FSWB_temp s1_FSWB_temp s1_FSWB_mask
nifti_4dfp -n s1_FSWB_mask s1_FSWB_mask.nii

/bin/rm s1_FSWB_temp.*

# mask average images
foreach img ( MPDP_pre_ldopa_cbf_average${norm_label} MPDP_post_ldopa_cbf_average${norm_label} MPDP_ldopa_effect_cbf_average${norm_label} )
	maskimg_4dfp ${img} s1_FSWB_mask.4dfp.img ${img}_dfnd
	nifti_4dfp -n ${img}_dfnd ${img}_dfnd.nii
end

popd

exit 0
