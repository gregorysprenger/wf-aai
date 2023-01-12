process INFILE_HANDLING {

    publishDir "${params.process_log_dir}",
        mode: "${params.publish_dir_mode}",
        pattern: ".command.*",
        saveAs: { filename -> "${task.process}${filename}" }

    container "ubuntu:focal"

    input:
        path input
        path query

    output:
        path "proteomes", emit: prot
        path "proteomes/*"
        path ".command.out"
        path ".command.err"
        path "versions.yml", emit: versions
        
    shell:
        '''
        source bash_functions.sh
        
        # Get input data
        shopt -s nullglob
        compressed_prot=( "!{input}"/*.{faa,gb,gbk,gbf,gbff}.gz )
        plaintext_prot=( "!{input}"/*.{faa,gb,gbk,gbf,gbff} )
        shopt -u nullglob
        msg "INFO: ${#compressed_prot[@]} compressed proteomes found"
        msg "INFO: ${#plaintext_prot[@]} plain text proteomes found"

        # Check if total inputs are > 2
        if [[ -f !{query} ]]; then
            total_inputs=$(( ${#compressed_prot[@]} + ${#plaintext_prot[@]} + 1 ))
        else
            total_inputs=$(( ${#compressed_prot[@]} + ${#plaintext_prot[@]} ))
        fi

        if [[ ${total_inputs} -lt 2 ]]; then
            msg 'ERROR: at least 2 proteomes are required for batch analysis' >&2
        exit 1
        fi

        # Make tmp directory and move files to proteomes dir
        mkdir proteomes
        for file in "${compressed_prot[@]}" "${plaintext_prot[@]}"; do
            cp ${file} proteomes
        done

        # Decompress files
        if [[ ${#compressed_prot[@]} -ge 1 ]]; then
            gunzip ./proteomes/*.gz
        fi

        # Get all assembly files after gunzip
        shopt -s nullglob
        PROT=( ./proteomes/*.{faa,gb,gbk,gbf,gbff} )
        shopt -u nullglob
        msg "INFO: Total number of proteomes: ${#PROT[@]}"

        # Filter out and report unusually small genomes
        FAA=()
        for A in "${PROT[@]}"; do
        # TO-DO: file content corruption and format validation tests
            if [[ $(find -L "$A" -type f -size +33k 2>/dev/null) ]]; then
                FAA+=("$A")
            else
                msg "INFO: $A not >33 kB so it was not included in the analysis" >&2
            fi
        done

        if [ ${#FAA[@]} -lt 2 ]; then
            msg 'ERROR: found <2 proteome files >33 kB' >&2
        exit 1
        fi

        # Check file size of query input
        if [[ -f !{query} ]]; then
            verify_file_minimum_size "!{query}" 'query' '33k'
        fi

        cat <<-END_VERSIONS > versions.yml
        "!{task.process}":
            ubuntu: $(awk -F ' ' '{print $2,$3}' /etc/issue | tr -d '\\n')
        END_VERSIONS
        '''
}
