#!/bin/csh

set script_dir = /data/nil-bluearc/black/git/asl-scripts

#set patids = ( *MPD[0-9]* )
set patids = ( MPD103_s1 )
foreach patid ( ${patids} )
    pushd ${patid}
    source ${patid}.params

    echo 'mode,smoothmode,mean,mean70,x5,x95' > pair_global_numbers.csv

    @ i = 1
    while ($i <= ${#irun} )
        pushd asl${irun[$i]}

        # generate cbf pairs global numbers table
        ${script_dir}/get_mask_stats.csh \
            ${patid}_a${irun[$i]}_xr3d_atl_brainmasked_cbf \
            ../atlas/${patid}_asl_xr3d_atl_dfndm \
            | tee -a ../pair_global_numbers.csv

        popd
        @ i++
    end

    # combine pairwise global numbers with timing info from cbf_pair_times
    tr -d '\r' < cbf_pair_times.csv | paste /dev/stdin pair_global_numbers.csv -d , > temp.csv # remove ^M line endings from cbf_pair times before pasting together
    mv temp.csv pair_global_numbers.csv

    popd
end
