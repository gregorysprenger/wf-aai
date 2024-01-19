process INFILE_HANDLING_UNIX {

    tag( "${meta.id}" )
    container "ubuntu:jammy"

    input:
    tuple val(meta), path(input)

    output:
    path("proteomes.fofn")                   , emit: proteomes
    path("proteomes/*")                      , emit: prot_files
    path("${meta.id}.Initial_Input_File.tsv"), emit: qc_filecheck
    path(".command.{out,err}")
    path("versions.yml")                     , emit: versions

    shell:
    // Rename files with meta.id (has spaces and periods removed)
    gzip_compressed = input.toString().contains('.gz') ? '.gz' : ''
    file_extension  = input.toString().split('.gz')[0].split('\\.')[-1]
    '''
    source bash_functions.sh

    # Rename input files to prefix and move to proteomes dir
    mkdir proteomes
    cp !{input} proteomes/"!{meta.id}.!{file_extension}!{gzip_compressed}"

    # gunzip all files that end in .{gz,Gz,GZ,gZ}
    find -L proteomes/ -type f -name '*.[gG][zZ]' -exec gunzip -f {} +

    # Filter out small proteomes
    msg "Checking input file sizes.."
    echo -e "Sample name\tQC step\tOutcome (Pass/Fail)" > "!{meta.id}.Initial_Input_File.tsv"
    for file in proteomes/*; do
      if verify_minimum_file_size "${file}" 'Input' "!{params.min_input_filesize}"; then
        echo -e "$(basename ${file%%.*})\tInput File\tPASS" \
        >> "!{meta.id}.Initial_Input_File.tsv"

        # Generate list of proteomes
        echo -e "$(basename ${file})" >> proteomes.fofn
      else
        echo -e "$(basename ${file%%.*})\tInput File\tFAIL" \
        >> "!{meta.id}.Initial_Input_File.tsv"

        rm ${file}
      fi
    done

    if [[ -s proteomes.fofn ]]; then
      sed -i '1i Filename' proteomes.fofn
    else
      touch proteomes.fofn
    fi

    cat <<-END_VERSIONS > versions.yml
    "!{task.process}":
      ubuntu: $(awk -F ' ' '{print $2,$3}' /etc/issue | tr -d '\\n')
    END_VERSIONS
    '''
}
