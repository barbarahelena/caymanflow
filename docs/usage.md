# Caymanflow: Usage

> _Documentation of pipeline parameters is generated automatically from the pipeline schema and can no longer be found in markdown files._

## Introduction

Caymanflow is a bioinformatics pipeline for annotating shotgun metagenomic paired-end reads using Cayman. The pipeline provides a comprehensive workflow that includes:

- **Read Counting**: Tracks reads at multiple stages (raw, post-QC, post-host-removal)
- **Optional Quality Control**: Quality filtering and adapter trimming with fastp (can be skipped with `--skip_qc`)
- **Optional Host Read Removal**: Remove host contamination using Bowtie2 with iGenomes support (can be skipped with `--skip_host_removal`)
- **Database Preparation**: Automatic download from Zenodo, unzipping, decompression, and BWA index creation
- **Direct Functional Annotation**: Cayman for metagenomic read annotation
- **Output Processing**: Automated generation of publication-ready tables (TPM, CPM, QC statistics)

## Running the pipeline

The typical command for running the pipeline is as follows:

```bash
nextflow run barbarahelena/caymanflow --input samplesheet.csv --outdir <OUTDIR> -profile docker
```

This will launch the pipeline with the `docker` configuration profile. See below for more information about profiles.

### Basic usage examples

**Skip quality control:**
```bash
nextflow run barbarahelena/caymanflow \
  --input samplesheet.csv \
  --skip_qc \
  --outdir <OUTDIR> \
  -profile docker
```

**With host removal (human, GRCh38):**
```bash
nextflow run barbarahelena/caymanflow \
  --input samplesheet.csv \
  --genome GRCh38 \
  --outdir <OUTDIR> \
  -profile docker
```

**Complete pipeline with QC and host removal:**
```bash
nextflow run barbarahelena/caymanflow \
  --input samplesheet.csv \
  --genome GRCh38 \
  --cayman_dbname human-gut \
  --outdir <OUTDIR> \
  -profile singularity
```

## Database Options

The pipeline provides flexible options for providing the Cayman database:

### Option 1: Automatic Download (Default)

By default, the pipeline downloads the database from Zenodo based on the `--cayman_dbname` parameter:

```bash
nextflow run barbarahelena/caymanflow \
  --input samplesheet.csv \
  --cayman_dbname human-gut \
  --outdir results \
  -profile docker
```

Available database names:
- `human-gut` (default)
- `pig-gut`
- `dog-gut`
- `cat-gut`
- `mouse-gut`
- `chicken-gut`
- `freshwater`
- `wastewater`
- `marine`
- `human-skin`

The downloaded database and annotations are automatically stored in `db/cayman/` and reused in subsequent runs.

### Option 2: Provide Your Own Database

You can provide a pre-existing database file. The pipeline supports multiple formats:

**Uncompressed FASTA:**
```bash
nextflow run barbarahelena/caymanflow \
  --input samplesheet.csv \
  --cayman_database /path/to/database.fna \
  --cayman_annotations /path/to/annotations.csv \
  --outdir results \
  -profile docker
```

**Gzipped FASTA:**
```bash
nextflow run barbarahelena/caymanflow \
  --input samplesheet.csv \
  --cayman_database /path/to/database.fna.gz \
  --cayman_annotations /path/to/annotations.csv \
  --outdir results \
  -profile docker
```

**Zip archive (containing both database and annotations):**
```bash
nextflow run barbarahelena/caymanflow \
  --input samplesheet.csv \
  --cayman_database /path/to/gene_catalogues.zip \
  --cayman_annotations /path/to/annotations.zip \
  --outdir results \
  -profile docker
```

### Option 3: Provide Pre-computed BWA Index

If you have already created a BWA index for your database, you can provide it to save computation time:

```bash
nextflow run barbarahelena/caymanflow \
  --input samplesheet.csv \
  --cayman_database /path/to/database.fna \
  --cayman_annotations /path/to/annotations.csv \
  --bwa_index /path/to/index/directory \
  --outdir results \
  -profile docker
```

