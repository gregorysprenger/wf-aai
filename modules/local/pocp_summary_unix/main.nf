process POCP_SUMMARY_UNIX {

    label "process_low"
    container "ubuntu:focal"

    input:
    path(stats)

    output:
    path("Summary.POCP.tsv")
    path(".command.{out,err}")
    path("versions.yml")      , emit: versions

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

    msg "INFO: Summarizing each comparison to Summary.POCP.tsv"

    # Summarize POCP values
    echo -n '' > Summary.POCP.tsv
    for f in !{stats}; do
        PAIR=$(basename ${f} .stats.tab | sed 's/aai\\.//1')
        S1=${PAIR##*,}
        S2=${PAIR%%,*}

        # Calculate POCP from bidrectional values
        PROT=$(grep ',' ${f} | cut -f 2)
        if [[ ! "${PROT}" =~ ',' ]]; then
            msg "ERROR: Absent comma for bidirectional comparison in ${PROT} within the $f file" >&2
            exit 1
        fi

        CNT_CORE=0
        CNT_TOTAL=0

        for sample_proteins in ${PROT%%,*} ${PROT##*,}; do
            if [[ ! "${sample_proteins}" =~ '/' ]]; then
                msg "ERROR: Absent backslash for fraction of filtered proteins in ${sample_proteins} within the ${f} file" >&2
                exit 1
            fi
            CNT_CORE=$(( $CNT_CORE + ${sample_proteins%%/*}))
            CNT_TOTAL=$(( $CNT_TOTAL + ${sample_proteins##*/}))
        done

        POCP=$(echo "${CNT_CORE}" "${CNT_TOTAL}" | awk '{printf("%.3f", ($1/$2)*100)}')

        if ! [[ "${POCP%.*}" -ge 0 && "${POCP%.*}" -le 100 ]]; then
            msg "ERROR: Found AAI $AAI for $B1,$B2; skipping the comparison" >&2
            exit 1
        fi

        echo -e "${S1}\t${S2}\t${POCP}" >> Summary.POCP.tsv
    done

    A='Sample\tSample\tPercentage_of_Conserved_Proteins[%]'
    sed -i "1i ${A}" Summary.POCP.tsv

    cat <<-END_VERSIONS > versions.yml
    "!{task.process}":
        ubuntu: $(awk -F ' ' '{print $2,$3}' /etc/issue | tr -d '\\n')
    END_VERSIONS
    '''
}
