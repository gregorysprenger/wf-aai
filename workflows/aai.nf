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
include { PERFORM_AAI_BIOPYTHON           } from "../modules/local/perform_aai_biopython/main"
include { AAI_SUMMARY_UNIX                } from "../modules/local/aai_summary_unix/main"
include { POCP_SUMMARY_UNIX               } from "../modules/local/pocp_summary_unix/main"

include { CONVERT_TSV_TO_EXCEL_PYTHON     } from "../modules/local/convert_tsv_to_excel_python/main"
include { CREATE_EXCEL_RUN_SUMMARY_PYTHON } from "../modules/local/create_excel_run_summary_python/main"

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { ALL_VS_ALL                      } from "../subworkflows/local/all_vs_all_file_pairings"
include { QUERY_VS_REFDIR                 } from "../subworkflows/local/query_vs_refdir_file_pairings"

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
    ch_versions             = Channel.empty()
    ch_aai_stats            = Channel.empty()
    ch_qc_filecheck         = Channel.empty()
    ch_output_summary_files = Channel.empty()

    /*
    ================================================================================
                            Preprocessing input data
    ================================================================================
    */
    if ( params.query && params.refdir && !params.input ) {
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
        ch_aai_pairs  = QUERY_VS_REFDIR.out.aai_pairs

    } else if ( params.input && !params.query && !params.refdir ) {
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
        ch_aai_pairs  = ALL_VS_ALL.out.aai_pairs

    } else {
        // Throw error if query, refdir, and input are combined
        error("Invalid input combinations! Cannot specify query or refdir with input!")
    }


    /*
    ================================================================================
                            Performing AAI on input data
    ================================================================================
    */
    if ( toLower(params.aai) in ['blast', 'diamond'] ) {
        PERFORM_AAI_BIOPYTHON (
            ch_aai_pairs,
            ch_prot_files
        )
        ch_versions  = ch_versions.mix(PERFORM_AAI_BIOPYTHON.out.versions)
        ch_aai_stats = PERFORM_AAI_BIOPYTHON.out.aai_stats.collect()
    }

    /*
    ================================================================================
                            Summarizing data
    ================================================================================
    */
    if ( toLower(params.aai) in ['blast', 'diamond'] ) {
        // PROCESS: Summarize AAI stats into one file
        AAI_SUMMARY_UNIX (
            ch_aai_stats
        )
        ch_versions             = ch_versions.mix(AAI_SUMMARY_UNIX.out.versions)
        ch_output_summary_files = ch_output_summary_files.mix(AAI_SUMMARY_UNIX.out.summary)
    }

    if ( toLower(params.aai) in ['blast', 'diamond'] && params.pocp ) {
        // PROCESS: Summarize POCP stats into one file
        POCP_SUMMARY_UNIX (
            ch_aai_stats
        )
        ch_versions             = ch_versions.mix(POCP_SUMMARY_UNIX.out.versions)
        ch_output_summary_files = ch_output_summary_files.mix(POCP_SUMMARY_UNIX.out.summary)
    }

    /*
    ================================================================================
                        Convert TSV outputs to Excel XLSX
    ================================================================================
    */

    if (params.create_excel_outputs) {
        CREATE_EXCEL_RUN_SUMMARY_PYTHON (
            ch_output_summary_files.collect()
        )
        ch_versions = ch_versions.mix(CREATE_EXCEL_RUN_SUMMARY_PYTHON.out.versions)

        CONVERT_TSV_TO_EXCEL_PYTHON (
            CREATE_EXCEL_RUN_SUMMARY_PYTHON.out.summary
        )
        ch_versions = ch_versions.mix(CONVERT_TSV_TO_EXCEL_PYTHON.out.versions)
    }

    /*
    ================================================================================
                        Collect version and QC information
    ================================================================================
    */
    // Collect version information
    ch_versions
        .unique()
        .collectFile(
            name:     "software_versions.yml",
            storeDir: params.tracedir
        )

    // Collect QC file check information
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
