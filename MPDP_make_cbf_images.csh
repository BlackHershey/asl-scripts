#!/bin/csh

set study_dir = $cwd
set scripts_dir = /net/zfs-black/BLACK/black/git/asl-scripts

set patids = `find . -maxdepth 1 -type d -name "MPD*_s1"`
set exclusions = ( MPD106_s1 MPD129_s1 MPD128_s1 )

set post_ldopa_avg_label = "post_ldopa_avg"

set ldopa_effect_average_list = ""
set ldopa_pre_average_list = ""
set ldopa_post_average_list = ""
set dfnd_list = ""
set fswb_list = ""

@ num_infusion_times = `cat MPDP_infusion_times.csv | wc -l` - 1
if ( ${#patids} > $num_infusion_times ) then
	echo "Error: infusion time missing for at least one subject. Please update MPDP_infusion_times.csv"
	exit 1
endif


# make cbf folder with images for every subject
if ( ! -d cbf ) mkdir cbf

foreach patid ( ${patids} )
	pushd $patid

	# execute main CBF processing script
	source ${scripts_dir}/make_cbf_images.csh ${patid}.params ${study_dir}/MPDP_instructions.txt

	# make pair time tables
	set inpath_str = ""
	if ( ${?inpath} ) then
		set inpath_str = "--inpath ${inpath}"
	endif
	set infusion_time = `cat ${study_dir}/MPDP_infusion_times.csv | grep ${patid} | cut -d"," -f2 | sed "s/://g"`
	if ( $redo || ! -e ${patid}/cbf_pair_times.csv ) then
		python3 ${scripts_dir}/analysis/pcasl_timing.py \
			${patid} \
			${infusion_time} \
			${inpath_str} \
			-r
	endif

	# make pdvars weighted pre-LD  average
	if ( $redo || ! -e ${conc_root}_pre_ldopa_avg_moco_wt.4dfp.img ) then
		@ preLD_frames = `cat movement/${patid}_a1_xr3d_atl_msk_b${anat_aveb}0_pdvars.format | wc -m`
		@ total_frames = `cat movement/pdvars.dat | wc -l`
		@ exclude_frames = `expr $total_frames - $preLD_frames`
		set fmtstr = `format2lst -e ${preLD_frames}+${exclude_frames}x`
		python3 ${scripts_dir}/analysis/weighted_average.py \
			--conc ${conc_root}.conc \
			--trailer pre_ldopa \
			--fmtstr $fmtstr
	endif


	# make 15-40 minute CBF average, CBF ldopa post minus pre image
	if ( $redo || ! -e ${study_dir}/${patid}/${patid}_asl${reg_label}_brainmasked_cbf${norm_label}_ldopa_post_minus_pre.4dfp.img ) then
		# get infusion time
		set infusion_time = `cat ${study_dir}/MPDP_infusion_times.csv | grep ${patid} | cut -d"," -f2 | sed "s/://g"`
		python3 ${scripts_dir}/analysis/post_ld_average.py \
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
	endif

	# make average lists (excluding excluded subjects and second sessions)
	if ( $patid =~ "*_s1" && ! ( "${exclusions}" =~ "*${patid}*") ) then
		set ldopa_effect_average_list = ( ${ldopa_effect_average_list} ${patid}_asl${reg_label}_brainmasked_cbf${norm_label}_ldopa_post_minus_pre )
		set ldopa_pre_average_list = ( ${ldopa_pre_average_list} asl${irun[1]}/${patid}_a${irun[1]}${reg_label}_brainmasked_cbf${norm_label}_avg_moco )
		set ldopa_post_average_list = ( ${ldopa_post_average_list} ${patid}_asl${reg_label}_brainmasked_cbf${norm_label}_${post_ldopa_avg_label} )
		set dfnd_list = ( ${dfnd_list} atlas/${patid}_asl${reg_label}_dfndm.4dfp.img )
		set fswb_list = ( $fswb_list atlas/${patid}_FSWB_on_${target}_333_${atl_label}.4dfp.img )
	endif

	popd
end

# create combined global number files for all subjects (WB, GM, WM)
foreach region ( WB GM WM )
	find . -type f -name "pair_global_numbers_${region}.csv" -exec awk 'FNR==1 && NR!=1{next;}{print}' {} + > all_pair_global_numbers_${region}.csv
	find . -type f -name "avg_global_numbers_${region}.csv" -exec awk 'FNR==1 && NR!=1{next;}{print}' {} + > all_avg_global_numbers_${region}.csv
end

pushd cbf

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
