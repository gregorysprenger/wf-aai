nextflow.enable.dsl=2

include { BLAST } from '../../modules/local/blast.nf'

workflow ALIGN_BLAST {
    take:
        pairs_ch
    main:
        BLAST (
            pairs_ch
        )
    emit:
        versions = BLAST.out.versions
        stats = BLAST.out.stats
}