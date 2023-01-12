nextflow.enable.dsl=2

include { DIAMOND } from '../../modules/local/diamond.nf'

workflow ALIGN_DIAMOND {
    take:
        pairs_ch
    main:
        DIAMOND (
            pairs_ch
        )
    emit:
        versions = DIAMOND.out.versions
        stats = DIAMOND.out.stats
}