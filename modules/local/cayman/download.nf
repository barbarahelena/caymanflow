process CAYMAN_DOWNLOAD {
    tag "download"
    label 'process_single'
    storeDir "${ task.ext.storeDir ?: "${params.outdir}/db/cayman" }"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/curl%3A7.80.0' :
        'biocontainers/curl:7.80.0' }"

    output:
    path("GMGC10.human-gut.95nr.fna.gz"), emit: db

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    curl -L -f -o GMGC10.human-gut.95nr.fna.gz "http://gmgc.embl.de/downloads/v1.0/subcatalogs/GMGC10.human-gut.95nr.no-rare.fna.gz"
    
    # Verify the file was downloaded
    if [ ! -f GMGC10.human-gut.95nr.fna.gz ]; then
        echo "Error: Failed to download database"
        exit 1
    fi
    """
    
    stub:
    """
    touch GMGC10.human-gut.95nr.fna.gz
    """
}