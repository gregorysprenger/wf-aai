//
// Check inputs and generate file pairs for ALL vs ALL analysis
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULES: Local modules
//
include { INFILE_HANDLING_UNIX     } from "../../modules/local/infile_handling_unix/main"
include { GENBANK2FASTA_BIOPYTHON  } from "../../modules/local/genbank2fasta_biopython/main"
include { GENERATE_PAIRS_BIOPYTHON } from "../../modules/local/generate_pairs_biopython/main"

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK              } from "./input_check"

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
    RUN ALL_VS_ALL WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow ALL_VS_ALL {

    take:
    input
    ch_aai_name

    main:
    ch_versions = Channel.empty()

    // Check input for samplesheet or pull inputs from directory
    INPUT_CHECK (
        input
    )
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)

    // Check input files meet size criteria
    INFILE_HANDLING_UNIX (
        INPUT_CHECK.out.input_files
    )
    ch_versions = ch_versions.mix(INFILE_HANDLING_UNIX.out.versions)

    // Collect proteomes.fofn files and concatenate into one
    ch_proteomes_fofn = INFILE_HANDLING_UNIX.out.proteomes
                        .collectFile(
                            name: "proteomes.fofn",
                            skip: 1
                        )
                        .map {
                            file ->
                                def meta = [:]
                                meta['aai'] = "${ch_aai_name}"
                                [ meta, file ]
                        }

    ch_proteomes_list = INFILE_HANDLING_UNIX.out.proteomes
                        .collectFile(
                            name:       "proteomes.tsv",
                            keepHeader: true,
                            storeDir:   "${params.outdir}/AAI/${ch_aai_name}"
                        )

    // PROCESS: Create pairings and append to pairs.fofn
    GENERATE_PAIRS_BIOPYTHON (
        ch_proteomes_fofn,
        []
    )
    ch_versions = ch_versions.mix(GENERATE_PAIRS_BIOPYTHON.out.versions)

    // Collect pairs.fofn and assemblies directory
    ch_aai_pairs = GENERATE_PAIRS_BIOPYTHON.out.aai_pairs
                    .splitCsv(header: true, sep: '\t')
                    .map{ row -> tuple("${row.Filepair1}", "${row.Filepair2}") }

    emit:
    versions     = ch_versions
    aai_pairs    = ch_aai_pairs
    prot_files   = INFILE_HANDLING_UNIX.out.prot_files.collect()
    qc_filecheck = INFILE_HANDLING_UNIX.out.qc_filecheck.collect()
}
