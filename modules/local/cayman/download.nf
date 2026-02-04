process CAYMAN_DOWNLOAD {
    tag "download"
    label 'process_single'
    storeDir "${ task.ext.storeDir ?: 'db/cayman' }"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/curl%3A7.80.0' :
        'biocontainers/curl:7.80.0' }"

    output:
    path("v3"), emit: db

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    curl "https://zenodo.org/records/13998227/files/v3.zip?download=1" -o v3.zip
    unzip v3.zip -d .
    """
}