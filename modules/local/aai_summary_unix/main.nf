process AAI_SUMMARY_UNIX {

    label "process_low"
    container "ubuntu:focal"

    input:
    tuple val(meta), path(stats)

    output:
    path("Summary.${meta.aai}.tsv")          , emit: summary
    path("Summary.Proteins_Per_Proteome.tsv")
    path(".command.{out,err}")
    path("versions.yml")                     , emit: versions

    shell:
    '''
    source bash_functions.sh

    # Verify each file has data
    for f in !{stats}; do
        lines=$(grep -o '%'$'\t''[0-9]' ${f} | wc -l)
        if [ ${lines} -ne 6 ]; then
            msg "ERROR: ${f} lacks data to extract" >&2
            exit 1
        fi
    done

    msg "INFO: Summarizing each comparison to Summary.!{meta.aai}.tsv"

    # Summarize AAI values
    echo -n '' > "Summary.!{meta.aai}.tsv"
    for f in !{stats}; do
        PAIR=$(basename ${f} .stats.tab | sed 's/aai\\.//1')
        S1=${PAIR##*,}
        S2=${PAIR%%,*}

        # bidirectional values
        FRAG=$(grep ',' ${f} | cut -f 2 | cut -d '/' -f 1 | awk '{print $1/2}')
        MEAN=$(grep ',' ${f} | cut -f 3 | sed 's/%//1')
        STDEV=$(grep ',' ${f} | cut -f 4 | sed 's/%//1')

        # unidirectional values
        F1=$(grep -v -e ',' -e 'StDev' ${f} | sed -n 1p | cut -f 2 | cut -d '/' -f 1)
        M1=$(grep -v -e ',' -e 'StDev' ${f} | sed -n 1p | cut -f 3 | sed 's/%//1')
        D1=$(grep -v -e ',' -e 'StDev' ${f} | sed -n 1p | cut -f 4 | sed 's/%//1')

        F2=$(grep -v -e ',' -e 'StDev' ${f} | sed -n 2p | cut -f 2 | cut -d '/' -f 1)
        M2=$(grep -v -e ',' -e 'StDev' ${f} | sed -n 2p | cut -f 3 | sed 's/%//1')
        D2=$(grep -v -e ',' -e 'StDev' ${f} | sed -n 2p | cut -f 4 | sed 's/%//1')

        echo -e "$S1\t$S2\t$FRAG\t$MEAN\t$STDEV\t$F1\t$M1\t$D1\t$F2\t$M2\t$D2" >> "Summary.!{meta.aai}.tsv"

        # number of proteins in each input sample
        TotalInputProteins_S1=$(grep -v -e ',' -e 'StDev' ${f} | sed -n 1p | cut -f 2 | cut -d \\/ -f 2)
        TotalInputProteins_S2=$(grep -v -e ',' -e 'StDev' ${f} | sed -n 2p | cut -f 2 | cut -d \\/ -f 2)
        echo -e "${S1}\t${TotalInputProteins_S1}" >> Num_Proteins_Per_Proteome.tmp
        echo -e "${S2}\t${TotalInputProteins_S2}" >> Num_Proteins_Per_Proteome.tmp
    done

    A='Sample\tSample\tFragments_Used_for_Bidirectional_Calc[#]\tBidirectional_AAI[%]\tBidirectional_StDev[%]'
    B='\tFragments_Used_for_Unidirectional_Calc[#]\tUnidirectional_AAI[%]\tUnidirectional_StDev[%]'
    sed -i "1i ${A}${B}${B}" "Summary.!{meta.aai}.tsv"

    msg "INFO: Summarizing number of proteins per proteome"
    awk '!seen[$0]++' Num_Proteins_Per_Proteome.tmp \
      | sed '1i Proteome\tProteins_Predicted_from_Genome[#]' \
      > Summary.Proteins_Per_Proteome.tsv

    cat <<-END_VERSIONS > versions.yml
    "!{task.process}":
        ubuntu: $(awk -F ' ' '{print $2,$3}' /etc/issue | tr -d '\\n')
    END_VERSIONS
    '''
}
