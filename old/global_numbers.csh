#!/bin/csh

if ( ${#argv} < 3 || ${#argv} == 4 && $4 != '--avg-only' ) then
	echo "Usage: global_numbers.csh <patid> <mask> <output trailer> [--avg-only]"
endif

set script_dir = /net/zfs-black/BLACK/black/git/asl-scripts
set header = 'mode,smoothmode,mean,mean70,x5,x95'

set patid = $1
set mask = $2
set trailer = $3

@ avg_only = 0
if ( ${#argv} == 4 ) then
	@ avg_only = 1
endif

source ${patid}.params

if ( ! $avg_only ) then 
	echo $header > pair_global_numbers_${trailer}.csv
endif


echo $header > avg_global_numbers_${trailer}.csv

@ i = 1
while ($i <= ${#irun} )
    pushd asl${irun[$i]}

	if ( ! $avg_only ) then
		# generate cbf pairs global numbers table
		${script_dir}/get_mask_stats.csh \
		    ${patid}_a${irun[$i]}_xr3d_atl_brainmasked_cbf \
		    $mask \
		    | tee -a ../pair_global_numbers_${trailer}.csv
	endif

    #generate run avg global numbers table
    ${script_dir}/get_mask_stats.csh \
        ${patid}_a${irun[$i]}_xr3d_atl_brainmasked_cbf_avg \
        $mask \
        | tee -a ../avg_global_numbers_${trailer}.csv

    popd
    @ i++
end

if ( ! $avg_only ) then
	# combine pairwise global numbers with timing info from cbf_pair_times
	tr -d '\r' < cbf_pair_times.csv | paste /dev/stdin pair_global_numbers_${trailer}.csv -d , > temp.csv # remove ^M line endings from cbf_pair times before pasting together
	mv temp.csv pair_global_numbers_${trailer}.csv
endif

# extract patid, aslrun from scan start times
cut -d , -f1,2 scan_start_times.csv | paste /dev/stdin avg_global_numbers_${trailer}.csv -d , > temp.csv
mv temp.csv avg_global_numbers_${trailer}.csv
