process CAYMAN_PROCESS_COUNTS {
    tag "$meta.id"
    label 'process_single'
    
    conda "conda-forge::r-base=4.3.1 conda-forge::r-tidyverse=2.0.0 conda-forge::r-data.table=1.14.8"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/r-base_r-data.table_r-tidyverse:3634b3b70a5b6df7' :
        'community.wave.seqera.io/library/r-base_r-data.table_r-tidyverse:ea67dd87918b9545' }"

    input:
    tuple val(meta), path(gene_counts), path(aln_stats)
    path annotations

    output:
    tuple val(meta), path("*_genes_tpm.tsv")      , emit: genes_tpm
    tuple val(meta), path("*_families_cpm.tsv")   , emit: families_cpm
    tuple val(meta), path("*_sample_stats.tsv")   , emit: sample_stats
    path "versions.yml"                            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    #!/usr/bin/env Rscript
    
    library(tidyverse)
    library(data.table)
    
    # Read input files
    gene_counts <- read.csv("${gene_counts}", header = TRUE, sep = "\\t")
    aln_stats <- readLines("${aln_stats}")
    annotations <- read.csv("${annotations}", header = TRUE)
    
    sample_id <- "${prefix}"
    
    # Debug: Print input dimensions
    cat("\\n=== DEBUG: Input files ===\\n")
    cat("Sample ID:", sample_id, "\\n")
    cat("Gene counts dimensions:", nrow(gene_counts), "rows x", ncol(gene_counts), "cols\\n")
    cat("Gene counts columns:", paste(colnames(gene_counts), collapse = ", "), "\\n")
    cat("Annotations dimensions:", nrow(annotations), "rows x", ncol(annotations), "cols\\n")
    cat("Annotations columns:", paste(colnames(annotations), collapse = ", "), "\\n")
    cat("Alignment stats lines:", length(aln_stats), "\\n\\n")
    
    # ========== 1. Process gene-level TPM data ==========
    cat("=== Processing gene-level TPM ===\\n")
    
    # Calculate TPM from combined_rpkm and join with annotations for family info
    genes_tpm <- gene_counts %>%
        left_join(
            annotations %>% select(gene_id = sequenceID, family),
            by = c("gene" = "gene_id")
        ) %>%
        mutate(
            gene_name = str_extract(gene, "[^.]+\$"),  # Extract gene name after last dot
            tpm = combined_rpkm * 1000  # Convert RPKM to TPM (approximation)
        ) %>%
        select(gene, gene_name, family, tpm) %>%
        rename(gene_id = gene, !!sample_id := tpm)
    
    cat("Genes in TPM table:", nrow(genes_tpm), "\\n")
    cat("First few rows:\\n")
    print(head(genes_tpm, 3))
    cat("\\n")
    
    write_tsv(genes_tpm, "${prefix}_genes_tpm.tsv")
    
    # ========== 2. Process family-level CPM data ==========
    cat("=== Processing family-level CPM ===\\n")
    
    # Extract gene_id from gene column (everything before the last dot)
    genes_with_counts <- gene_counts %>% rename(gene_id = gene)
    
    cat("Genes with counts:", nrow(genes_with_counts), "\\n")
    cat("First few gene IDs:", paste(head(genes_with_counts[["gene_id"]], 3), collapse = ", "), "\\n")
    
    # Join with annotations
    genes_with_families <- genes_with_counts %>%
        left_join(
            annotations %>% select(gene_id = sequenceID, family),
            by = "gene_id"
        )
    cat("After join with annotations:", nrow(genes_with_families), "rows\\n")
    cat("Genes with family info:", sum(!is.na(genes_with_families[["family"]])), "\\n")
    
    cat("First few families:", paste(head(unique(genes_with_families[["family"]]), 3), collapse = ", "), "\\n")
    
    # Aggregate counts by family and calculate CPM
    families_cpm <- genes_with_families %>%
        filter(!is.na(family), family != "", family != "UNKNOWN") %>%
        group_by(family) %>%
        summarise(combined_raw = sum(combined_raw, na.rm = TRUE)) %>%
        mutate(
            cpm = (combined_raw / sum(combined_raw)) * 1e6
        ) %>%
        select(family, cpm) %>%
        rename(!!sample_id := cpm)
    
    cat("Unique families after aggregation:", nrow(families_cpm), "\\n")
    cat("First few family CPM rows:\\n")
    print(head(families_cpm, 3))
    cat("\\n")
    
    write_tsv(families_cpm, "${prefix}_families_cpm.tsv")
    
    # ========== 3. Calculate sample statistics ==========
    cat("=== Processing sample statistics ===\\n")
    
    # Parse alignment statistics using stringr
    total_line <- str_subset(aln_stats, regex("total", ignore_case = TRUE))
    passed_line <- str_subset(aln_stats, regex("passed", ignore_case = TRUE))
    seqid_line <- str_subset(aln_stats, regex("seqid", ignore_case = TRUE))
    
    cat("Total line:", total_line, "\\n")
    cat("Passed line:", passed_line, "\\n")
    cat("Seqid line:", seqid_line, "\\n")
    
    # Extract numbers from lines
    total_reads <- as.numeric(str_extract(total_line, "\\\\d+"))
    passed_reads <- as.numeric(str_extract(passed_line, "\\\\d+"))
    unique_genes <- as.numeric(str_extract(seqid_line, "\\\\d+"))
    
    cat("Parsed values - Total:", total_reads, "Passed:", passed_reads, "Unique genes:", unique_genes, "\\n")
    
    # Calculate statistics
    filter_efficiency <- passed_reads / total_reads
    richness <- unique_genes
    complexity <- unique_genes / passed_reads
    
    cazy_reads <- gene_counts %>% summarise(total = sum(combined_raw, na.rm = TRUE)) %>% pull(total)    
    cat("CAZy reads found:", cazy_reads, "\\n")
    
    pct_cazy <- (cazy_reads / passed_reads) * 100
    
    # Create statistics table
    sample_stats <- tibble(
        sample = sample_id,
        total_reads = total_reads,
        passed_reads = passed_reads,
        filter_efficiency = filter_efficiency,
        richness = richness,
        complexity = complexity,
        pct_cazy_reads = pct_cazy
    )
    
    cat("Final sample statistics:\\n")
    print(sample_stats)
    cat("\\n")
    
    write_tsv(sample_stats, "${prefix}_sample_stats.tsv")
    
    # Write versions
    version_file <- file("versions.yml", "w")
    writeLines(c(
        '"${task.process}":',
        paste0('    r-base: ', R.version.string),
        paste0('    tidyverse: ', packageVersion("tidyverse"))
    ), version_file)
    close(version_file)
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo -e "gene_id\\tgene_name\\tfamily\\t${prefix}" > ${prefix}_genes_tpm.tsv
    echo -e "GMGC10.000_000_001.GENE1\\tGENE1\\tGH1\\t100" >> ${prefix}_genes_tpm.tsv
    
    echo -e "family\\t${prefix}" > ${prefix}_families_cpm.tsv
    echo -e "family1\\t100" >> ${prefix}_families_cpm.tsv
    
    echo -e "sample\\ttotal_reads\\tpassed_reads\\tfilter_efficiency\\trichness\\tcomplexity\\tpct_cazy_reads" > ${prefix}_sample_stats.tsv
    echo -e "${prefix}\\t1000000\\t900000\\t0.9\\t5000\\t0.0055\\t2.5" >> ${prefix}_sample_stats.tsv
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: 4.3.1
        tidyverse: 2.0.0
    END_VERSIONS
    """
}
