process CAYMAN_MERGE_TABLES {
    label 'process_single'
    
    conda "conda-forge::r-base=4.3.1 conda-forge::r-tidyverse=2.0.0 conda-forge::r-data.table=1.14.8"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/r-base_r-data.table_r-tidyverse:3634b3b70a5b6df7' :
        'community.wave.seqera.io/library/r-base_r-data.table_r-tidyverse:ea67dd87918b9545' }"

    input:
    path families_cpm
    path sample_stats

    output:
    path "families_cpm_table.tsv"   , emit: families_table
    path "sample_statistics.tsv"    , emit: stats_table
    path "versions.yml"              , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    #!/usr/bin/env Rscript
    
    library(tidyverse)
    library(data.table)
    
    # ========== 1. Merge family CPM tables ==========
    family_files <- list.files(pattern = "_families_cpm\\\\.tsv\$", full.names = TRUE)
    
    if(length(family_files) > 0) {
        families_list <- lapply(family_files, function(f) {
            fread(f, header = TRUE)
        })
        
        # Merge all family tables by family
        families_merged <- families_list %>%
            reduce(full_join, by = "family") %>%
            replace(is.na(.), 0)  # Replace NA with 0
        
        write_tsv(families_merged, "families_cpm_table.tsv")
    } else {
        # Create empty file if no input
        writeLines("family", "families_cpm_table.tsv")
    }
    
    # ========== 2. Merge sample statistics ==========
    stats_files <- list.files(pattern = "_sample_stats\\\\.tsv\$", full.names = TRUE)
    
    if(length(stats_files) > 0) {
        stats_list <- lapply(stats_files, function(f) {
            fread(f, header = TRUE)
        })
        
        # Combine all statistics
        stats_merged <- bind_rows(stats_list)
        
        write_tsv(stats_merged, "sample_statistics.tsv")
    } else {
        # Create empty file if no input
        writeLines("sample\\ttotal_reads\\tpassed_reads\\tfilter_efficiency\\trichness\\tcomplexity\\tpct_cazy_reads", 
                   "sample_statistics.tsv")
    }
    
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
    """
    echo -e "family\\tsample1\\tsample2" > families_cpm_table.tsv
    echo -e "family1\\t100\\t200" >> families_cpm_table.tsv
    
    echo -e "sample\\ttotal_reads\\tpassed_reads\\tfilter_efficiency\\trichness\\tcomplexity\\tpct_cazy_reads" > sample_statistics.tsv
    echo -e "sample1\\t1000000\\t900000\\t0.9\\t5000\\t0.0055\\t2.5" >> sample_statistics.tsv
    echo -e "sample2\\t1000000\\t900000\\t0.9\\t5000\\t0.0055\\t2.5" >> sample_statistics.tsv
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: 4.3.1
        tidyverse: 2.0.0
    END_VERSIONS
    """
}
