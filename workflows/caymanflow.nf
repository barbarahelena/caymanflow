/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { softwareVersionsToYAML      } from '../subworkflows/nf-core/utils_nfcore_pipeline'

include { FASTP                  } from '../modules/nf-core/fastp/main'
include { CAYMAN_DOWNLOAD        } from '../modules/local/cayman/download'
include { BWA_INDEX              } from '../modules/local/bwa_index'
include { CAYMAN_CAYMAN          } from '../modules/local/cayman/cayman'
include { GUNZIP                 } from '../modules/nf-core/gunzip/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow CAYMANFLOW {

    take:
    ch_samplesheet // channel: samplesheet read in from --input

    main:
    // Initialize channels
    ch_versions = channel.empty()

    //
    // MODULE: Quality control with fastp (optional)
    //
    if (!params.skip_qc) {
        FASTP(
            ch_samplesheet,
            [],
            false,  // discard_trimmed_pass
            false,  // save_trimmed_fail
            false   // save_merged
        )
        ch_reads_for_cayman = FASTP.out.reads
        ch_versions = ch_versions.mix(FASTP.out.versions)
    } else {
        ch_reads_for_cayman = ch_samplesheet
    }

    //
    // MODULE: Cayman annotation on reads
    //
    // Download or use provided Cayman database
    if (!params.cayman_database) {
        CAYMAN_DOWNLOAD()
        ch_db_gz = CAYMAN_DOWNLOAD.out.db.map{ db -> tuple([id:"caymandb"], db) }
        GUNZIP(ch_db_gz)
        cayman_db = GUNZIP.out.gunzip.map{ _meta, gunzip -> gunzip }
        // Note: GUNZIP versions use a different format (topic: versions) not compatible with softwareVersionsToYAML
    } else {
        cayman_db = channel.fromPath(params.cayman_database)
    }

    // Index the Cayman database with BWA (if not already indexed)
    if (!params.skip_bwa_index) {
        BWA_INDEX(cayman_db)
        ch_versions = ch_versions.mix(BWA_INDEX.out.versions)
        
        // Collect all index files
        ch_bwa_index = BWA_INDEX.out.index_amb
            .mix(BWA_INDEX.out.index_ann)
            .mix(BWA_INDEX.out.index_bwt)
            .mix(BWA_INDEX.out.index_pac)
            .mix(BWA_INDEX.out.index_sa)
            .collect()
        
        ch_cayman_db = cayman_db
    } else {
        // If skipping indexing, assume index files exist alongside the database
        ch_bwa_index = channel.empty()
        ch_cayman_db = cayman_db
    }

    // Run Cayman profile on paired-end reads
    // Cayman needs the reference fasta and will use the BWA index
    // The index files are automatically found by Cayman using the same prefix as the reference
    CAYMAN_CAYMAN(
        ch_reads_for_cayman,
        ch_cayman_db,
        ch_bwa_index
    )
    ch_versions = ch_versions.mix(CAYMAN_CAYMAN.out.versions)


    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'amrfinderflow_software_versions.yml',
            sort: true,
            newLine: true,
        )

    emit:
    versions       = ch_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
