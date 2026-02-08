process CAYMAN_CAYMAN {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::cayman=0.10.1"
    container "docker://ghcr.io/zellerlab/cayman@sha256:29da4ffcbb1cf4efe5d36213eac9c036e1be2358018db7122a4035f1f16983c0"

    input:
    tuple val(meta), path(reads)
    path(db, stageAs: "database.fna")
    path(index, stageAs: "database.fna.*", arity: '0..*')

    output:
    tuple val(meta), path("${meta.id}/*"), emit: cayman
    path "versions.yml"                  , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def r1 = reads[0]
    def r2 = reads[1]
    """
    cayman profile \\
        --reference database.fna \\
        --reads ${r1} ${r2} \\
        --cpus_for_alignment ${task.cpus} \\
        ${args} \\
        --outdir ${prefix}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        cayman: \$(cayman --version |& sed '1!d ; s/cayman //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p ${prefix}
    touch ${prefix}/profile_results.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        cayman: \$(cayman --version |& sed '1!d ; s/cayman //')
    END_VERSIONS
    """
}
