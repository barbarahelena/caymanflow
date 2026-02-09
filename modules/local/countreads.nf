process COUNT_READS {
    tag "$meta.id"
    label 'process_single'
    
    conda "conda-forge::sed=4.7"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'nf-core/ubuntu:20.04' }"

    input:
    tuple val(meta), path(reads)

    output:
    path "*_readcount.txt"      , emit: counts
    path "versions.yml"         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    // Count reads in forward file only (R1)
    def forward_read = meta.single_end ? reads : reads[0]
    """
    # Count reads in forward FASTQ file
    # Each read is 4 lines in FASTQ format, so divide line count by 4
    read_count=\$(zcat ${forward_read} | wc -l | awk '{print \$1/4}')
    
    # Write output
    echo "Reads in ${prefix}: \${read_count}" > ${prefix}_readcount.txt
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gzip: \$(gzip --version 2>&1 | head -n 1 | sed 's/^gzip //; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "Reads in ${prefix}: 1000" > ${prefix}_readcount.txt
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gzip: \$(gzip --version 2>&1 | head -n 1 | sed 's/^gzip //; s/ .*\$//')
    END_VERSIONS
    """
}
