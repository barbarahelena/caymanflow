# Caymanflow

A Nextflow pipeline for running Cayman on shotgun paired-end metagenomic reads.

## Introduction

**Caymanflow** is a simple bioinformatics pipeline that annotates shotgun metagenomic paired-end reads using [Cayman](https://github.com/zellerlab/cayman).

## Pipeline Summary

1. **Optional Quality Control**: Quality filtering and adapter trimming with [`fastp`](https://github.com/OpenGene/fastp) (can be skipped with `--skip_qc`)
2. **Annotation**: Direct annotation of metagenomic reads using [`Cayman`](https://github.com/zellerlab/cayman)

## Quick Start

### 1. Prepare your samplesheet

Create a CSV file with your paired-end FASTQ files:

```csv
sample,fastq_1,fastq_2
sample1,/path/to/sample1_R1.fastq.gz,/path/to/sample1_R2.fastq.gz
sample2,/path/to/sample2_R1.fastq.gz,/path/to/sample2_R2.fastq.gz
```

### 2. Run the pipeline

```bash
nextflow run caymanflow \
  --input samplesheet.csv \
  --outdir results \
  -profile docker
```

## Parameters

### Required Parameters

- `--input`: Path to the samplesheet CSV file

### Optional Parameters

- `--outdir`: Output directory (default: `./results`)
- `--skip_qc`: Skip quality control step (default: `false`)
- `--cayman_database`: Path to pre-downloaded Cayman database (if not provided, will be downloaded automatically)

### Profile Options

- `-profile docker`: Use Docker containers
- `-profile singularity`: Use Singularity containers
- `-profile conda`: Use Conda environments

## Output

The pipeline will create the following output structure:

```
results/
├── qc/
│   └── fastp/                 # Quality control reports (if not skipped)
│       ├── *.json
│       └── *.html
└── cayman/                    # Cayman annotation results
    └── *.csv
```

## Credits

This pipeline uses:
- [Nextflow](https://www.nextflow.io/)
- [fastp](https://github.com/OpenGene/fastp) for quality control
- [Cayman](https://github.com/zellerlab/cayman) for read annotation

## License

This pipeline is available under the MIT License.
