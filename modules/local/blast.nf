process BLAST {

    publishDir "${params.outpath}",
        mode: "${params.publish_dir_mode}",
        pattern: "AAI--*"
    publishDir "${params.process_log_dir}",
        mode: "${params.publish_dir_mode}",
        pattern: ".command.*",
        saveAs: { filename -> "${base1}_${base2}.${task.process}${filename}" }

    label "process_high"
    tag( "${base1}_${base2}" )

    container "gregorysprenger/blast-plus-biopython@sha256:dc6a4cd2d3675b6782dbe88a0852663a7f9406670b4178867b8b230eb3be0d0d"

    input:
        tuple val(pair1), val(pair2), path(prot)

    output:
        path "AAI--*"
        path "AAI--*/aai*stats.tab", emit: stats
        path ".command.out"
        path ".command.err"
        path "versions.yml", emit: versions
        
    shell:
        // Get basename of pair1 and pair2 to add to .command.out/err log files
        base1=pair1.split('\\.')[0].split('_genomic')[0].split('_protein')[0]; 
        base2=pair2.split('\\.')[0].split('_genomic')[0].split('_protein')[0];
        '''
        source bash_functions.sh

        # Get AAIb+.py and check if it exists
        run_AAI="${DIR}/AAIb+.py"
        check_if_file_exists_allow_seconds ${run_AAI} '60'

        # Make variable path of pair1 and pair2
        filepair1="!{prot}/!{pair1}"
        filepair2="!{prot}/!{pair2}"
        
        # Verify input files exist and not empty
        verify_file_minimum_size "${filepair1}" 'input sequence file' '1k'
        verify_file_minimum_size "${filepair2}" 'input sequence file' '1k'

        # When sample (base)name variable not given, grab from filename
        B1=$(echo !{pair1} | sed 's/\\.[^.]*$//1' | sed 's/_genomic//1' | sed 's/_protein//1')
        B2=$(echo !{pair2} | sed 's/\\.[^.]*$//1' | sed 's/_genomic//1' | sed 's/_protein//1')
        
        # Skip comparison if precomputed value exists
        AAI=""
        if [ -s "!{params.outpath}/AAI--${B1},${B2}/aai.${B1},${B2}.stats.tab" ]; then
            echo "INFO: found precomputed !{params.outpath}/AAI--${B1},${B2}/aai.${B1},${B2}.stats.tab" >&2
            AAI=$(grep ',' "!{params.outpath}/AAI--${B1},${B2}/aai.${B1},${B2}.stats.tab" | cut -f 3 | sed 's/%//1')
        elif [ -s "!{params.outpath}/AAI--${B2},${B1}/aai.${B2},${B1}.stats.tab" ]; then
            echo "INFO: found precomputed !{params.outpath}/AAI--${B2},${B1}/aai.${B2},${B1}.stats.tab" >&2
            AAI=$(grep ',' "!{params.outpath}/AAI--${B2},${B1}/aai.${B2},${B1}.stats.tab" | cut -f 3 | sed 's/%//1')
        fi
        if [[ ! -z $AAI ]]; then
            if [[ "${AAI%.*}" -ge 0 && "${AAI%.*}" -le 100 ]]; then
                msg "INFO: found AAI ${AAI} for $B1,$B2; skipping the comparison" >&2
                exit 0
            fi
        fi

        msg "INFO: Performing AAI on ${B1} and ${B2}."
        msg "INFO: Using BLASTp aligner."

        python ${run_AAI} -1 ${filepair1} -2 ${filepair2} --name1 ${B1} --name2 ${B2} -c !{task.cpus} \
        -o "AAI--${B1},${B2}"

        cat <<-END_VERSIONS > versions.yml
        "!{task.process}":
            python: $(python --version 2>&1 | awk '{print $2}')
            biopython: $(python -c 'import Bio; print(Bio.__version__)' 2>&1)
            blast: $(blastp -version | head -n 1 | awk '{print $2}')
        END_VERSIONS
        '''
}
