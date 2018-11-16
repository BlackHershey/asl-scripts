#!/bin/csh

set study_dir = /data/nil-bluearc/black/MPDP
set scripts_dir = /data/nil-bluearc/black/git/asl-scripts
set fs_subjects_dir = ${study_dir}/freesurfer

set patids = `find . -maxdepth 1 -type d -name "MPD*"`
set exclusions = ( MPD106_s1 )

set post_ldopa_avg_label = "post_ldopa_avg"
@ redo = 1
@ normalize_cbf = 1 # 0 = none, 1 = additive, 2 = multiplicative

set ldopa_effect_average_list = ""
set ldopa_pre_average_list = ""
set ldopa_post_average_list = ""
set dfndm_list = ""

set preblur = 10
set preblur_label = ""
if ( $preblur ) then
	set preblur_label = "_msk_b${preblur}0"
endif


@ num_infusion_times = `cat ${study_dir}/MPDP_infusion_times.csv | wc -l` - 1
if ( ${#patids} > $num_infusion_times ) then
	echo "Error: infusion time missing for at least one subject. Please update MPDP_infusion_times.csv"
	exit 1
endif

@ num_completed_fs = `l $fs_subjects_dir/*MPD*/scripts/recon-all.done | wc -l`
@ num_first_sessions = `ls -d MPD*_s1 | wc -l`
if ( $num_first_sessions > $num_completed_fs ) then
	echo "Error: freesurfer segmentation needed for all participants before running script"
	exit 1
endif

# make cbf folder with images for every subject
if ( ! -d ${study_dir}/cbf ) mkdir ${study_dir}/cbf

foreach patid ( ${patids} )

	set norm_label = ""
	if ( $normalize_cbf == 1 ) then
		set norm_label = "_shifted"
	else if ( $normalize_cbf == 2 ) then
		set norm_label = "_scaled"
	endif

	# source .params file
	source ${study_dir}/${patid}/${patid}.params

	set patid1 = $patid
	if ( ${?day1_patid} ) then
		set patid1 = $day1_patid
	endif

	# run pcasl_pp.csh
	if ( $redo || ! -e ${study_dir}/${patid}/asl1/${patid}_a1_xr3d_atl.4dfp.img ) then
		pushd ${study_dir}/${patid}
		${scripts_dir}/pcasl_pp.csh \
			${patid}.params \
			../MPDP_instructions.txt

		set target = `cat ../MPDP_instructions.txt | grep target | cut -d "=" -f 2`
		set target =  $target:t
		if ( $redo || ! -e atlas/${patid}_aparc+aseg_on_${target}_333.4dfp.img ) then
			Generate_FS_Masks_AZS.csh ${patid}.params ../MPDP_instructions.txt
		endif

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
				${study_dir}/${patid1}/atlas/${patid1}_FSWB_on_CAPIIO_333.4dfp.img \
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

	# loop over asl scans for each subject, make cbf images
	@ i = 1
	while ( $i <= ${#irun} )
		if ( $redo || ! -e ${patid}/asl${irun[$i]}/${patid}_a${irun[$i]}_xr3d_atl_brainmasked_cbf.4dfp.img ) then
			pushd ${patid}/asl${irun[$i]}

			python2 ${scripts_dir}/python/pcasl_cbf.py \
				${patid}_a${irun[$i]}_xr3d_atl.4dfp.img \
				../atlas/${patid}_asl_xr3d_atl_dfndm.4dfp.img
			popd
		endif
		@ i++
	end

	# make pair time tables
	set infusion_time = `cat ${study_dir}/MPDP_infusion_times.csv | grep ${patid} | cut -d"," -f2 | sed "s/://g"`
	if ( $redo || ! -e ${patid}/cbf_pair_times.csv ) then
		python2 ${scripts_dir}/python/pcasl_timing.py ${patid} ${infusion_time} -r
	endif

	# make cbf global number tables (WB/GM/WM, pair-wise and average)
	pushd ${study_dir}/${patid}
	foreach region ( WB GM WM )
		if ( $redo || ! -e ${study_dir}/${patid}/pair_global_numbers_${region}.csv || ! -e ${study_dir}/${patid}/avg_global_numbers_${region}.csv ) then
			set region_mask = ${study_dir}/${patid1}/atlas/${patid1}_${region}_on_${target}_333.4dfp.img
			if ( $region == "WB" ) then
				set region_mask = ${study_dir}/${patid1}/atlas/${patid1}_asl_xr3d_atl_dfndm.4dfp.img
			endif			
			${scripts_dir}/global_numbers.csh ${patid} ${region_mask} ${region}
		endif
	end
	popd


	# normalize cbf images
	if ( $norm_label != "" ) then
		${scripts_dir}/normalize_cbf_pairs.csh \
			$patid \
			$norm_label \
			../atlas/${patid}_asl_xr3d_atl_dfndm.4dfp.img \
			$redo
		set norm_label = ${norm_label}_msk
	endif

	# make average run images
	@ i = 1
	while ( $i <= ${#irun} )
		if ( $redo || ! -e ${study_dir}/${patid}/asl${irun[$i]}/${patid}_a${irun[$i]}_xr3d_atl_brainmasked_cbf${norm_label}_avg_moco.4dfp.img ) then
			pushd ${patid}/asl${irun[$i]}
			set format_str = `cat ../movement/${patid}_a${irun[$i]}_xr3d_atl${preblur_label}_pdvars.format`
			actmapf_4dfp -aavg_moco \
				$format_str \
				${patid}_a${irun[$i]}_xr3d_atl_brainmasked_cbf${norm_label}
			popd
		endif
		@ i++
	end

	# get list of cbf images
	set run_list = ""
	@ i = 1
	while ( $i <= ${#irun} )
		set run_list = ( ${run_list} ${study_dir}/${patid}/asl${irun[$i]}/${patid}_a${irun[$i]}_xr3d_atl_brainmasked_cbf${norm_label} )
		@ i++
	end

	# make histograms
	python2 ${scripts_dir}/python/make_histograms.py \
		$run_list \
		-m ${study_dir}/${patid}/atlas/${patid}_asl_xr3d_atl_dfndm \
		-r $redo

	# make cbf conc
	if ( $redo || ! -e ${study_dir}/${patid}/${patid}_asl_xr3d_atl_brainmasked_cbf${norm_label}.conc ) then
		pushd ${study_dir}/${patid}
		conc_4dfp \
			${patid}_asl_xr3d_atl_brainmasked_cbf${norm_label} \
			"${run_list}" \
			-w
		popd
	endif


	# make 15-40 minute CBF average, CBF ldopa post minus pre image
	if ( 1 || ! -e ${study_dir}/${patid}/${patid}_asl_xr3d_atl_brainmasked_cbf${norm_label}_ldopa_post_minus_pre.4dfp.img ) then
		# get infusion time
		set infusion_time = `cat ${study_dir}/MPDP_infusion_times.csv | grep ${patid} | cut -d"," -f2 | sed "s/://g"`
		pushd ${study_dir}/${patid}
		python3 ${scripts_dir}/python/cbf_average.py \
			./${patid}_asl_xr3d_atl_brainmasked_cbf${norm_label}.conc \
			${post_ldopa_avg_label} \
			${infusion_time} \
			--fmtfile movement/pdvars.format
		imgopr_4dfp \
			-s${patid}_asl_xr3d_atl_brainmasked_cbf${norm_label}_ldopa_post_minus_pre \
			${patid}_asl_xr3d_atl_brainmasked_cbf${norm_label}_${post_ldopa_avg_label} \
			asl${irun[1]}/${patid}_a${irun[1]}_xr3d_atl_brainmasked_cbf${norm_label}_avg_moco
		foreach img ( ${patid}_asl_xr3d_atl_brainmasked_cbf${norm_label}_${post_ldopa_avg_label} ${patid}_asl_xr3d_atl_brainmasked_cbf${norm_label}_ldopa_post_minus_pre )
			nifti_4dfp -n ${img} ${img}.nii
			ln -s ${study_dir}/${patid}/${img}.nii ${study_dir}/cbf/${img}.nii
		end
		popd
	endif

	# make average lists (excluding excluded subjects and second sessions)
	if ( $patid =~ "*_s1" && ! ( "${exclusions}" =~ "${patid}") ) then
		echo $patid
		set ldopa_effect_average_list = ( ${ldopa_effect_average_list} ../${patid}/${patid}_asl_xr3d_atl_brainmasked_cbf${norm_label}_ldopa_post_minus_pre )
		set ldopa_pre_average_list = ( ${ldopa_pre_average_list} ../${patid}/asl${irun[1]}/${patid}_a${irun[1]}_xr3d_atl_brainmasked_cbf${norm_label}_avg )
		set ldopa_post_average_list = ( ${ldopa_post_average_list} ../${patid}/${patid}_asl_xr3d_atl_brainmasked_cbf${norm_label}_${post_ldopa_avg_label} )
		set dfndm_list = ( ${dfndm_list} ../${patid}/atlas/${patid}_asl_xr3d_atl_dfndm.4dfp.img ) 	
	endif
end

# create combined global number files for all subjects (WB, GM, WM)
foreach region ( WB GM WM )
	find . -type f -name "pair_global_numbers_${region}.csv" -exec awk 'FNR==1 && NR!=1{next;}{print}' {} + > all_pair_global_numbers_${region}.csv
	find . -type f -name "avg_global_numbers_${region}.csv" -exec awk 'FNR==1 && NR!=1{next;}{print}' {} + > all_avg_global_numbers_${region}.csv
end

# make voi files and plots
${scripts_dir}/gen_activity_curves.csh $redo
python3 ${scripts_dir}/python/average_TAC.py 

pushd cbf

# make average images
imgopr_4dfp -eMPDP_pre_ldopa_cbf_average${norm_label} ${ldopa_pre_average_list}
imgopr_4dfp -eMPDP_post_ldopa_cbf_average${norm_label} ${ldopa_post_average_list}
imgopr_4dfp -eMPDP_ldopa_effect_cbf_average${norm_label} ${ldopa_effect_average_list}

foreach img ( MPDP_pre_ldopa_cbf_average${norm_label} MPDP_post_ldopa_cbf_average${norm_label} MPDP_ldopa_effect_cbf_average${norm_label} )
	maskimg_4dfp ${img} s1_FSWB_mask.4dfp.img ${img}_dfnd
	nifti_4dfp -n ${img}_dfnd ${img}_dfnd.nii
end

popd

exit 0
