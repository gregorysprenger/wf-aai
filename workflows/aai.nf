/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowAAI.initialise(params, log)

// Check input path parameters to see if they exist
def checkPathParamList = [ params.input, params.query, params.refdir ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (params.input && !params.query && !params.refdir) {
    ch_input  = file(params.input)
} else if (params.query && params.refdir && !params.input) {
    ch_query  = file(params.query)
    ch_refdir = file(params.refdir)
} else if (params.input && params.query && params.refdir) {
    error("Invalid input combinations! Cannot specify query or refdir with input!")
} else {
    error("Input not specified")
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// CONFIGS: Import configs for this workflow
//




/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULES: Local modules
//
include { AAI_BLAST_BIOPYTHON   } from "../modules/local/aai_blast_biopython/main"
include { AAI_DIAMOND_BIOPYTHON } from "../modules/local/aai_diamond_biopython/main"
include { SUMMARY_UNIX          } from "../modules/local/summary_unix/main"

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { ALL_VS_ALL            } from "../subworkflows/local/all_vs_all_file_pairings"
include { QUERY_VS_REFDIR       } from "../subworkflows/local/query_vs_refdir_file_pairings"

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CREATE CHANNELS FOR INPUT PARAMETERS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// AAI input
if ( toLower(params.aai) == "diamond" ) {
    ch_aai_name = "DIAMOND"
} else {
    ch_aai_name = "BLAST"
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    WORKFLOW FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Convert params.aai to lowercase
def toLower(it) {
    it.toString().toLowerCase()
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow AAI {

    // SETUP: Define empty channels to concatenate certain outputs
    ch_versions     = Channel.empty()
    ch_qc_filecheck = Channel.empty()

    /*
    ================================================================================
                            Preprocessing input data
    ================================================================================
    */
    if (params.query && params.refdir && !params.input) {
        //
        // Process query file and refdir directory
        //
        QUERY_VS_REFDIR (
            ch_query,
            ch_refdir,
            ch_aai_name
        )
        ch_versions     = ch_versions.mix(QUERY_VS_REFDIR.out.versions)
        ch_qc_filecheck = ch_qc_filecheck.mix(QUERY_VS_REFDIR.out.qc_filecheck)

        // Collect AAI data
        ch_prot_files = QUERY_VS_REFDIR.out.prot_files
        ch_aai_pairs = QUERY_VS_REFDIR.out.aai_pairs

    } else if (params.input && !params.query && !params.refdir) {
        //
        // Process input directory
        //
        ALL_VS_ALL (
            ch_input,
            ch_aai_name
        )
        ch_versions     = ch_versions.mix(ALL_VS_ALL.out.versions)
        ch_qc_filecheck = ch_qc_filecheck.mix(ALL_VS_ALL.out.qc_filecheck)

        // Collect AAI data
        ch_prot_files = ALL_VS_ALL.out.prot_files
        ch_aai_pairs = ALL_VS_ALL.out.aai_pairs

    } else {
        // Throw error if query, refdir, and input are combined
        error("Invalid input combinations! Cannot specify query or refdir with input!")
    }


    /*
    ================================================================================
                            Performing AAI on input data
    ================================================================================
    */
    if ( toLower(params.aai) == "diamond" ) {
        // PROCESS: Use DIAMOND to perform AAI on each pair
        AAI_DIAMOND_BIOPYTHON (
            ch_aai_pairs,
            ch_prot_files
        )
        ch_versions = ch_versions.mix(AAI_DIAMOND_BIOPYTHON.out.versions)

        // PROCESS: Summarize AAI stats into one file
        SUMMARY_UNIX (
            AAI_DIAMOND_BIOPYTHON.out.aai_stats.collect()
        )
        ch_versions = ch_versions.mix(SUMMARY_UNIX.out.versions)

    } else {
        // PROCESS: Use BLASTp to perform AAI on each pair
        AAI_BLAST_BIOPYTHON (
            ch_aai_pairs,
            ch_prot_files
        )
        ch_versions = ch_versions.mix(AAI_BLAST_BIOPYTHON.out.versions)

        // PROCESS: Summarize AAI stats into one file
        SUMMARY_UNIX (
            AAI_BLAST_BIOPYTHON.out.aai_stats.collect()
        )
        ch_versions = ch_versions.mix(SUMMARY_UNIX.out.versions)
    }


    /*
    ================================================================================
                        Collect version and QC information
    ================================================================================
    */

    // PATTERN: Collate method for version information
    ch_versions
        .unique()
        .collectFile(
            name:     "software_versions.yml",
            storeDir: params.tracedir
        )

    // Collect QC file checks and concatenate into one file
    ch_qc_filecheck = ch_qc_filecheck
                        .flatten()
                        .collectFile(
                            name:       "Summary.QC_File_Checks.tsv",
                            keepHeader: true,
                            storeDir:   "${params.outdir}/Summaries",
                            sort:       'index'
                        )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log)
    }
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
