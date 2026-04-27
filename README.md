# B2A
This repository contains the script to convert .BAM files to ASCII values.

## Required packages
- [Modkit](https://github.com/nanoporetech/modkit/blob/master/README.md)
- [Samtools](https://anaconda.org/bioconda/samtools)
- [Conda](https://anaconda.org/anaconda/conda)

## Usage
The pipeline accepts either a single BAM file or a folder of BAM files:

```bash
./run_pipeline.sh [options] <bam_file_or_folder> <reference_fasta> [bitwidth]
```

- `bam_file_or_folder`: BAM file path or folder containing one or more `.bam` files
- `reference_fasta`: reference sequence path (`.fasta` or `.fa`)
- `bitwidth`: `7` or `8` (defaults to `8`)

## Interactive Menu (No command memorization)
If you prefer a guided interface, use the menu script:

```bash
bash ./pipeline_menu.sh
```

Menu features:
- Run one BAM or a full folder of BAMs
- Choose word mode (`--word`, `--word-map`, or skip)
- Toggle artifact saving (`--save-bed-error` + `--save-dir`)
- Create/edit `words.map` interactively

## CLI options
- `--word <text>`: desired payload word used for per-barcode error stats
- `--word-map <path>`: mapping file with one entry per barcode/BAM: `<barcode_or_bamname> <intended_word>`
- `--save-bed-error`: save BED/error artifacts in per-barcode output folders
- `--save-bed-error-files`: alias for `--save-bed-error`
- `--save-dir <path>`: root folder for saved BED/error outputs (default: `Saved_BED_Error`)
- `-h`, `--help`: print help

## WSL path support
- On WSL, Windows-style paths like `C:\...` and `C:/...` are normalized automatically to `/mnt/c/...`.
- This avoids hardcoding username-specific paths such as `/mnt/c/Users/<name>/...`.
- The same normalization is applied to input BAM/folder paths, reference FASTA path, and `--save-dir`.

## Multi-barcode folder input
- If input is a folder, the pipeline recursively finds all `.bam` files and processes each one.
- Per-barcode labeling:
    - If BAM parent folder matches `barcode*`, that folder name is used (for example `barcode01`).
    - Otherwise, the BAM filename (without extension) is used.
- Each BAM gets its own methpos log entry and optional error report.

## Test Command Line:
Test files are given in this repository and will get cloned. Use the following command line for testing if the pipeline works. The output should read "EpiB"
```
./run_pipeline.sh input.bam reference.fasta 8

```
Commmon command line format is as follows:
```
./run_pipeline.sh <input file path or folder> <reference fasta path> <number of bits per byte>

```
Example with BED/error export per barcode:
```bash
./run_pipeline.sh --word EpiB --save-bed-error --save-dir ./artifact_exports ./demux_bams ./reference.fasta 8
```

Example with barcode-specific intended words:
```bash
cat > words.map << 'EOF'
barcode01 EpiB
barcode02 HELLO
barcode03 DATA
EOF

./run_pipeline.sh --word-map ./words.map --save-bed-error ./demux_bams ./reference.fasta 8
```

Example with Windows paths from WSL:
```bash
./run_pipeline.sh "C:\\data\\demux" "C:\\data\\reference.fasta" 8
```

## Outputs:
- `ASCII_logs/ASCII_Log_ddmmyy_hhmmss.log`: full terminal log for the run.
- `ASCII_logs/<barcode>_methpos_ddmmyy_hhmmss.txt`: per-barcode methylation positions above threshold.
- `ErrorStats_logs/ErrorStats_<barcode>_ddmmyy_hhmmss.txt`: per-barcode error stats when `--word` is set.

When `--save-bed-error` is enabled:
- `<save-dir>/run_ddmmyy_hhmmss/<barcode_or_barcode_bam>/methylation_cpg.bed`
- `<save-dir>/run_ddmmyy_hhmmss/<barcode_or_barcode_bam>/methylation_M.txt`
- `<save-dir>/run_ddmmyy_hhmmss/<barcode_or_barcode_bam>/full_bed.txt`
- `<save-dir>/run_ddmmyy_hhmmss/<barcode_or_barcode_bam>/ErrorStats_<barcode_or_barcode_bam>_ddmmyy_hhmmss.txt` (if `--word` or `--word-map` is set)

This run-scoped folder layout prevents accidental overwrite across separate pipeline runs.



