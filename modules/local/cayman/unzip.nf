process CAYMAN_UNZIP {
    tag "${dbname}"
    label 'process_single'
    storeDir "db"

    conda "conda-forge::p7zip=16.02"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/p7zip:16.02' :
        'biocontainers/p7zip:16.02' }"

    input:
    tuple val(dbname), path(gene_catalogues_zip), path(annotations_zip)

    output:
    path("${dbname}.fna.gz"), emit: db
    path("${dbname}_annotations.csv"), emit: annotations

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    # Unzip gene catalogues using 7za (handles newer zip formats)
    7za x ${gene_catalogues_zip}
    
    # Unzip annotations using 7za
    7za x ${annotations_zip}
    
    # Move the selected database to main folder
    # Try with and without .no-rare in the filename
    if [ -f "gene_catalogues/GMGC10.${dbname}.95nr.0.5.percent.prevalence.fna.gz" ]; then
        mv gene_catalogues/GMGC10.${dbname}.95nr.0.5.percent.prevalence.fna.gz ${dbname}.fna.gz
    elif [ -f "gene_catalogues/GMGC10.${dbname}.95nr.no-rare.0.5.percent.prevalence.fna.gz" ]; then
        mv gene_catalogues/GMGC10.${dbname}.95nr.no-rare.0.5.percent.prevalence.fna.gz ${dbname}.fna.gz
    else
        echo "Error: Database file not found for ${dbname}"
        exit 1
    fi
    
    # Move the selected annotations to main folder (always has .no-rare)
    mv annots/GMGC10.${dbname}.95nr.no-rare.0.5.percent.prevalence_all_v3_FINAL.csv ${dbname}_annotations.csv
    
    # Clean up unpacked folders
    rm -rf gene_catalogues annots
    """
    
    stub:
    """
    touch ${dbname}.fna.gz
    touch ${dbname}_annotations.csv
    """
}
