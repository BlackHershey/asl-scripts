#!/bin/csh

alias MATH 'set \!:1 = `echo "\!:3-$" | bc -l`'

if ( ${#argv} != 2 && ${#argv} != 4 ) then
	echo "Usage: get_mask_stats.csh <img> <mask> [<low_limit> <high_limit>]"
	echo " e.g.: get_mask_stats.csh  img   mask"
	echo " e.g.: get_mask_stats.csh  img   mask            0         1000"
	echo " N.B.: low_limit and high_limit must be integers"
	exit 1
endif

set img = $1
set mask = $2

set exttest = $img:e
if ( $exttest == "img" ) then
	set img = $img:r
endif
set exttest = $img:e
if ( $exttest == "4dfp" ) then
	set img = $img:r
endif

set exttest = $mask:e
if ( $exttest == "img" ) then
	set mask = $mask:r
endif
set exttest = $mask:e
if ( $exttest == "4dfp" ) then
	set mask = $mask:r
endif

# default low and high values (for ASL CBF)
@ loval = -61
@ hival = 121

if ( $#argv > 2 ) then
	set loval = $3
	set hival = $4
endif

@ bins = $hival - $loval + 1
@ xlines = $bins - 2
@ binlimit = $bins - 3

MATH lowlimit = $loval - "0.5"
MATH hilimit = $hival + "0.5"

set num_frames = `cat ${img}.4dfp.ifh | grep 'matrix size' | tail -1 | awk '{print $5}'`

@ frame = 1
while ( $frame <= $num_frames )

	img_hist_4dfp -b$bins "-r"$lowlimit"to"$hilimit $img -m$mask -x -f$frame| tail -$bins | head -$xlines >! temp_hist.txt

	set oldmax = 0
	set max = 0
	set mode = 0

	@ i = 2
	while ( $i <= $binlimit )
		set bincount = `cat temp_hist.txt | head -$i | tail -1 | awk '{print $2}'`

		if ( $bincount > $oldmax ) then
			set max = $bincount
			set oldmax = $max
			set mode = `cat temp_hist.txt | head -$i | tail -1 | awk '{print $1}'`
		endif

		@ i++
	end

	# echo "real mode = "$mode

	# use real mode as starting point, fit parabola to range of bins defined by lowest and highest bin that are > 70% of mode bin

	set binlow = 0
	set binhi = 0

	MATH countthresh = $max * 0.7
	set countthresh = `echo $countthresh | awk '{printf("%d\n",$0+=$0<0?-0.5:0.5)}'`

	# echo "thresh = "$countthresh

	@ i = 2
	while ( $i <= $binlimit )
		set bincount = `cat temp_hist.txt | head -$i | tail -1 | awk '{print $2}'`
		set binval = `cat temp_hist.txt | head -$i | tail -1 | awk '{print $1}'`
		if ( $bincount > $countthresh ) then
			set j = $i
			@ i = 1000
			set binlow = $binval
		endif
		@ i++
	end

	@ i = $binlimit
	while ( $i >= 2 )
		set bincount = `cat temp_hist.txt | head -$i | tail -1 | awk '{print $2}'`
		set binval = `cat temp_hist.txt | head -$i | tail -1 | awk '{print $1}'`
		if ( $bincount > $countthresh ) then
			@ k = $i
			@ i = -1000
			set binhi = $binval
		endif
		@ i--
	end

	# echo "binlow = "$binlow
	# echo "binhi = "$binhi

	set sumy = "0"
	set sumx = "0"
	set sumx2 = "0"
	set sumx3 = "0"
	set sumx4 = "0"
	set sumyx = "0"
	set sumyx2 = "0"
	@ N = 0

	# fit parabola
	@ i = $j
	while ( $i <= $k )
		set y = `cat temp_hist.txt | head -$i | tail -1 | awk '{print $2}'`
		set x = `cat temp_hist.txt | head -$i | tail -1 | awk '{print $1}'`

		MATH sumy = $sumy + $y
		MATH sumx = $sumx + $x
		MATH sumx2 = $sumx2 + ( $x * $x )
		MATH sumx3 = $sumx3 + ( $x * $x * $x )
		MATH sumx4 = $sumx4 + ( $x * $x * $x * $x )
		MATH sumyx = $sumyx + ( $y * $x )
		MATH sumyx2 = $sumyx2 + ( $y * $x * $x )
		@ N++
		@ i++
	end

	MATH xbar = $sumx / $N
	MATH x2bar = $sumx2 / $N
	MATH ybar = $sumy / $N

	MATH part1 = ( ( $xbar * $sumx2 ) - $sumx3 )
	MATH part2 = ( $sumx2 - ( $xbar * $sumx ) )

	MATH anumer = ( $sumx2 * $ybar ) - $sumyx2 - ( ( ( $sumyx - ( $ybar * $sumx ) ) * $part1 ) / $part2 )
	MATH adenom = ( $x2bar * $sumx2 ) - $sumx4 + ( ( $part1 * $part1 ) / $part2 )
	MATH a = $anumer / $adenom

	MATH b = ( ( $a * $part1 ) + $sumyx - ( $ybar * $sumx ) ) / $part2

	MATH c = $ybar - ( $a * $x2bar ) - ( $b * $xbar )

	# echo "y = "$a"*x2 + "$b"*x + "$c

	MATH smoothmode = - ( $b / ( 2 * $a ) )
	# echo "real mode = "$mode
	# echo "smooth mode = "$smoothmode

	/bin/rm temp_hist.txt

	set frames_before = `expr $frame - 1`
	set frames_after = `expr $num_frames - $frame`
	set formatstr = $frames_before"x+"$frames_after"x"
	set mean = `qnt_4dfp $img $mask -f$formatstr | tail -2 | head -1 | awk '{print $2}'`
	set mean70 = `qnt_4dfp -v$binlow"to"$binhi $img $mask -f$formatstr | tail -2 | head -1 | awk '{print $2}'`
	# echo "mean = "$mean
	# echo "70% mean = "$mean70

	# round to two decimal places
	set mode = `echo $mode | awk '{printf("%.3f\n",$1)}'`
	set smoothmode = `echo $smoothmode | awk '{printf("%.3f\n",$1)}'`
	set mean = `echo $mean | awk '{printf("%.3f\n",$1)}'`
	set mean70 = `echo $mean70 | awk '{printf("%.3f\n",$1)}'`

	# get xtile vals (5 and 95)
	set xtile = $img"_vol"$frame.xtile
	set xtile_length = `cat $xtile | wc -l`

	set x5 = "NA"
	set x95 = "NA"

	@ i = 4
	while ( $i <= $xtile_length )
		set xval = `cat $xtile | head -$i | tail -1 | awk '{print $1}'`
		if ( $xval == "5" ) set x5 = `cat $xtile | head -$i | tail -1 | awk '{print $2}'`
		if ( $xval == "95" ) set x95 = `cat $xtile | head -$i | tail -1 | awk '{print $2}'`
		@ i++
	end

	/bin/rm $xtile

	echo $mode","$smoothmode","$mean","$mean70","$x5","$x95
	@ frame++

end
exit
