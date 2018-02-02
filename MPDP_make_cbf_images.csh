#!/bin/csh

set study_dir = /data/nil-bluearc/black/MPDP
set scripts_dir = /data/nil-bluearc/black/git/asl-scripts
set patids = ( MPD101_s1 MPD103_s1 MPD104_s1 MPD106_s1 MPD107_s1 )
#set patids = ( MPD103_s1 )
set post_ldopa_avg_label = "post_ldopa_avg"

@ redo = 0

set ldopa_effect_average_list = ""
set ldopa_pre_average_list = ""
set ldopa_post_average_list = ""

# make cbf folder with images for every subject
if ( ! -d ${study_dir}/cbf ) mkdir ${study_dir}/cbf

foreach patid ( ${patids} )

	# source .params file
	source ${study_dir}/${patid}/${patid}.params

	# run pcasl_pp.csh
	if ( $redo || ! -e ${study_dir}/${patid}/asl1/${patid}_a1_xr3d_atl.4dfp.img ) then
		pushd ${study_dir}/${patid}
		${scripts_dir}/pcasl_pp.csh \
			${patid}.params \
			../MPDP_instructions.txt
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
	
	# make _cbf.conc
	if ( $redo || ! -e ${study_dir}/${patid}/${patid}_asl_xr3d_atl_brainmasked_cbf.conc ) then
		set conc_list = ""
		pushd ${study_dir}/${patid}
		@ i = 1
		while ( $i <= ${#irun} )
			set conc_list = ( ${conc_list} ${study_dir}/${patid}/asl${irun[$i]}/${patid}_a${irun[$i]}_xr3d_atl_brainmasked_cbf )
			@ i++
		end
		conc_4dfp \
			${patid}_asl_xr3d_atl_brainmasked_cbf \
			"${conc_list}" \
			-w
		popd
	endif
	
	# make 15-40 minute CBF average, CBF ldopa post minus pre image
	if ( $redo || ! -e ${study_dir}/${patid}/${patid}_asl_xr3d_atl_brainmasked_cbf_ldopa_post_minus_pre.4dfp.img ) then
		# get infusion time
		set infusion_time = `cat ${study_dir}/MPDP_infusion_times.csv | grep ${patid} | cut -d"," -f2 | sed "s/://g"`
		pushd ${study_dir}/${patid}
		python2 ${scripts_dir}/python/cbf_average.py \
			./${patid}_asl_xr3d_atl_brainmasked_cbf.conc \
			${post_ldopa_avg_label} \
			${infusion_time}
		imgopr_4dfp \
			-s${patid}_asl_xr3d_atl_brainmasked_cbf_ldopa_post_minus_pre \
			${patid}_asl_xr3d_atl_brainmasked_cbf_${post_ldopa_avg_label} \
			asl${irun[1]}/${patid}_a${irun[1]}_xr3d_atl_brainmasked_cbf_avg
		foreach img ( ${patid}_asl_xr3d_atl_brainmasked_cbf_${post_ldopa_avg_label} ${patid}_asl_xr3d_atl_brainmasked_cbf_ldopa_post_minus_pre )
			nifti_4dfp -n ${img} ${img}.nii
			ln -s ${study_dir}/${patid}/${img}.nii ${study_dir}/cbf/${img}.nii
		end
		popd
	endif

	# make cbf global number tables (pair-wise and average)
	if ( $redo || ! -e ${study_dir}/${patid}/pair_global_numbers.csv || ! -e ${study_dir}/${patid}/avg_global_numbers.csv ) then
		pushd ${study_dir}/${patid}
		${scripts_dir}/global_numbers.csh ${patid}
		popd
	endif

	# make average lists
	set ldopa_effect_average_list = ( ${ldopa_effect_average_list} ../${patid}/${patid}_asl_xr3d_atl_brainmasked_cbf_ldopa_post_minus_pre )
	set ldopa_pre_average_list = ( ${ldopa_pre_average_list} ../${patid}/asl${irun[1]}/${patid}_a${irun[1]}_xr3d_atl_brainmasked_cbf_avg )
	set ldopa_post_average_list = ( ${ldopa_post_average_list} ../${patid}/${patid}_asl_xr3d_atl_brainmasked_cbf_${post_ldopa_avg_label} )
	
end

pushd cbf

# make average images
imgopr_4dfp -eMPDP_pre_ldopa_cbf_average ${ldopa_pre_average_list}
imgopr_4dfp -eMPDP_post_ldopa_cbf_average ${ldopa_post_average_list}
imgopr_4dfp -eMPDP_ldopa_effect_cbf_average ${ldopa_effect_average_list}

foreach img ( MPDP_pre_ldopa_cbf_average MPDP_post_ldopa_cbf_average MPDP_ldopa_effect_cbf_average )
	nifti_4dfp -n $img $img.nii
end

popd

exit 0

