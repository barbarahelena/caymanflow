/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { FASTP                  } from '../modules/nf-core/fastp/main'
include { CAYMAN_DOWNLOAD        } from '../modules/local/cayman/download'
include { CAYMAN_CAYMAN          } from '../modules/local/cayman/cayman'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow CAYMANFLOW {

    // Initialize channels
    ch_versions = Channel.empty()
    
    // Read input samplesheet
    Channel
        .fromPath(params.input)
        .splitCsv(header: true)
        .map { row ->
            def meta = [:]
            meta.id = row.sample
            meta.single_end = false
            
            def reads = []
            reads.add(file(row.fastq_1))
            reads.add(file(row.fastq_2))
            
            return [meta, reads]
        }
        .set { ch_input }

    //
    // MODULE: Quality control with fastp (optional)
    //
    if (!params.skip_qc) {
        ch_input_for_fastp = ch_input.map { meta, reads ->
            [meta, reads, []]
        }
        
        FASTP(
            ch_input_for_fastp,
            false,  // discard_trimmed_pass
            false,  // save_trimmed_fail
            false   // save_merged
        )
        ch_reads_for_cayman = FASTP.out.reads
        ch_versions = ch_versions.mix(FASTP.out.versions.first())
    } else {
        ch_reads_for_cayman = ch_input
    }

    //
    // MODULE: Cayman annotation on reads
    //
    // Download or use provided Cayman database
    if (!params.cayman_database) {
        CAYMAN_DOWNLOAD()
        cayman_db = CAYMAN_DOWNLOAD.out.db
    } else {
        cayman_db = Channel.fromPath(params.cayman_database)
    }

    // Concatenate paired-end reads for Cayman
    // Cayman needs a single FASTQ file, so we'll concatenate R1 and R2
    ch_reads_concat = ch_reads_for_cayman.map { meta, reads ->
        [meta, reads]
    }

    CAYMAN_CAYMAN(
        ch_reads_concat,
        cayman_db
    )
    ch_versions = ch_versions.mix(CAYMAN_CAYMAN.out.versions.first())

    emit:
    cayman_results = CAYMAN_CAYMAN.out.cayman
    versions       = ch_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
