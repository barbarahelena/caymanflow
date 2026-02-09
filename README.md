# Caymanflow

A Nextflow pipeline for running Cayman on shotgun paired-end metagenomic reads.

## Introduction

**Caymanflow** is a bioinformatics pipeline that annotates shotgun metagenomic paired-end reads using [Cayman](https://github.com/zellerlab/cayman).

## Pipeline Summary

1. Read counting at multiple stages (raw, post-QC, post-host-removal)
2. Optional quality control with fastp
3. Optional host read removal with Bowtie2 (supports iGenomes)
4. Direct functional annotation with Cayman
5. Automated processing of gene counts into publication-ready tables

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

### 3. With host removal and custom database

```bash
nextflow run caymanflow \
  --input samplesheet.csv \
  --genome GRCh38 \
  --cayman_dbname human-gut \
  --outdir results \
  -profile singularity
```

## Main Parameters

- `--input`: Path to samplesheet CSV file (required)
- `--outdir`: Output directory (default: `./results`)
- `--skip_qc`: Skip quality control step
- `--skip_host_removal`: Skip host read removal step
- `--genome`: iGenomes reference (e.g., `GRCh38`, `GRCm38`, `mm10`)
- `--cayman_dbname`: Database name (default: `human-gut`)
- `-profile`: Software management (`docker`, `singularity`, `conda`)

## Output

```
results/
├── readcounts/              # Read counts at each processing stage
├── qc/fastp/               # Quality control reports
├── host_removal/           # Host removal statistics
├── cayman/
│   ├── compressed/         # Raw Cayman outputs
│   ├── uncompressed/       # Decompressed outputs
│   ├── processed/          # Per-sample processed files (gene TPM, family CPM, stats)
│   └── tables/             # Merged tables (family CPM, sample statistics)
└── pipeline_info/          # Execution reports
```

## Documentation

For detailed documentation including:
- Complete parameter list
- Database options and configuration
- Host removal with iGenomes
- Output file descriptions
- Advanced usage examples

Please see [docs/usage.md](docs/usage.md)

## Credits

This pipeline uses:
- [Nextflow](https://www.nextflow.io/)
- [fastp](https://github.com/OpenGene/fastp) for quality control
- [Bowtie2](https://bowtie-bio.sourceforge.net/bowtie2/) for host removal
- [Cayman](https://github.com/zellerlab/cayman) for read annotation

## License

This pipeline is available under the MIT License.

