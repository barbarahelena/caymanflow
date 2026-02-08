process BWA_INDEX {
    tag "$fasta"
    label 'process_highmemory'
    storeDir "db"

    conda "bioconda::bwa=0.7.18"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bwa:0.7.18--he4a0461_0':
        'biocontainers/bwa:0.7.18--he4a0461_0' }"

    input:
    path(fasta)

    output:
    path("*.amb")     , emit: index_amb
    path("*.ann")     , emit: index_ann
    path("*.bwt")     , emit: index_bwt
    path("*.pac")     , emit: index_pac
    path("*.sa")      , emit: index_sa
    path "versions.yml"                             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    bwa index ${fasta}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bwa: \$(bwa 2>&1 | grep -e '^Version' | sed 's/Version: //')
    END_VERSIONS
    """

    stub:
    """
    touch ${fasta}.amb
    touch ${fasta}.ann
    touch ${fasta}.bwt
    touch ${fasta}.pac
    touch ${fasta}.sa

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bwa: \$(bwa 2>&1 | grep -e '^Version' | sed 's/Version: //')
    END_VERSIONS
    """
}
