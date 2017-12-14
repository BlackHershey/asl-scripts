#!/bin/csh -f

# NOTE: this script was copied and then edited from Avi's cross_bold_pp_161012.csh

set program = $0; set program = $program:t
echo $program $argv[1-]

if (${#argv} != 2) then
	echo "usage:	"$program" params_file instructions_file"
	exit 1
endif
set prmfile = $1
echo "prmfile="$prmfile

if (! -e $prmfile) then
	echo $program": "$prmfile not found
	exit -1
endif
source $prmfile
set instructions = ""
if (${#argv} > 1) then
	set instructions = $2
	if (! -e $instructions) then
		echo $program": "$instructions not found
		exit -1
	endif
	cat $instructions
	source $instructions
endif

##########
# check OS
##########
set OS = `uname -s`
if ($OS != "Linux") then
	echo $program must be run on a linux machine
	exit -1
endif

if ($target:h != $target) then
	set tarstr = -T$target
else
	set tarstr = $target
endif

@ runs = ${#irun}
if ($runs != ${#pcasl}) then
	echo "irun pcasl mismatch - edit "$prmfile
	exit -1
endif

if (! ${?scrdir}) set scrdir = ""
@ usescr = `echo $scrdir | awk '{print length ($1)}'`
if ($usescr) then
	if (! -e $scrdir) mkdir $scrdir
	if ($status) exit $status
endif
set sourcedir = $cwd
if (! ${?sorted}) @ sorted = 0

if (! ${?E4dfp}) @ E4dfp = 0
if (${E4dfp}) then
	echo "4dfp files have been pre-generated. Option E4dfp set with value $E4dfp. Skipping dcm_to_4dfp"
endif

if (! ${?use_anat_ave}) @ use_anat_ave = 1
if ($use_anat_ave) then
	set epi_anat = $patid"_asl_M0_ave"
else
	set epi_anat = $patid"_func_vols_ave"
endif

if (! ${?day1_patid}) set day1_patid = "";
if ($day1_patid != "") then
	set patid1	= $day1_patid
	set day1_path	= `echo $day1_path | sed 's|/$||g'`
else
	set patid1	= $patid
endif

if (${?goto_UNWARP}) goto UNWARP

##########
# settings
##########
set M0_max_intensity = "2000"

date
####################
# process pCASL data
####################

@ err = 0
@ k = 1
while ($k <= $runs)
	if (! $E4dfp) then
		if ($usescr) then		# test to see if user requested use of scratch disk
			if (-e asl$irun[$k]) /bin/rm asl$irun[$k]	# remove existing link
			if (! -d $scrdir/asl$irun[$k]) mkdir $scrdir/asl$irun[$k]
			ln -s $scrdir/asl$irun[$k] asl$irun[$k]
		else
			if (! -d asl$irun[$k]) mkdir asl$irun[$k]
		endif
	endif
	pushd asl$irun[$k]
	set y = $patid"_a"$irun[$k]
	if (-e $y.4dfp.img && -e $y.4dfp.ifh) goto POP
	if (! $E4dfp) then
		if ($sorted) then
			echo		dcm_to_4dfp -q -b study$pcasl[$k] $inpath/study$pcasl[$k]
			if ($go)	dcm_to_4dfp -q -b study$pcasl[$k] $inpath/study$pcasl[$k]
		else
			echo		dcm_to_4dfp -q -b study$pcasl[$k] $inpath/$dcmroot.$pcasl[$k]."*"
			if ($go)	dcm_to_4dfp -q -b study$pcasl[$k] $inpath/$dcmroot.$pcasl[$k].*
		endif
	endif
	if (${?nounpack}) goto FA
	echo		unpack_4dfp -V study$pcasl[$k] $patid"_a"$irun[$k] -nx$nx -ny$ny
	if ($go)	unpack_4dfp -V study$pcasl[$k] $patid"_a"$irun[$k] -nx$nx -ny$ny
	if ($status) then
		@ err++
		/bin/rm $patid"_a"$irun[$k]*
		goto POP
	endif
	echo		/bin/rm  study$pcasl[$k]."*"
	if ($go)	/bin/rm  study$pcasl[$k].*
POP:
	popd	# out of asl$irun[$k]
	@ k++
end
if ($err) then
	echo $program": one or more ASL runs failed preliminary processing"
	exit -1
endif
if ($epi2atl == 2) goto ATL

if (-e  $patid"_asl_xr3d".lst)	/bin/rm $patid"_asl_xr3d".lst;	touch $patid"_asl_xr3d".lst
@ k = 1
while ($k <= $runs)
	echo asl$irun[$k]/$patid"_a"$irun[$k] >>	$patid"_asl_xr3d".lst
	echo asl$irun[$k]/$patid"_a"$irun[$k]"_xr3d" >> $patid"_asl_M0".lst
	@ k++
end

echo cat	$patid"_asl_xr3d".lst
cat		$patid"_asl_xr3d".lst

# make normode = 0
@ normode = 0

# use first frame as reference (M0)
@ ref_frame = 1

# cross-realign EPI frames
echo		cross_realign3d_4dfp -c -r$ref_frame -qv$normode -l$patid"_asl_xr3d".lst
if ($go)	cross_realign3d_4dfp -c -r$ref_frame -qv$normode -l$patid"_asl_xr3d".lst
if ($status)	exit $status

date
###################
# movement analysis
###################
if (! -d movement) mkdir movement
if (! ${?lomotil}) then
	set lstr = ""
else
	set lstr = "-l$lomotil TR_vol=$TR_vol"
endif
@ k = 1
while ($k <= $runs)
	echo		mat2dat asl$irun[$k]/"*_xr3d".mat -RD -n$skip $lstr
	if ($go)	mat2dat asl$irun[$k]/*"_xr3d".mat -RD -n$skip $lstr
	echo		/bin/mv asl$irun[$k]/"*_xr3d.*dat"	movement
	if ($go)	/bin/mv asl$irun[$k]/*"_xr3d".*dat	movement
	@ k++
end

date

if (! -d atlas) mkdir atlas
######################################
# make first frame (M0 anatomy) image
######################################
echo cat	$patid"_asl_M0".lst
cat		$patid"_asl_M0".lst
echo		paste_4dfp -p1 $patid"_asl_M0".lst	$patid"_asl_M0_ave"
if ($go)	paste_4dfp -p1 $patid"_asl_M0".lst	$patid"_asl_M0_ave"
echo		ifh2hdr	-r${M0_max_intensity}				$patid"_asl_M0_ave"
if ($go)	ifh2hdr	-r${M0_max_intensity}				$patid"_asl_M0_ave"
echo		/bin/mv $patid"_asl_M0*" atlas
if ($go)	/bin/mv $patid"_asl_M0"* atlas

########################
# more movement analysis
########################
pushd movement
if (-e ${patid}"_xr3d".FD) /bin/rm	${patid}"_xr3d".FD
touch						${patid}"_xr3d".FD
@ k = 1
while ($k <= $runs)
	gawk -f $RELEASE/FD.awk $patid"_a"$irun[$k]"_xr3d".ddat >> ${patid}"_xr3d".FD
	@ k++
end
if ($?FDthresh) then
	if (! $?FDtype) set FDtype = 1
	conc2format ../atlas/${patid}_func_vols.conc $skip | xargs format2lst > $$.format0
	gawk '{c="+";if ($'$FDtype' > crit)c="x"; printf ("%s\n",c)}' crit=$FDthresh ${patid}"_xr3d".FD > $$.format1
	paste $$.format0 $$.format1 | awk '{if($1=="x")$2="x";printf("%s",$2)}' > ${patid}"_xr3d".FD.format
	/bin/rm $$.format0 $$.format1
	/bin/mv ${patid}"_xr3d".FD.format ../atlas/
endif
popd

pushd atlas		# into atlas
if (! ${?anat_aveb}) set anat_aveb = 0.
if (! ${?anat_avet}) then			# set anat_avet excessively high if you wish not to use DVARS as a frame censoring technique
	set xstr = ""				# compute threshold using find_dvar_crit.awk
else
	set xstr = -x$anat_avet
endif
set  format = `conc2format ${patid}_func_vols.conc $skip`
echo $format >! ${patid}_func_vols.format

if ($status) exit $status
nifti_4dfp -n ${patid}_asl_M0_ave ${patid}_asl_M0_ave
$FSLDIR/bin/bet ${patid}_asl_M0_ave.nii ${patid}_asl_M0_ave_msk -f 0.3
if ($status) exit $status
niftigz_4dfp -4  ${patid}_asl_M0_ave_msk.nii.gz  ${patid}_asl_M0_ave_msk

if ($?FDthresh) then
	format2lst ${patid}_func_vols.format > $$.format1
	format2lst ${patid}"_xr3d".FD.format > $$.format2
	paste $$.format1 $$.format2 | gawk '{if($1=="x")$2="x";printf("%s",$2);}' | xargs condense  > ${patid}_func_vols.format
	rm $$.format1 $$.format2
endif

if ($status) exit $status

##########################################
# compute cross-day $epi_anat registration
##########################################
if ($day1_patid != "") then
	set stretch_flag = ""
	if (! ${?cross_day_nostretch}) @ cross_day_nostretch = 0;
	if ($cross_day_nostretch) set stretch_flag = -nostretch
	if ($use_anat_ave) then
		set trailer = anat_ave
	else
		set trailer = func_vols_ave
	endif
	echo		cross_day_imgreg_4dfp $patid $day1_path $day1_patid $tarstr $stretch_flag -a$trailer
	if ($go)	cross_day_imgreg_4dfp $patid $day1_path $day1_patid $tarstr $stretch_flag -a$trailer
	if ($status) exit $status
	if ($trailer != anat_ave) then
		/bin/rm -f						${patid}_asl_M0_ave_to_${target:t}_t4
		ln -s $cwd/${patid}_func_vols_ave_to_${target:t}_t4	${patid}_asl_M0_ave_to_${target:t}_t4
	endif
	@ Et2w = 0
	if (-e $day1_path/$patid1"_t2wT".4dfp.img) then
		set t2w = $patid1"_t2wT"
		@ Et2w = 1
	else if (-e $day1_path/$patid1"_t2w".4dfp.img) then
		set t2w = $patid1"_t2w"
		@ Et2w = 1
	endif
	if (-e $day1_path/$patid1"_mpr1T".4dfp.img) then
		set mpr = $patid1"_mpr1T"
	else if ( -e $day1_path/$patid1"_mpr1".4dfp.img) then
		set mpr = $patid1"_mpr1"
	else
		echo "no structual image in day1_path"
		exit 1
	endif
	if ($day1_path != $cwd) then
		/bin/cp -t . \
			$day1_path/${day1_patid}_${trailer}_to_*_t4 \
			$day1_path/${mpr}.4dfp.* \
			$day1_path/${mpr}_to_${target:t}_t4
		if ($status) exit $status
	endif
	if ($Et2w) then
		echo "t2w="$t2w
		if ($day1_path != $cwd) then
			/bin/cp $day1_path/${t2w}.4dfp.* $day1_path/${t2w}_to_${target:t}_t4 .
			if ($status) exit $status
		endif
		t4_mul ${epi_anat}_to_${day1_patid}_${trailer}_t4 ${day1_patid}_${trailer}_to_${t2w}_t4 ${epi_anat}_to_${t2w}_t4
		if ($status) exit $status
		t4_mul ${epi_anat}_to_${t2w}_t4 ${t2w}_to_${target:t}_t4
		if ($status) exit $status
	else
		t4_mul ${epi_anat}_to_${day1_patid}_${trailer}_t4 ${day1_patid}_${trailer}_to_${mpr}_t4 ${epi_anat}_to_${mpr}_t4
		if ($status) exit $status
		if ( $day1_path != $cwd  && (! ${?gre} && ! ${?FMmag}) && $?FMmean && $?FMbases ) then
			/bin/cp -t . \
				$day1_path/${patid1}_aparc+aseg_on_${target:t}_333.4dfp.* \
				$day1_path/${patid1}_FSWB_on_${target:t}_333.4dfp.* \
				$day1_path/${patid1}_CS_erode_on_${target:t}_333_clus.4dfp.* \
				$day1_path/${patid1}_WM_erode_on_${target:t}_333_clus.4dfp.* \
				$day1_path/${patid1}_aparc+aseg.4dfp.* \
				$day1_path/${patid1}_orig_to_${mpr}_t4
			if ($status) exit $status
		endif
	endif
	goto EPI_to_ATL
endif
######################
# make MP-RAGE average
######################
@ nmpr = ${#mprs}
if ($nmpr < 1) exit 0
set mprave = $patid"_mpr_n"$nmpr
set mprlst = ()
@ k = 1
while ($k <= $nmpr)
	if (! $E4dfp) then
		if ($sorted) then
			echo		dcm_to_4dfp -b $patid"_mpr"$k $inpath/study$mprs[$k]
			if ($go)	dcm_to_4dfp -b $patid"_mpr"$k $inpath/study$mprs[$k]
		else
			echo		dcm_to_4dfp -b $patid"_mpr"$k $inpath/$dcmroot.$mprs[$k]."*"
			if ($go)	dcm_to_4dfp -b $patid"_mpr"$k $inpath/$dcmroot.$mprs[$k].*
		endif
		if ($status) exit $status
	endif
	set mprlst = ($mprlst $patid"_mpr"$k)
	@ k++
end

date
#########################
# compute atlas transform
#########################
if (! ${?tse}) 	set tse = ()
if (! ${?t1w})	set t1w = ()
if (! ${?pdt2})	set pdt2 = ()
if (! ${?Gad})	set Gad = 0;		# Gadolinium contrast given: @ Gad = 1

if ($#tse == 0 && ! ${?FMmag} && ! ${?gre}) then
	set mprlstT = ()
		foreach mpr ($mprlst)
		@ ori = `awk '/orientation/{print $NF}' ${mpr}.4dfp.ifh`
		switch ($ori)
		case 2:
					set mprlstT = ($mprlstT ${mpr});  breaksw;
		case 3:
			C2T_4dfp $mpr;	set mprlstT = ($mprlstT ${mpr}T); breaksw;
		case 4:
			S2T_4dfp $mpr;	set mprlstT = ($mprlstT ${mpr}T); breaksw;
		default:
			echo $program": illegal "$mpr" orientation"; exit -1; breaksw;
		endsw
	end
	set mprlst = ($mprlstT)
endif

set mpr = $mprlst[1]
if ($Gad) then
	mpr2atl1_4dfp $mpr $tarstr useold
	if ($status) exit $status
	set episcript = epi2t2w2mpr2atl3_4dfp;
else
	echo		avgmpr_4dfp $mprlst $mprave $tarstr useold
	if ($go)	avgmpr_4dfp $mprlst $mprave $tarstr useold
	if ($status) exit $status
	set episcript = epi2t2w2mpr2atl2_4dfp;
endif
foreach O (111 222 333)
	ifh2hdr -r1600 ${patid}_mpr_n${nmpr}_${O}_t88
end

@ ntse = ${#tse}
if (${#t1w}) then
	if (! $E4dfp) then
		if ($sorted) then
			echo		dcm_to_4dfp -b $patid"_t1w" $inpath/study$t1w
			if ($go)	dcm_to_4dfp -b $patid"_t1w" $inpath/study$t1w
		else
			echo		dcm_to_4dfp -b $patid"_t1w" $inpath/$dcmroot.$t1w."*"
			if ($go) 	dcm_to_4dfp -b $patid"_t1w" $inpath/$dcmroot.$t1w.*
		endif
	endif
	echo		t2w2mpr_4dfp $patid"_mpr1" $patid"_t1w" $tarstr
	if ($go)	t2w2mpr_4dfp $patid"_mpr1" $patid"_t1w" $tarstr
	if ($status) exit $status

	echo		epi2t1w_4dfp ${epi_anat} $patid"_t1w" $tarstr
	if ($go)	epi2t1w_4dfp ${epi_anat} $patid"_t1w" $tarstr
	if ($status) exit $status

	echo		t4_mul ${epi_anat}_to_$patid"_t1w_t4" $patid"_t1w_to_"$target:t"_t4"
	if ($go)	t4_mul ${epi_anat}_to_$patid"_t1w_t4" $patid"_t1w_to_"$target:t"_t4"
else if ($ntse) then
	set tselst = ()
	@ k = 1
	while ($k <= $ntse)
		set filenam = $patid"_t2w"
		if ($ntse > 1) set filenam = $filenam$k
		if (! $E4dfp) then
			if ($sorted) then
				echo		dcm_to_4dfp -b $filenam $inpath/study$tse[$k]
				if ($go)	dcm_to_4dfp -b $filenam $inpath/study$tse[$k]
			else
				echo		dcm_to_4dfp -b $filenam $inpath/$dcmroot.$tse[$k]."*"
				if ($go) 	dcm_to_4dfp -b $filenam $inpath/$dcmroot.$tse[$k].*
			endif
			if ($status) exit $status
		endif
		set tselst = ($tselst $filenam)
		@ k++
	end
	if ($ntse  > 1) then
		echo		collate_slice_4dfp $tselst $patid"_t2w"
		if ($go)	collate_slice_4dfp $tselst $patid"_t2w"
	endif
else if (${#pdt2}) then
	if (! $E4dfp) then
		if ($sorted) then
			echo		dcm_to_4dfp -b $patid"_pdt2" $inpath/study$pdt2
			if ($go)	dcm_to_4dfp -b $patid"_pdt2" $inpath/study$pdt2
		else
			echo		dcm_to_4dfp -b $patid"_pdt2" $inpath/$dcmroot.$pdt2."*"
			if ($go) 	dcm_to_4dfp -b $patid"_pdt2" $inpath/$dcmroot.$pdt2.*
		endif
		if ($status) exit $status
	endif
	echo		extract_frame_4dfp $patid"_pdt2" 2 -o$patid"_t2w"
	if ($go)	extract_frame_4dfp $patid"_pdt2" 2 -o$patid"_t2w"
	if ($status) exit $status
endif

@ Et2w = (-e $patid"_t2w".4dfp.img && -e $patid"_t2w".4dfp.ifh)
if ($Et2w) then
#################################################
# if unwarp is needed make sure t2w is transverse
#################################################
	set t2w = $patid"_t2w"
	@ ori = `awk '/orientation/{print $NF}' $patid"_t2w".4dfp.ifh`
	switch ($ori)
	case 2:
		breaksw;
	case 3:
		C2T_4dfp $patid"_t2w"; set t2w = $patid"_t2wT"; breaksw;
	case 4:
		S2T_4dfp $patid"_t2w"; set t2w = $patid"_t2wT"; breaksw;
	default:
		echo $program": illegal $patid"_t2w" orientation"; exit -1; breaksw;
	endsw
	echo		$episcript ${epi_anat} $t2w $patid"_mpr1" useold $tarstr
	if ($go)	$episcript ${epi_anat} $t2w $patid"_mpr1" useold $tarstr
else
	echo		epi2mpr2atl2_4dfp ${epi_anat} $mpr useold $tarstr
	if ($go)	epi2mpr2atl2_4dfp ${epi_anat} $mpr useold $tarstr
endif
if ($status) exit $status

EPI_to_ATL:
if (! $use_anat_ave && $day1_patid == "") then
	/bin/rm ${patid}_asl_M0_ave_to_${target:t}_t4
	ln -s ${patid}_func_vols_ave_to_${target:t}_t4 ${patid}_asl_M0_ave_to_${target:t}_t4
endif

########################################################################
# make atlas transformed epi_anat and t2w in 111 222 and 333 atlas space
########################################################################
set t4file = ${patid}_asl_M0_ave_to_${target:t}_t4
foreach O (222)
	echo		t4img_4dfp $t4file  ${epi_anat}	${epi_anat}_on_${target:t}_$O -O$O
	if ($go)	t4img_4dfp $t4file  ${epi_anat}	${epi_anat}_on_${target:t}_$O -O$O
	echo		ifh2hdr	 -r2000			${epi_anat}_on_${target:t}_$O
	if ($go)	ifh2hdr	 -r2000			${epi_anat}_on_${target:t}_$O
end
if ($status) exit $status

if ($day1_patid != "" || ! $Et2w) goto SKIPT2W
set t4file = ${t2w}_to_${target:t}_t4
foreach O (111)
	echo		t4img_4dfp $t4file  ${t2w}	${t2w}_on_${target:t}_$O -O$O
	if ($go)	t4img_4dfp $t4file  ${t2w}	${t2w}_on_${target:t}_$O -O$O
	echo		ifh2hdr	 -r1000			${t2w}_on_${target:t}_$O
	if ($go)	ifh2hdr	 -r1000			${t2w}_on_${target:t}_$O
end
if ($status) exit $status
SKIPT2W:
/bin/rm *t4% >& /dev/null
popd		# out of atlas

UNWARP:
##############################################################
# logic to adjudicate between measured vs. computed field maps
##############################################################
if (! ${?gre})  set gre = ()					# gradient echo measured field maps
if (! ${?sefm}) set sefm = ()					# spin echo measured field maps
if (${#sefm}) then
	if (! -e sefm/${patid}_sefm_mag_brain.nii.gz) then
		sefm_pp_AZS.csh ${prmfile} ${instructions}	# creates sefm subdirectory
	else
		echo sefm exists - skipping sefm_pp_AZS.csh
	endif
	if ($status) exist $status
	set uwrp_args  = (-map $patid atlas/${epi_anat} sefm/${patid}_sefm_mag.nii.gz sefm/${patid}_sefm_pha.nii.gz $dwell $TE_vol $ped 0)
	set log	= ${patid}_fmri_unwarp_170616_se.log
else if (${#gre}) then
	if (! ${?delta}) then
		echo $program":" parameter delta must be defined with gradient echo field mapping
		exit -1
	endif
	if (${#gre} != 2) then
		echo $program":" gradient echo field mapping requires exactly 2 scans
		exit -1
	endif
	dcm2nii -a y -d n -e n -f n -g n -i n -p n -r n -o . $inpath/study$gre[1] >! $$.txt
	if ($status) exit $status
	set F = `cat $$.txt | gawk '/^Saving/{print $NF}'`
	mv $F		${patid}_mag.nii
	if ($status) exit $status
	dcm2nii -a y -d n -e n -f n -g n -i n -p n -r n -o . $inpath/study$gre[2] >! $$.txt
	set F = `cat $$.txt | gawk '/^Saving/{print $NF}'`
	mv $F		${patid}_pha.nii
	if ($status) exit $status
	/bin/rm $$.txt
	set uwrp_args  = (-map $patid atlas/${epi_anat} ${patid}_mag.nii ${patid}_pha.nii $dwell $TE_vol $ped $delta)
	set log	= ${patid}_fmri_unwarp_170616_gre.log
else if ($?FMmean && $?FMbases) then
#########################################################
# unwarping script now expects t2w to be in current atlas
#########################################################
	if ($Et2w) then
		set uwrp_args   = (-basis atlas/${epi_anat} atlas/${t2w} $FMmean $FMbases atlas/${epi_anat}_to_${t2w}_t4 atlas/${epi_anat}_to_${target:t}_t4 $dwell $ped $nbasis)
	else
		if ($day1_patid == "") then
			if ($go) Generate_FS_Masks_AZS.csh $prmfile $instructions
			if ($status) exit $status
		endif
		pushd atlas
			t4img_4dfp ${patid1}_orig_to_${mpr}_t4 ${patid1}_aparc+aseg ${patid1}_aparc+aseg_on_$mpr -O$mpr -n
			if ($status) exit $status
			niftigz_4dfp -n ${patid1}_aparc+aseg_on_$mpr ${patid1}_aparc+aseg_on_$mpr
			if ($status) exit $status
			$FSLDIR/bin/fslmaths ${patid1}_aparc+aseg_on_$mpr.nii.gz -bin -dilF -dilF -fillh -ero ${patid1}_brain_mask.nii.gz
			if ($status) exit $status
			niftigz_4dfp -4 ${patid1}_brain_mask ${patid1}_brain_mask
			if ($status) exit $status
		popd
		set uwrp_args = (-basis atlas/${epi_anat} atlas/$mpr $FMmean $FMbases atlas/${epi_anat}_to_${mpr}_t4 atlas/${epi_anat}_to_${target:t}_t4 $dwell $ped $nbasis atlas/${patid1}_brain_mask)
	endif
	set log	= ${patid}_fmri_unwarp_170616_basis.log
else if ($?FMmean) then
	set uwrp_args = (-mean atlas/${epi_anat} $FMmean atlas/${epi_anat}_to_${target:t}_t4 $dwell $ped)
	set log	= ${patid}_fmri_unwarp_170616_mean.log
else
	echo "distortion will not be done"
	#################################
	# t4_xr3d_4dfp for atlas resample
	#################################
	if ( ! ${?to_MNI152} ) set to_MNI152 = 0
	@ k = 1
	while ($k <= $runs)
		pushd asl$irun[$k]
		if ($to_MNI152) then
			set A = $RELEASE/MNI152_T1_3mm.4dfp.ifh
			echo		t4_xr3d_4dfp $sourcedir/atlas/${patid}_asl_M0_ave_to_MNI152lin_t4	${patid}_a$irun[$k] -axr3d_MNI152_3mm -v$normode -O$A
			if ($go)	t4_xr3d_4dfp $sourcedir/atlas/${patid}_asl_M0_ave_to_MNI152lin_t4   ${patid}_a$irun[$k] -axr3d_MNI152_3mm -v$normode -O$A
		else
			echo		t4_xr3d_4dfp $sourcedir/atlas/${patid}_asl_M0_ave_to_${target:t}_t4 ${patid}_a$irun[$k] -axr3d_atl        -v$normode -O333
			if ($go)	t4_xr3d_4dfp $sourcedir/atlas/${patid}_asl_M0_ave_to_${target:t}_t4 ${patid}_a$irun[$k] -axr3d_atl        -v$normode -O333
		endif
		if ($status) exit $status
		if ($economy > 4) then
			echo		/bin/rm ${patid}_a$irun[$k]_xr3d_norm.4dfp."*"
			if ($go)	/bin/rm ${patid}_a$irun[$k]_xr3d_norm.4dfp.*
			echo		/bin/rm ${patid}_a$irun[$k]_xr3d.4dfp."*"
			if ($go)	/bin/rm ${patid}_a$irun[$k]_xr3d.4dfp.*
		endif
		popd	# out of asl$irun[$k]
		@ k++
	end

	echo $program done status=$status
	exit
	
endif
##################################
# compute field mapping correction
##################################
date						>! $log
echo	fmri_unwarp_170616.tcsh $uwrp_args	>> $log
	fmri_unwarp_170616.tcsh $uwrp_args	>> $log

###################################################
# compute unwarp/${epi_anat}_uwrp_to_${target:t}_t4
###################################################
if (${#sefm} || ${#gre} || ! $?FMbases) then
	if ($Et2w) then
		niftigz_4dfp -n atlas/$t2w atlas/$t2w
		bet atlas/$t2w atlas/${t2w}_brain -m -f 0.4 -R
		niftigz_4dfp -4 atlas/${t2w}_brain_mask atlas/${t2w}_brain_mask -N
		@ mode = 8192 + 2048 + 3
		/bin/cp atlas/${epi_anat}_to_${t2w}_t4 unwarp/${epi_anat}_uwrp_to_${t2w}_t4
		imgreg_4dfp atlas/$t2w atlas/${t2w}_brain_mask unwarp/${epi_anat}_uwrp none unwarp/${epi_anat}_uwrp_to_${t2w}_t4 $mode \
			>! unwarp/${epi_anat}_uwrp_to_${t2w}.log
		if ($status) exit $status

		t4_mul unwarp/${epi_anat}_uwrp_to_${t2w}_t4 atlas/${t2w}_to_${target:t}_t4 unwarp/${epi_anat}_uwrp_to_${target:t}_t4
		if ($status) exit $status
	else
		pushd atlas; msktgen_4dfp $mpr -T$target; popd;
		@ mode = 8192 + 2048 + 3
		/bin/cp atlas/${epi_anat}_to_${mpr}_t4 unwarp/${epi_anat}_uwrp_to_${mpr}_t4
		imgreg_4dfp atlas/${mpr} atlas/${mpr}_mskt unwarp/${epi_anat}_uwrp none unwarp/${epi_anat}_uwrp_to_${mpr}_t4 $mode \
			>! unwarp/${epi_anat}_uwrp_to_${mpr}.log
		if ($status) exit $status
		t4_mul unwarp/${epi_anat}_uwrp_to_${mpr}_t4 atlas/${mpr}_to_${target:t}_t4 unwarp/${epi_anat}_uwrp_to_${target:t}_t4
		if ($status) exit $status
	endif
else
	if ($Et2w) then
		set struct = $t2w
	else
		set struct = $mpr
	endif
	echo	t4_mul	unwarp/${epi_anat}_uwrp_to_${struct}_t4 atlas/${struct}_to_${target:t}_t4 unwarp/${epi_anat}_uwrp_to_${target:t}_t4
		t4_mul	unwarp/${epi_anat}_uwrp_to_${struct}_t4 atlas/${struct}_to_${target:t}_t4 unwarp/${epi_anat}_uwrp_to_${target:t}_t4
	set t4file = unwarp/${epi_anat}_uwrp_to_${target:t}_t4
	if ($status) exit $status
	echo	t4img_4dfp unwarp/${epi_anat}_uwrp_to_${struct}_t4 unwarp/${epi_anat}_uwrp 	unwarp/${epi_anat}_uwrp_on_${struct} -Oatlas/${struct}
		t4img_4dfp unwarp/${epi_anat}_uwrp_to_${struct}_t4 unwarp/${epi_anat}_uwrp 	unwarp/${epi_anat}_uwrp_on_${struct} -Oatlas/${struct}
	if ($status) exit $status
	ifh2hdr -r2000										unwarp/${epi_anat}_uwrp_on_${struct}
endif
foreach O (111 222 333)
	echo		t4img_4dfp unwarp/${epi_anat}_uwrp_to_${target:t}_t4 unwarp/${epi_anat}_uwrp	unwarp/${epi_anat}_uwrp_on_${target:t}_$O -O$O
	if ($go)	t4img_4dfp unwarp/${epi_anat}_uwrp_to_${target:t}_t4 unwarp/${epi_anat}_uwrp	unwarp/${epi_anat}_uwrp_on_${target:t}_$O -O$O
	echo		ifh2hdr	 -r2000									unwarp/${epi_anat}_uwrp_on_${target:t}_$O
	if ($go)	ifh2hdr	 -r2000									unwarp/${epi_anat}_uwrp_on_${target:t}_$O
end

ATL:
#################################
# one step resample unwarped fMRI
#################################
if (! $epi2atl) exit 0
set x = ${rsam_cmnd:t}; set x = $x:r
set log		= ${patid}_$x.log
date						>! $log
echo	$rsam_cmnd $prmfile $instructions	>> $log
	$rsam_cmnd $prmfile $instructions	>> $log
if ($status) exit $status
exit $status
####################################################################
# remake single resampled 333 atlas space fMRI volumetric timeseries
####################################################################
set lst = ${patid}_xr3d_uwrp_atl.lst
if (-e $lst) /bin/rm $lst
touch $lst
@ k = 1
while ($k <= $#irun)
	echo asl$irun[$k]/${patid}_a$irun[$k]${MBstr}_xr3d_uwrp_atl.4dfp.img >> $lst
	@ k++
end
conc_4dfp ${lst:r}.conc -l$lst
if ($status) exit $status
set fmtfile = atlas/${patid}_func_vols.format
if (! -e $fmtfile) exit $status
actmapf_4dfp $fmtfile ${patid}_xr3d_uwrp_atl.conc -aave
if ($status) exit $status
ifh2hdr -r2000 		${patid}_xr3d_uwrp_atl_ave
mv			${patid}_xr3d_uwrp_atl_ave.4dfp.*	atlas
var_4dfp -sF$fmtfile	${patid}_xr3d_uwrp_atl.conc
ifh2hdr -r20		${patid}_xr3d_uwrp_atl_sd1
mv			${patid}_xr3d_uwrp_atl_sd1*		atlas
mv			${patid}_xr3d_uwrp_atl.conc*		atlas

echo $program complete
exit 0
