#!/bin/csh

set scripts_dir = /data/nil-bluearc/black/git/asl-scripts/python
set outdir = $pwd

set patids = `find . -maxdepth 1 -type d -name "MPD*"`
set redo = $1

if ( ${#argv} > 1) then
	echo "Usage: gen_activity_curves.csh [redo]"
	exit 1
endif

@ redo = 0
if ( ${#argv} == 1 ) then
	@ redo = $1
endif

echo 'patid,min_since_infusion,midbrain_avg,pdvars' > $outfile
foreach patid ( $patids )
	pushd ${patid}
	foreach roi ( "midbrain_20180822" )
		if ( $redo || ! -e ${patid}_${roi}_tac.png ) then
			python ${scripts_dir}/activity_curve.py \
				${patid}_asl_xr3d_atl_brainmasked_cbf_shifted_msk.conc \
				${outdir}/${roi}_ROI.4dfp.img \
				${roi} 

		endif
		awk 'NR>1' ${patid}_${roi}_tac.csv >> ${outdir}/${region}_tac.csv
	end
	popd
	
end