The `--bwa_index` directory should contain files with extensions: `.amb`, `.ann`, `.bwt`, `.pac`, and `.sa`.

Note that the pipeline will create the following files in your working directory:

```bash
work            # Directory containing temporary files required for the run
<OUTDIR>        # Final results (location specified with --outdir)
db/             # Cached database files (if using automatic download)
.nextflow_log   # Log file from nextflow

# Other nextflow hidden files, eg. history of pipeline runs and old logs
```

If you wish to repeatedly use the same parameters for multiple runs, rather than specifying each flag in the command, you can specify these in a params file.

Pipeline settings can be provided in a `yaml` or `json` file via `-params-file <file>`.

> [!WARNING]
> Do not use `-c <file>` to specify parameters as this will result in errors. Custom config files specified with `-c` must only be used for [tuning process resource specifications](https://nf-co.re/docs/usage/configuration#tuning-workflow-resources), other infrastructural tweaks (such as output directories), or module arguments (args).

The above pipeline run specified with a params file in yaml format:

```bash
nextflow run barbarahelena/caymanflow -profile docker -params-file params.yaml
```

with:

```yaml title="params.yaml"
input: './samplesheet.csv'
outdir: './results/'
<...>
```

You can also generate such `YAML`/`JSON` files via [nf-core/launch](https://nf-co.re/launch).

## Samplesheet input

barbarahelena/caymanflow takes paired-end FASTQ files as input. To supply these to the pipeline, you will need to create a samplesheet with information about the samples you would like to analyse. Use this parameter to specify its location.

```bash
--input '[path to samplesheet file]'
```

The input samplesheet has to be a comma-separated file (`.csv`) with 3 columns and a header row as shown in the examples below.

**Required columns:**
- `sample`: Sample name
- `fastq_1`: Path to forward reads FASTQ file (R1)
- `fastq_2`: Path to reverse reads FASTQ file (R2)

### Basic samplesheet:

```csv title="samplesheet.csv"
sample,fastq_1,fastq_2
sample_1,/<path>/<to>/sample_1_R1.fastq.gz,/<path>/<to>/sample_1_R2.fastq.gz
sample_2,/<path>/<to>/sample_2_R1.fastq.gz,/<path>/<to>/sample_2_R2.fastq.gz
```

| Column    | Description                                                                                                                                                                                                           |
| --------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `sample`  | Custom sample name. This will be used to name all output files from the pipeline. Spaces in sample names are automatically converted to underscores (`_`).                                                            |
| `fastq_1` | Path or URL to a gzipped or uncompressed forward reads FASTQ file. Accepted file suffixes are: `.fastq`, `.fq`, or any of these with `.gz`, e.g. `.fastq.gz`.                                                               |
| `fastq_2` | Path or URL to a gzipped or uncompressed reverse reads FASTQ file. Accepted file suffixes are: `.fastq`, `.fq`, or any of these with `.gz`, e.g. `.fastq.gz`.                                                               |

An [example samplesheet](../assets/samplesheet.csv) has been provided with the pipeline.

## Host Read Removal

The pipeline supports optional host read removal using Bowtie2. This step can be skipped with `--skip_host_removal`.

### Using iGenomes References (Recommended)

The easiest way to enable host removal is to use a reference genome from iGenomes:

```bash
nextflow run barbarahelena/caymanflow \
  --input samplesheet.csv \
  --genome GRCh38 \
  --outdir results \
  -profile docker
```

Available genomes include (see `conf/igenomes.config` for the complete list):
- **Human**: `GRCh38`, `GRCh37`, `hg38`, `hg19`
- **Mouse**: `GRCm38`, `GRCm39`, `mm10`, `mm39`
- **Rat**: `Rnor_6.0`
- **Zebrafish**: `GRCz10`, `GRCz11`
- **Dog**: `CanFam3.1`
- **Pig**: `Sscrofa11.1`
- And many more...

### Using Custom Host References

**Option 1: Pre-built Bowtie2 index**

If you already have a Bowtie2 index:

```bash
nextflow run barbarahelena/caymanflow \
  --input samplesheet.csv \
  --host_bowtie2_index /path/to/host_bowtie2_index \
  --outdir results \
  -profile docker
```

The index directory should contain files with the `.bt2` or `.bt2l` extensions.

**Option 2: Host FASTA file**

If you have a host genome FASTA file, the pipeline will build the Bowtie2 index for you:

```bash
nextflow run barbarahelena/caymanflow \
  --input samplesheet.csv \
  --host_fasta /path/to/host_genome.fasta \
  --outdir results \
  -profile docker
```

The built index will be cached in the `db/` directory for future runs.

### Saving Host-Filtered Reads

By default, only host removal statistics are saved. To also save the host-filtered reads:

```bash
nextflow run barbarahelena/caymanflow \
  --input samplesheet.csv \
  --genome GRCh38 \
  --save_host_filtered_reads \
  --outdir results \
  -profile docker
```

### Host Removal Parameters

- `--skip_host_removal`: Skip host read removal step (default: `false`)
- `--genome`: iGenomes reference genome name (e.g., `GRCh38`, `mm10`)
- `--host_bowtie2_index`: Path to pre-built Bowtie2 index directory
- `--host_fasta`: Path to host genome FASTA file (will build index)
- `--save_host_filtered_reads`: Save the host-filtered reads (default: `false`)
- `--igenomes_base`: Base path for iGenomes references (default: `s3://ngi-igenomes/igenomes`)
- `--igenomes_ignore`: Ignore iGenomes and use only custom references (default: `false`)

**Note**: Only one of `--genome`, `--host_bowtie2_index`, or `--host_fasta` should be provided.

## Pipeline workflow

When you run the pipeline, the following steps are performed:

1. **Read Counting (Raw)**: Count reads in raw input FASTQ files
2. **Quality Control (optional)**: If `--skip_qc` is not specified, fastp performs quality filtering and adapter trimming
   - Read counting after QC (if not skipped)
3. **Host Read Removal (optional)**: If `--skip_host_removal` is not specified, Bowtie2 removes host contamination
   - Supports iGenomes references (e.g., `--genome GRCh38`)
   - Or custom host references (pre-built index or FASTA file)
   - Read counting after host removal (if not skipped)
4. **Database Preparation**: 
   - If no database is provided, downloads gene catalogues from Zenodo
   - Unzips and decompresses files as needed
   - Creates BWA index if not provided
5. **Read Annotation**: Cayman aligns reads to the gene catalogue and produces:
   - Alignment statistics (`.aln_stats.txt.gz`)
   - Gene count tables (`.gene_counts.txt.gz`)
6. **Output Processing**: Automated generation of analysis-ready tables:
   - Gene-level TPM (Transcripts Per Million) matrix
   - Family-level CPM (Counts Per Million) matrix
   - Sample quality control and complexity statistics

## Output Files

The pipeline generates the following output structure:

```
results/
├── readcounts/                          # Read count summaries
│   ├── readcounts_raw.csv              # Read counts from raw input files
│   ├── readcounts_after_qc.csv         # Read counts after QC (if not skipped)
│   └── readcounts_after_host_removal.csv  # Read counts after host removal (if not skipped)
├── qc/
│   └── fastp/                           # Quality control reports (if not skipped)
│       ├── *.json
│       └── *.html
├── host_removal/                        # Host removal statistics (if not skipped)
│   ├── *.bowtie2.log                   # Bowtie2 alignment logs
│   ├── *.stats                         # Alignment statistics
│   └── reads/                          # Host-filtered reads (if --save_host_filtered_reads)
├── cayman/                              # Cayman annotation results
│   ├── compressed/
│   │   ├── *.aln_stats.txt.gz          # Alignment statistics (compressed)
│   │   └── *.gene_counts.txt.gz        # Gene count tables (compressed)
│   ├── uncompressed/
│   │   ├── *.aln_stats.txt             # Alignment statistics (decompressed)
│   │   └── *.gene_counts.txt           # Gene count tables (decompressed)
│   ├── processed/                       # Per-sample processed files
│   │   ├── *_genes_tpm.tsv             # Gene-level TPM per sample
│   │   ├── *_families_cpm.tsv          # Family-level CPM per sample
│   │   └── *_sample_stats.tsv          # Sample statistics
│   └── tables/                          # Merged tables across all samples
│       ├── families_cpm_table.tsv      # Family-level CPM across all samples
│       └── sample_statistics.tsv       # Sample QC statistics
└── pipeline_info/                       # Pipeline execution information
    ├── execution_report.html
    ├── execution_timeline.html
    └── pipeline_dag.html
```

### Read Count Files

The pipeline generates separate CSV files tracking read counts at each processing stage:

- **`readcounts_raw.csv`**: Read counts from the original input FASTQ files
- **`readcounts_after_qc.csv`**: Read counts after fastp quality control (only if `--skip_qc` is not used)
- **`readcounts_after_host_removal.csv`**: Read counts after Bowtie2 host filtering (only if `--skip_host_removal` is not used)

Each CSV file has the format:
```csv
SampleID,ReadCount
sample1,1000000
sample2,2000000
```

These files allow you to track how many reads are retained at each step of the pipeline.

### Cayman Output Tables

The pipeline processes Cayman outputs into publication-ready tables:

#### 1. Per-sample Gene TPM Files (`*_genes_tpm.tsv`)

Gene-level expression in TPM (Transcripts Per Million) for each sample:
- Contains TPM values for all annotated genes in that sample
- UNKNOWN genes are filtered out
- Uses combined counts (multi-mapped reads are distributed)
- Format: Two columns (gene_name, tpm)
- Located in `cayman/processed/`

#### 2. Family-level CPM Table (`families_cpm_table.tsv`)

Gene family-level expression in CPM (Counts Per Million) merged across all samples:
- Aggregates genes by family annotation
- CPM normalization for cross-sample comparison
- Families extracted from annotation file via inner join
- Format: Families in rows, samples in columns
- Located in `cayman/tables/`

#### 3. Sample Statistics Table (`sample_statistics.tsv`)

Quality control and complexity metrics per sample:
- `total_reads`: Total input reads to Cayman
- `passed_reads`: Reads that aligned to the gene catalogue
- `filter_efficiency`: Proportion of reads that passed (passed/total)
- `richness`: Number of unique genes detected
- `complexity`: Unique genes per passed read (richness/passed)
- `pct_cazy_reads`: Percentage of reads mapping to CAZy genes
- Located in `cayman/tables/`

## Notes on the Cayman Tool

[Cayman](https://github.com/zellerlab/cayman) is a tool for direct functional annotation of metagenomic reads without assembly. It uses BWA for alignment and provides gene-level abundance estimates.

Key features:
- Direct read annotation (no assembly required)
- Multiple gene catalogues available (gut microbiomes, environmental, etc.)
- Combined count strategy for handling multi-mapped reads
- Integration with functional annotation databases (CAZy, KEGG, etc.)

## Database Options and Reference Files

### Cayman Database

Cayman requires a gene catalogue database for annotation. The pipeline supports multiple ways to provide this:

### Automatic Download (Recommended)

By default, the pipeline will download the appropriate database from Zenodo based on the `--cayman_dbname` parameter. The downloaded files are cached in the `db/cayman/` directory for reuse.

### Pre-downloaded Database

If you have a pre-downloaded database file, you can provide it directly:

```bash
--cayman_database /path/to/database.fna.gz \
--cayman_annotations /path/to/annotations.csv
```

The pipeline supports:
- Uncompressed FASTA (`.fna`)
- Gzipped FASTA (`.fna.gz`)
- Zip archives (`.zip`)

### Pre-computed BWA Index

To save computation time, you can provide a pre-built BWA index:

```bash
--cayman_database /path/to/database.fna.gz \
--cayman_annotations /path/to/annotations.csv \
--bwa_index /path/to/index/directory
```

The index directory should contain files with extensions: `.amb`, `.ann`, `.bwt`, `.pac`, and `.sa`.

For more details on database options, see the [Database Options](#database-options) section above.

## Updating the pipeline

When you run the below command, Nextflow automatically pulls the pipeline code from GitHub and stores it as a cached version. When running the pipeline after this, it will always use the cached version if available - even if the pipeline has been updated since. To make sure that you're running the latest version of the pipeline, make sure that you regularly update the cached version of the pipeline:

```bash
nextflow pull barbarahelena/caymanflow
```

## Reproducibility

It is a good idea to specify the pipeline version when running the pipeline on your data. This ensures that a specific version of the pipeline code and software are used when you run your pipeline. If you keep using the same tag, you'll be running the same version of the pipeline, even if there have been changes to the code since.

First, go to the [barbarahelena/caymanflow releases page](https://github.com/barbarahelena/caymanflow/releases) and find the latest pipeline version - numeric only (eg. `1.0.0`). Then specify this when running the pipeline with `-r` (one hyphen) - eg. `-r 1.0.0`. Of course, you can switch to another version by changing the number after the `-r` flag.

This version number will be logged in reports when you run the pipeline, so that you'll know what you used when you look back in the future.

To further assist in reproducibility, you can use share and reuse [parameter files](#running-the-pipeline) to repeat pipeline runs with the same settings without having to write out a command with every single parameter.

> [!TIP]
> If you wish to share such profile (such as upload as supplementary material for academic publications), make sure to NOT include cluster specific paths to files, nor institutional specific profiles.

## Core Nextflow arguments

> [!NOTE]
> These options are part of Nextflow and use a _single_ hyphen (pipeline parameters use a double-hyphen)

### `-profile`

Use this parameter to choose a configuration profile. Profiles can give configuration presets for different compute environments.

Several generic profiles are bundled with the pipeline which instruct the pipeline to use software packaged using different methods (Docker, Singularity, Podman, Shifter, Charliecloud, Apptainer, Conda) - see below.

> [!IMPORTANT]
> We highly recommend the use of Docker or Singularity containers for full pipeline reproducibility, however when this is not possible, Conda is also supported.

The pipeline also dynamically loads configurations from [https://github.com/nf-core/configs](https://github.com/nf-core/configs) when it runs, making multiple config profiles for various institutional clusters available at run time. For more information and to check if your system is supported, please see the [nf-core/configs documentation](https://github.com/nf-core/configs#documentation).

Note that multiple profiles can be loaded, for example: `-profile test,docker` - the order of arguments is important!
They are loaded in sequence, so later profiles can overwrite earlier profiles.

If `-profile` is not specified, the pipeline will run locally and expect all software to be installed and available on the `PATH`. This is _not_ recommended, since it can lead to different results on different machines dependent on the computer environment.

- `test`
  - A profile with a complete configuration for automated testing
  - Includes links to test data so needs no other parameters
- `docker`
  - A generic configuration profile to be used with [Docker](https://docker.com/)
- `singularity`
  - A generic configuration profile to be used with [Singularity](https://sylabs.io/docs/)
- `podman`
  - A generic configuration profile to be used with [Podman](https://podman.io/)
- `shifter`
  - A generic configuration profile to be used with [Shifter](https://nersc.gitlab.io/development/shifter/how-to-use/)
- `charliecloud`
  - A generic configuration profile to be used with [Charliecloud](https://hpc.github.io/charliecloud/)
- `apptainer`
  - A generic configuration profile to be used with [Apptainer](https://apptainer.org/)
- `wave`
  - A generic configuration profile to enable [Wave](https://seqera.io/wave/) containers. Use together with one of the above (requires Nextflow ` 24.03.0-edge` or later).
- `conda`
  - A generic configuration profile to be used with [Conda](https://conda.io/docs/). Please only use Conda as a last resort i.e. when it's not possible to run the pipeline with Docker, Singularity, Podman, Shifter, Charliecloud, or Apptainer.

### `-resume`

Specify this when restarting a pipeline. Nextflow will use cached results from any pipeline steps where the inputs are the same, continuing from where it got to previously. For input to be considered the same, not only the names must be identical but the files' contents as well. For more info about this parameter, see [this blog post](https://www.nextflow.io/blog/2019/demystifying-nextflow-resume.html).

You can also supply a run name to resume a specific run: `-resume [run-name]`. Use the `nextflow log` command to show previous run names.

### `-c`

Specify the path to a specific config file (this is a core Nextflow command). See the [nf-core website documentation](https://nf-co.re/usage/configuration) for more information.

## Custom configuration

### Resource requests

Whilst the default requirements set within the pipeline will hopefully work for most people and with most input data, you may find that you want to customise the compute resources that the pipeline requests. Each step in the pipeline has a default set of requirements for number of CPUs, memory and time. For most of the pipeline steps, if the job exits with any of the error codes specified [here](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/conf/base.config#L18) it will automatically be resubmitted with higher resources request (2 x original, then 3 x original). If it still fails after the third attempt then the pipeline execution is stopped.

To change the resource requests, please see the [max resources](https://nf-co.re/docs/usage/configuration#max-resources) and [tuning workflow resources](https://nf-co.re/docs/usage/configuration#tuning-workflow-resources) section of the nf-core website.

### Custom Containers

In some cases, you may wish to change the container or conda environment used by a pipeline steps for a particular tool. By default, nf-core pipelines use containers and software from the [biocontainers](https://biocontainers.pro/) or [bioconda](https://bioconda.github.io/) projects. However, in some cases the pipeline specified version maybe out of date.

To use a different container from the default container or conda environment specified in a pipeline, please see the [updating tool versions](https://nf-co.re/docs/usage/configuration#updating-tool-versions) section of the nf-core website.

### Custom Tool Arguments

A pipeline might not always support every possible argument or option of a particular tool used in pipeline. Fortunately, nf-core pipelines provide some freedom to users to insert additional parameters that the pipeline does not include by default.

To learn how to provide additional arguments to a particular tool of the pipeline, please see the [customising tool arguments](https://nf-co.re/docs/usage/configuration#customising-tool-arguments) section of the nf-core website.

### nf-core/configs

In most cases, you will only need to create a custom config as a one-off but if you and others within your organisation are likely to be running nf-core pipelines regularly and need to use the same settings regularly it may be a good idea to request that your custom config file is uploaded to the `nf-core/configs` git repository. Before you do this please can you test that the config file works with your pipeline of choice using the `-c` parameter. You can then create a pull request to the `nf-core/configs` repository with the addition of your config file, associated documentation file (see examples in [`nf-core/configs/docs`](https://github.com/nf-core/configs/tree/master/docs)), and amending [`nfcore_custom.config`](https://github.com/nf-core/configs/blob/master/nfcore_custom.config) to include your custom profile.

See the main [Nextflow documentation](https://www.nextflow.io/docs/latest/config.html) for more information about creating your own configuration files.

If you have any questions or issues please send us a message on [Slack](https://nf-co.re/join/slack) on the [`#configs` channel](https://nfcore.slack.com/channels/configs).

## Running in the background

Nextflow handles job submissions and supervises the running jobs. The Nextflow process must run until the pipeline is finished.

The Nextflow `-bg` flag launches Nextflow in the background, detached from your terminal so that the workflow does not stop if you log out of your session. The logs are saved to a file.

Alternatively, you can use `screen` / `tmux` or similar tool to create a detached session which you can log back into at a later time.
Some HPC setups also allow you to run nextflow within a cluster job submitted your job scheduler (from where it submits more jobs).

## Nextflow memory requirements

In some cases, the Nextflow Java virtual machines can start to request a large amount of memory.
We recommend adding the following line to your environment to limit this (typically in `~/.bashrc` or `~./bash_profile`):

```bash
NXF_OPTS='-Xms1g -Xmx4g'
```
