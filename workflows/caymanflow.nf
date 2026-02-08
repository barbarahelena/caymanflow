/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { softwareVersionsToYAML      } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { FASTP                       } from '../modules/nf-core/fastp/main'
include { CAYMAN_DOWNLOAD             } from '../modules/local/cayman/download'
include { CAYMAN_UNZIP                } from '../modules/local/cayman/unzip'
include { BWA_INDEX                   } from '../modules/local/bwa_index'
include { CAYMAN_CAYMAN               } from '../modules/local/cayman/cayman'
include { GUNZIP                      } from '../modules/nf-core/gunzip/main'

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
        CAYMAN_DOWNLOAD(params.cayman_dbname)
        
        // Combine the two outputs into a single channel for CAYMAN_UNZIP
        ch_cayman_zips = CAYMAN_DOWNLOAD.out.gene_catalogues
            .join(CAYMAN_DOWNLOAD.out.annotations)
        
        CAYMAN_UNZIP(ch_cayman_zips)
        
        ch_db_gz = CAYMAN_UNZIP.out.db.map{ db -> tuple([id:"caymandb"], db) }
        GUNZIP(ch_db_gz)
        cayman_db = GUNZIP.out.gunzip.map{ _meta, gunzip -> gunzip }
        cayman_annotations = CAYMAN_UNZIP.out.annotations
        // Note: GUNZIP versions use a different format (topic: versions) not compatible with softwareVersionsToYAML
    } else {
        cayman_db = channel.fromPath(params.cayman_database)
        cayman_annotations = params.cayman_annotations ? channel.fromPath(params.cayman_annotations) : channel.empty()
    }

    // Index the Cayman database with BWA (if not already indexed)
    if (params.bwa_index) {
        // Use provided BWA index
        ch_bwa_index = channel.fromPath("${params.bwa_index}/*.{amb,ann,bwt,pac,sa}").collect()
        ch_cayman_db = cayman_db
    } else if (!params.skip_bwa_index) {
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
        ch_bwa_index,
        cayman_annotations
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
