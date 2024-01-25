//
// Check inputs and generate file pairs for QUERY vs REFERENCE analysis
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULES: Local modules
//
include { INFILE_HANDLING_UNIX as REFDIR_INFILE_HANDLING_UNIX       } from "../../modules/local/infile_handling_unix/main"
include { INFILE_HANDLING_UNIX as QUERY_INFILE_HANDLING_UNIX        } from "../../modules/local/infile_handling_unix/main"
include { GENBANK2FASTA_BIOPYTHON as REFDIR_GENBANK2FASTA_BIOPYTHON } from "../../modules/local/genbank2fasta_biopython/main"
include { GENBANK2FASTA_BIOPYTHON as QUERY_GENBANK2FASTA_BIOPYTHON  } from "../../modules/local/genbank2fasta_biopython/main"
include { GENERATE_PAIRS_BIOPYTHON                                  } from "../../modules/local/generate_pairs_biopython/main"

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK as REFDIR_INPUT_CHECK                         } from "./input_check"
include { INPUT_CHECK as QUERY_INPUT_CHECK                          } from "./input_check"

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Convert params.aai to lowercase
def toLower(it) {
    it.toString().toLowerCase()
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN QUERY_VS_REFDIR WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow QUERY_VS_REFDIR {

    take:
    query
    refdir
    ch_aai_name

    main:
    // SETUP: Define empty channels to concatenate certain outputs
    ch_versions = Channel.empty()

    // Check query for samplesheet or grab file
    QUERY_INPUT_CHECK (
        query
    )
    ch_versions = ch_versions.mix(QUERY_INPUT_CHECK.out.versions)

    // Check input for samplesheet or pull inputs from directory
    REFDIR_INPUT_CHECK (
        refdir
    )
    ch_versions = ch_versions.mix(REFDIR_INPUT_CHECK.out.versions)

    // Check query file meets size criteria
    QUERY_INFILE_HANDLING_UNIX (
        QUERY_INPUT_CHECK.out.input_files
    )
    ch_versions = ch_versions.mix(QUERY_INFILE_HANDLING_UNIX.out.versions)

    // Check refdir input files meet size criteria
    REFDIR_INFILE_HANDLING_UNIX (
        REFDIR_INPUT_CHECK.out.input_files
    )
    ch_versions = ch_versions.mix(REFDIR_INFILE_HANDLING_UNIX.out.versions)

    // Collect all Initial Input File checks and concatenate into one file
    ch_qc_filecheck = Channel.empty()
    ch_qc_filecheck = ch_qc_filecheck
                        .mix(QUERY_INFILE_HANDLING_UNIX.out.qc_filecheck)
                        .mix(REFDIR_INFILE_HANDLING_UNIX.out.qc_filecheck)
                        .collect()

    // Collect proteomes.fofn and rename to query and refdir
    ch_query_fofn = QUERY_INFILE_HANDLING_UNIX.out.proteomes
                        .collectFile(
                            name:     "queries.tsv",
                            storeDir: "${params.outdir}/AAI/${ch_aai_name}"
                        )

    ch_refdir_fofn = REFDIR_INFILE_HANDLING_UNIX.out.proteomes
                        .collectFile(
                            name:     "references.tsv",
                            storeDir: "${params.outdir}/AAI/${ch_aai_name}"
                        )


    // Add meta information to reference channel
    ch_reference_prot = REFDIR_INFILE_HANDLING_UNIX.out.prot_files
                        .collect()
                        .map {
                            file ->
                                def meta = [:]
                                meta['aai'] = "${ch_aai_name}"
                                [ meta, file ]
                        }

    // Collect assembly files
    ch_prot_files = Channel.empty()
    ch_prot_files = ch_prot_files
                    .mix(QUERY_INFILE_HANDLING_UNIX.out.prot_files)
                    .mix(REFDIR_INFILE_HANDLING_UNIX.out.prot_files)
                    .collect()

    // PROCESS: Create pairings and append to pairs.fofn
    GENERATE_PAIRS_BIOPYTHON (
        ch_reference_prot,
        QUERY_INFILE_HANDLING_UNIX.out.prot_files.collect()
    )
    ch_versions = ch_versions.mix(GENERATE_PAIRS_BIOPYTHON.out.versions)

    // Collect pairs.fofn and assemblies directory
    ch_aai_pairs = GENERATE_PAIRS_BIOPYTHON.out.aai_pairs
                    .splitCsv(header: true, sep: '\t')
                    .map{ row -> tuple("${row.Filepair1}", "${row.Filepair2}") }

    emit:
    versions     = ch_versions
    aai_pairs    = ch_aai_pairs
    prot_files   = ch_prot_files
    qc_filecheck = ch_qc_filecheck
}
