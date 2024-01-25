process GENERATE_PAIRS_BIOPYTHON {

    tag( "${meta.aai}" )
    container "gregorysprenger/biopython@sha256:77a50d5d901709923936af92a0b141d22867e3556ef4a99c7009a5e7e0101cc1"

    input:
    tuple val(meta), path(prot)
    path(query)

    output:
    path("pairs.tsv")         , emit: aai_pairs
    path(".command.{out,err}")
    path("versions.yml")      , emit: versions

    shell:
    '''
    source bash_functions.sh

    # Generate Query vs Refdir pairs
    if [[ ! -z "!{query}" ]]; then

      total_input=( !{prot} !{query} )
      msg "INFO: Total number of proteomes: ${#total_input[@]}."

      # Create pairs.tsv
      for query in !{query}; do
        for proteome in !{prot}; do
          echo -e "${query}\t${proteome}" >> pairs.tsv
        done
      done

      # Check if there are file pairs to submit
      if [[ $(awk 'END {print NR}' pairs.tsv) -eq 0 ]]; then
        msg "ERROR: No file pairs to submit for analysis"
        exit 1
      fi

    else
      # Generate All vs All pairs

      # Check if total inputs are > 2
      num_proteomes=$(awk 'END {print NR}' !{prot})
      if [[ ${num_proteomes} -lt 2 ]]; then
        msg "ERROR: At least 2 proteomes are required for batch analysis"
        exit 1
      else
        msg "INFO: Total number of proteomes: ${num_proteomes}."
      fi

      # Set params to bash variables to export
      tasks_per_job="!{params.tasks_per_job}"
      proteomes="!{prot}"

      # Create environment variables
      export proteomes tasks_per_job

      # Use python3 to find all possible combinations of files
      # Script placed into bash_functions.sh due to line indention errors
      find_combinations

      if [ ${#COMBO_FILES[@]} -eq 0 ]; then
        msg "ERROR: No file pairs to submit for analysis"
        exit 1
      fi
    fi

    msg "INFO: Pairs file, 'pairs.tsv', created with $(awk 'END {print NR}' pairs.tsv) pairs"

    sed -i '1i Filepair1\tFilepair2' pairs.tsv

    cat <<-END_VERSIONS > versions.yml
    "!{task.process}":
      python: $(python --version 2>&1 | awk '{print $2}')
      biopython: $(python -c 'import Bio; print(Bio.__version__)' 2>&1)
    END_VERSIONS
    '''
}
