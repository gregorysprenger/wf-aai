# wf-aai: Output

## Introduction

This document describes the output produced by the pipeline.

The directories listed below will be created in the results directory after the pipeline has finished. All paths are relative to the top-level results directory.

## Pipeline overview

The pipeline is built using [Nextflow](https://www.nextflow.io/) and processes FastA/Genbank files. Output differs between AAI comparison methods:

- [AAI output](#aai) - Output of each file pairing
  - [BLAST](#blast)
  - [DIAMOND](#diamond)
- [Summaries](#summaries) - Output summaries
- [Log files](#pipeline_info) - Nextflow and HPC logs, software information, and error list if applicable
- [Process logs](#process-logs) - Output and error logs for each process
- [QC file checks](#qc-file-checks) - Process output quality checks to determine if input files can be used in AAI comparisons

# Output File Structure

_Note: Output file structure is based on the output path given to `--outdir`._

_Note: `<SampleName>`, `<Pair1>`, and `<Pair2>` are parsed from input filenames and excludes the file extensions_

_Note: `<AAI>` is the name of the AAI tool (BLAST, DIAMOND) given to `--aai`. \[Default: BLAST\]_

| Output Directory                                        | Filename                                          | Explanation                                                                            |
| ------------------------------------------------------- | ------------------------------------------------- | -------------------------------------------------------------------------------------- |
| <a id="aai">AAI</a>                                     |                                                   | **AAI output directory**                                                               |
| AAI/\<AAI\>                                             |                                                   | **Output for specified AAI tool**                                                      |
|                                                         | proteomes.tsv                                     | List of all input proteomes when comparing all files vs each other                     |
|                                                         | queries.tsv                                       | List of query proteome(s) when comparing a query vs a reference panel                  |
|                                                         | references.tsv                                    | List of all reference proteomes when comparing a query vs a reference panel            |
|                                                         | pairs.tsv                                         | List of all pairings of proteomes that are found in proteomes.tsv                      |
| <a id="blast">AAI/BLAST/\<Pair1\>-\<Pair2\></a>         |                                                   | **BLAST (AAIb) output for each file pairing**                                          |
|                                                         | aai.\<Pair1\>,\<Pair2\>.stats.tab                 | AAI of each pair and their combined bidirectional AAI                                  |
|                                                         | blastp.\<Pair1\>,\<Pair2\>.tab                    | BLAST output of each fragment of \<Pair1\> vs reference \<Pair2\>                      |
|                                                         | blastp.\<Pair2\>,\<Pair1\>.tab                    | BLAST output of each fragment of \<Pair2\> vs reference \<Pair1\>                      |
|                                                         | blastp.\<Pair1\>,\<Pair2\>.filt.tab               | Filtered BLAST output                                                                  |
|                                                         | blastp.\<Pair1\>,\<Pair2\>.filt.two-way.tab       | Filtered bidirectional BLAST output                                                    |
| <a id="diamond">AAI/DIAMOND/\<Pair1\>-\<Pair2\></a>     |                                                   | **DIAMOND output for each file pairing**                                               |
|                                                         | aai.\<Pair1\>,\<Pair2\>.stats.tab                 | AAI of each pair and their combined bidirectional AAI                                  |
|                                                         | diamond.\<Pair1\>,\<Pair2\>.tab                   | DIAMOND output of each fragment of \<Pair1\> vs reference \<Pair2\>                    |
|                                                         | diamond.\<Pair2\>,\<Pair1\>.tab                   | DIAMOND output of each fragment of \<Pair2\> vs reference \<Pair1\>                    |
|                                                         | diamond.\<Pair1\>,\<Pair2\>.filt.tab              | Filtered DIAMOND output                                                                |
|                                                         | diamond.\<Pair1\>,\<Pair2\>.filt.two-way.tab      | Filtered bidirectional DIAMOND output                                                  |
| <a id="summaries">Summaries</a>                         |                                                   | **Output summary files**                                                               |
|                                                         | Summary.\<AAI\>.tsv                               | AAI summary of all samples                                                             |
|                                                         | Summary.QC_File_Checks.tab                        | Summary of QC file checks                                                              |
| <a id="pipeline_info">pipeline_info</a>                 |                                                   | **Log files**                                                                          |
|                                                         | nextflow_log.<job_ID>.txt                         | Log output from Nextflow                                                               |
|                                                         | AAI\_\<Number of Samples\>.o\<Submission Number\> | HPC output report                                                                      |
|                                                         | AAI\_\<Number of Samples\>.e\<Submission Number\> | HPC error report                                                                       |
|                                                         | pipeline_dag.\<YYYY-MM-DD_HH-MM-SS\>.html         | Direct acrylic graph of workflow                                                       |
|                                                         | report.\<YYYY-MM-DD_HH-MM-SS\>.html               | Nextflow summary report of workflow                                                    |
|                                                         | timeline.\<YYYY-MM-DD_HH-MM-SS\>.html             | Nextflow execution timeline of each process in workflow                                |
|                                                         | trace.\<YYYY-MM-DD_HH-MM-SS\>.txt                 | Nextflow execution tracing of workflow, which includes percent of CPU and memory usage |
|                                                         | software_versions.yml                             | Versions of software used in each process                                              |
|                                                         | errors.tsv                                        | Errors file if errors exist and summarizes the errors                                  |
| <a id="process-logs">pipeline_info/process_logs</a>     |                                                   | **Process log files**                                                                  |
|                                                         | \<SampleName\>.\<ProcessName\>.command.out        | Standard output for \<SampleName\> during process \<ProcessName\>                      |
|                                                         | \<SampleName\>.\<ProcessName\>.command.err        | Standard error for \<SampleName\> during process \<ProcessName\>                       |
| <a id="qc-file-checks">pipeline_info/qc_file_checks</a> |                                                   | **QC file check log files**                                                            |
|                                                         | \<SampleName\>.Initial_Input_Files.tsv            | Initial Fasta/Genbank File Check                                                       |
