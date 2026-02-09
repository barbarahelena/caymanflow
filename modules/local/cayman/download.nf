process CAYMAN_DOWNLOAD {
    tag "download"
    label 'process_single'
    storeDir "db"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/curl%3A7.80.0' :
        'biocontainers/curl:7.80.0' }"

    input:
    val(dbname)

    output:
    tuple val(dbname), path("gene_catalogues.zip"), emit: gene_catalogues
    tuple val(dbname), path("gene_catalogue_annotations.zip"), emit: annotations

    when:
    task.ext.when == null || task.ext.when


    script:
    """
    # Download gene catalogues
    curl -L -o gene_catalogues.zip https://zenodo.org/records/10473258/files/gene_catalogues.zip
    
    # Download annotations
    curl -L -o gene_catalogue_annotations.zip https://zenodo.org/records/10473258/files/gene_catalogue_annotations.zip
    """
    
    stub:
    """
    touch gene_catalogues.zip
    touch gene_catalogue_annotations.zip
    """
}