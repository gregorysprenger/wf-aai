process PERFORM_AAI_BIOPYTHON {

    label "process_high"
    tag( "${meta.aai}-${base1},${base2}" )
    container "${ meta.aai == 'BLAST' ?
                    'gregorysprenger/blast-plus-biopython@sha256:dc6a4cd2d3675b6782dbe88a0852663a7f9406670b4178867b8b230eb3be0d0d' :
                    'gregorysprenger/diamond-biopython@sha256:89803baa3e199aaada6d55a7d8a93245ecb9494cda9f18b34ea6bab179d7db4c' }"

    input:
    tuple val(filename1), val(filename2)
    tuple val(meta), path(proteomes, stageAs: 'proteomes/*')

    output:
    tuple val(meta), path("aai.${base1},${base2}.stats.tab"), emit: aai_stats
    path("*.tab")
    path(".command.{out,err}")
    path("versions.yml")                                    , emit: versions

    shell:
    // Get basename of input
    base1 = filename1.split('\\.')[0].split('_genomic')[0].split('_protein')[0]
    base2 = filename2.split('\\.')[0].split('_genomic')[0].split('_protein')[0]

    // Set params for POCP
    identity = params.pocp ? "40" : params.min_percent_identity
    fraction = params.pocp ? "50" : params.min_percent_alignment_length

    // Setup blast and diamond information
    aligner             = meta.aai == "BLAST" ? "blastp" : "diamond"
    version_information = meta.aai == "BLAST" ? "blastp -version | head -n 1 | awk '{print \$2}'" : "diamond --version | head -n 1 | awk '{print \$3}'"
    '''
    source bash_functions.sh

    # Skip comparison if precomputed value exists
    AAI=""
    if [ -s "!{params.outdir}/AAI/!{meta.aai}/!{base1}-!{base2}/aai.!{base1},!{base2}.stats.tab" ]; then
        echo "INFO: found precomputed !{params.outdir}/AAI/!{meta.aai}/!{base1}-!{base2}/aai.!{base1},!{base2}.stats.tab" >&2
        AAI=$(grep ',' "!{params.outdir}/AAI/!{meta.aai}/!{base1}-!{base2}/aai.!{base1},!{base2}.stats.tab" | cut -f 3 | sed 's/%//1')
    elif [ -s "  !{params.outdir}/AAI/!{meta.aai}/!{base2}-!{base1}/aai.!{base2},!{base1}.stats.tab" ]; then
        echo "INFO: found precomputed   !{params.outdir}/AAI/!{meta.aai}/!{base2}-!{base1}/aai.!{base2},!{base1}.stats.tab" >&2
        AAI=$(grep ',' "  !{params.outdir}/AAI/!{meta.aai}/!{base2}-!{base1}/aai.!{base2},!{base1}.stats.tab" | cut -f 3 | sed 's/%//1')
    fi
    if [[ ! -z $AAI ]]; then
        if [[ "${AAI%.*}" -ge 0 && "${AAI%.*}" -le 100 ]]; then
            msg "INFO: found AAI ${AAI} for !{base1},!{base2}; skipping the comparison" >&2
            exit 0
        fi
    fi

    msg "INFO: Performing AAI on !{base1} and !{base2}."

    AAIb+.py \
      -1 "proteomes/!{filename1}" \
      -2 "proteomes/!{filename2}" \
      -o . \
      --aligner !{aligner} \
      -c !{task.cpus} \
      --name1 "!{base1}" \
      --name2 "!{base2}" \
      --identity !{identity} \
      --fraction !{fraction} \
      --length !{params.min_length} \
      --bitscore !{params.min_bit_score} \
      --max-ACGT !{params.max_ACGT_fraction} \
      --decimal-places !{params.decimal_places} \
      --min-aln-len !{params.min_two_way_alignment_length} \
      --min-aln-frac !{params.min_two_way_alignment_fraction}

    cat <<-END_VERSIONS > versions.yml
    "!{task.process}":
        python: $(python --version 2>&1 | awk '{print $2}')
        !{aligner}: $(!{version_information})
        biopython: $(python -c 'import Bio; print(Bio.__version__)' 2>&1)
    END_VERSIONS
    '''
}
