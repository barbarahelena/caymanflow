/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { softwareVersionsToYAML      } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { FASTP                       } from '../modules/nf-core/fastp/main'
include { BOWTIE2_BUILD               } from '../modules/local/bowtie2/build'
include { BOWTIE2_FILTERHOST          } from '../modules/local/bowtie2/filterhost'
include { COUNT_READS                 } from '../modules/local/countreads'
include { COUNT_READS as COUNT_READS_QC } from '../modules/local/countreads'
include { COUNT_READS as COUNT_READS_HOST } from '../modules/local/countreads'
include { CAT_READCOUNTS              } from '../modules/local/cat_readcounts'
include { CAT_READCOUNTS as CAT_READCOUNTS_QC } from '../modules/local/cat_readcounts'
include { CAT_READCOUNTS as CAT_READCOUNTS_HOST } from '../modules/local/cat_readcounts'
include { CAYMAN_DOWNLOAD             } from '../modules/local/cayman/download'
include { CAYMAN_UNZIP                } from '../modules/local/cayman/unzip'
include { BWA_INDEX                   } from '../modules/local/bwa_index'
include { CAYMAN_CAYMAN               } from '../modules/local/cayman/cayman'
include { CAYMAN_PROCESS_COUNTS       } from '../modules/local/cayman/process_counts'
include { CAYMAN_MERGE_TABLES         } from '../modules/local/cayman/merge_tables'
include { GUNZIP                      } from '../modules/nf-core/gunzip/main'
include { GUNZIP as GUNZIP_CAYMAN     } from '../modules/nf-core/gunzip/main'
include { GUNZIP as GUNZIP_STATS      } from '../modules/nf-core/gunzip/main'

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
    // MODULE: Count reads in raw input
    //
    COUNT_READS(ch_samplesheet)
    ch_versions = ch_versions.mix(COUNT_READS.out.versions.first())
    ch_raw_readcounts = COUNT_READS.out.counts

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
        ch_reads_after_qc = FASTP.out.reads
        ch_versions = ch_versions.mix(FASTP.out.versions)
        
        // Count reads after QC
        COUNT_READS_QC(ch_reads_after_qc)
        ch_versions = ch_versions.mix(COUNT_READS_QC.out.versions.first())
        ch_qc_readcounts = COUNT_READS_QC.out.counts
    } else {
        ch_reads_after_qc = ch_samplesheet
        ch_qc_readcounts = channel.empty()
    }

    //
    // MODULE: Host read removal with Bowtie2 (optional)
    //
    if (!params.skip_host_removal) {
        // Prepare host reference (from iGenomes or user-provided)
        if (params.genome && !params.igenomes_ignore) {
            // Use iGenomes reference
            if (params.genomes && params.genomes.containsKey(params.genome)) {
                if (params.genomes[params.genome].bowtie2) {
                    ch_host_index = channel.fromPath("${params.genomes[params.genome].bowtie2}/*").collect()
                } else {
                    error "Bowtie2 index not available for genome '${params.genome}' in iGenomes config"
                }
            } else {
                error "Genome '${params.genome}' not found in iGenomes config"
            }
        } else if (params.host_bowtie2_index) {
            // Use user-provided Bowtie2 index
            ch_host_index = channel.fromPath("${params.host_bowtie2_index}/*").collect()
        } else if (params.host_fasta) {
            // Build Bowtie2 index from user-provided FASTA
            ch_host_fasta = channel.fromPath(params.host_fasta)
            BOWTIE2_BUILD(ch_host_fasta)
            ch_host_index = BOWTIE2_BUILD.out.index.collect()
            ch_versions = ch_versions.mix(BOWTIE2_BUILD.out.versions)
        } else {
            error "Host removal enabled but no reference provided. Use --genome, --host_bowtie2_index, or --host_fasta"
        }

        // Filter host reads
        BOWTIE2_FILTERHOST(
            ch_reads_after_qc,
            ch_host_index
        )
        ch_reads_for_cayman = BOWTIE2_FILTERHOST.out.reads
        ch_versions = ch_versions.mix(BOWTIE2_FILTERHOST.out.versions)
        
        // Count reads after host removal
        COUNT_READS_HOST(ch_reads_for_cayman)
        ch_versions = ch_versions.mix(COUNT_READS_HOST.out.versions.first())
        ch_host_readcounts = COUNT_READS_HOST.out.counts
    } else {
        ch_reads_for_cayman = ch_reads_after_qc
        ch_host_readcounts = channel.empty()
    }

    //
    // MODULE: Collect all read counts and create summary tables
    //
    CAT_READCOUNTS(ch_raw_readcounts.collect())
    ch_versions = ch_versions.mix(CAT_READCOUNTS.out.versions)
    
    if (!params.skip_qc) {
        CAT_READCOUNTS_QC(ch_qc_readcounts.collect())
        ch_versions = ch_versions.mix(CAT_READCOUNTS_QC.out.versions)
    }
    
    if (!params.skip_host_removal) {
        CAT_READCOUNTS_HOST(ch_host_readcounts.collect())
        ch_versions = ch_versions.mix(CAT_READCOUNTS_HOST.out.versions)
    }

    //
    // MODULE: Cayman annotation on reads
    //
    
    // Print configuration summary at the start
    log.info "==================================================="
    log.info "CAYMANFLOW CONFIGURATION"
    log.info "==================================================="
    
    // Host removal settings
    if (!params.skip_host_removal) {
        log.info "Host removal: ENABLED"
        if (params.genome && !params.igenomes_ignore) {
            log.info "Host genome: ${params.genome} (iGenomes)"
        } else if (params.host_bowtie2_index) {
            log.info "Host index: ${params.host_bowtie2_index}"
        } else if (params.host_fasta) {
            log.info "Host FASTA: ${params.host_fasta}"
        }
    } else {
        log.info "Host removal: DISABLED"
    }
    log.info ""
    
    if (!params.cayman_database) {
        log.info "Database mode: Automatic download from Zenodo"
        log.info "Database name: ${params.cayman_dbname}"
    } else {
        log.info "Database mode: User-provided files"
        log.info "Database path: ${params.cayman_database}"
        log.info "Database name: ${params.cayman_dbname}"
        log.info "Annotations path: ${params.cayman_annotations ?: 'NOT PROVIDED'}"
        log.info "BWA index path: ${params.bwa_index ?: 'NOT PROVIDED (will be generated)'}"
        
        if (!params.cayman_annotations) {
            log.warn "WARNING: No annotations file provided (--cayman_annotations)"
            log.warn "Cayman requires annotations - will download matching annotations from Zenodo"
        }
    }
    
    log.info "==================================================="
    log.info ""
    
    // Download or use provided Cayman database
    if (!params.cayman_database) {
        // Download database from Zenodo (always returns .zip files)
        CAYMAN_DOWNLOAD(params.cayman_dbname)
        
        // Combine the two outputs into a single channel for CAYMAN_UNZIP
        ch_cayman_zips = CAYMAN_DOWNLOAD.out.gene_catalogues
            .join(CAYMAN_DOWNLOAD.out.annotations)
        
        // Unzip downloaded files
        CAYMAN_UNZIP(ch_cayman_zips)
        
        // Gunzip the database
        ch_db_gz = CAYMAN_UNZIP.out.db.map{ db -> tuple([id:"caymandb"], db) }
        GUNZIP(ch_db_gz)
        cayman_db = GUNZIP.out.gunzip.map{ _meta, gunzip -> gunzip }.first()
        cayman_annotations = CAYMAN_UNZIP.out.annotations.first()
        
        // Downloaded databases always need to be indexed
        BWA_INDEX(cayman_db)
        ch_versions = ch_versions.mix(BWA_INDEX.out.versions)
        
        // Collect database + all index files together
        ch_bwa_index = cayman_db
            .mix(BWA_INDEX.out.index_amb)
            .mix(BWA_INDEX.out.index_ann)
            .mix(BWA_INDEX.out.index_bwt)
            .mix(BWA_INDEX.out.index_pac)
            .mix(BWA_INDEX.out.index_sa)
            .collect()
        
    } else {
        // Use provided database - handle different compression formats
        def db_path = params.cayman_database
        def anno_path = params.cayman_annotations
        
        // Check if annotations are provided - if not, download from Zenodo
        if (!anno_path) {
            // Download both database and annotations from Zenodo
            CAYMAN_DOWNLOAD(params.cayman_dbname)
            
            // Combine and unzip to get annotations
            ch_downloads = CAYMAN_DOWNLOAD.out.gene_catalogues
                .join(CAYMAN_DOWNLOAD.out.annotations)
            
            CAYMAN_UNZIP(ch_downloads)
            cayman_annotations = CAYMAN_UNZIP.out.annotations.first()
        }
        
        // Check if BWA index is provided first
        if (params.bwa_index) {
            // Use provided BWA index (includes the .fna file)
            // No need to decompress database since index already has it
            ch_bwa_index = channel.fromPath("${params.bwa_index}/*").collect()
            
            // Handle annotations - check if they need unzipping (only if provided by user)
            if (anno_path) {
                if (anno_path.endsWith('.zip')) {
                    // Unzip annotations
                    ch_anno_zip = channel.of([params.cayman_dbname, file(db_path), file(anno_path)])
                    CAYMAN_UNZIP(ch_anno_zip)
                    cayman_annotations = CAYMAN_UNZIP.out.annotations.first()
                } else {
                    // Use annotations directly
                    cayman_annotations = channel.fromPath(anno_path)
                }
            }
            // If anno_path was null, cayman_annotations already set from download above
        } else {
            // No index provided, so we need to prepare the database and create index
            
            // Handle database decompression based on extension
            if (db_path.endsWith('.zip')) {
                // Unzip the provided zip file (assuming it contains both database and annotations)
                ch_cayman_zips = channel.of([params.cayman_dbname, file(db_path), file(anno_path ?: 'dummy')])
                CAYMAN_UNZIP(ch_cayman_zips)
                
                ch_db_gz = CAYMAN_UNZIP.out.db.map{ db -> tuple([id:"caymandb"], db) }
                GUNZIP(ch_db_gz)
                cayman_db = GUNZIP.out.gunzip.map{ _meta, gunzip -> gunzip }.first()
                
                // If user provided zip, use annotations from it; otherwise already set from download
                if (anno_path) {
                    cayman_annotations = CAYMAN_UNZIP.out.annotations.first()
                }
            } else if (db_path.endsWith('.gz')) {
                // Gunzip the database
                ch_db_gz = channel.fromPath(db_path).map{ db -> tuple([id:"caymandb"], db) }
                GUNZIP(ch_db_gz)
                cayman_db = GUNZIP.out.gunzip.map{ _meta, gunzip -> gunzip }.first()
                
                // Handle annotations (only if user provided, otherwise already set from download)
                if (anno_path) {
                    cayman_annotations = channel.fromPath(anno_path)
                }
            } else {
                // Database is already decompressed
                cayman_db = channel.fromPath(db_path).first()
                
                // Handle annotations (only if user provided, otherwise already set from download)
                if (anno_path) {
                    cayman_annotations = channel.fromPath(anno_path)
                }
            }
            
            // Generate BWA index for the provided database
            BWA_INDEX(cayman_db)
            ch_versions = ch_versions.mix(BWA_INDEX.out.versions)
            
            // Collect database + all index files together
            ch_bwa_index = cayman_db
                .mix(BWA_INDEX.out.index_amb)
                .mix(BWA_INDEX.out.index_ann)
                .mix(BWA_INDEX.out.index_bwt)
                .mix(BWA_INDEX.out.index_pac)
                .mix(BWA_INDEX.out.index_sa)
                .collect()
        }
    }

    // Run Cayman profile on paired-end reads
    // Cayman needs the reference fasta and will use the BWA index
    // The index files are automatically found by Cayman using the same prefix as the reference
    CAYMAN_CAYMAN(
        ch_reads_for_cayman,
        ch_bwa_index,
        cayman_annotations,
        params.cayman_dbname
    )
    ch_versions = ch_versions.mix(CAYMAN_CAYMAN.out.versions)

    // Gunzip compressed outputs
    GUNZIP_CAYMAN(CAYMAN_CAYMAN.out.gene_counts)
    GUNZIP_STATS(CAYMAN_CAYMAN.out.aln_stats)
    
    //
    // MODULE: Process Cayman counts for each sample
    //
    // Join gunzipped gene counts with alignment stats
    ch_cayman_per_sample = GUNZIP_CAYMAN.out.gunzip
        .join(GUNZIP_STATS.out.gunzip)
    
    CAYMAN_PROCESS_COUNTS(
        ch_cayman_per_sample,
        cayman_annotations
    )
    ch_versions = ch_versions.mix(CAYMAN_PROCESS_COUNTS.out.versions.first())
    
    //
    // MODULE: Merge all samples into final tables
    //
    CAYMAN_MERGE_TABLES(
        CAYMAN_PROCESS_COUNTS.out.families_cpm.map{ _meta, file -> file }.collect(),
        CAYMAN_PROCESS_COUNTS.out.sample_stats.map{ _meta, file -> file }.collect()
    )
    ch_versions = ch_versions.mix(CAYMAN_MERGE_TABLES.out.versions)

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'cayman_software_versions.yml',
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
