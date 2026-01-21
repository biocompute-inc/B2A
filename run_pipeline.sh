#!/usr/bin/env bash
set -euo pipefail

# ------------------------------
# Inputs
# ------------------------------
if [ -z "${1:-}" ] || [ -z "${2:-}" ]; then
    echo "Usage: $0 <bamfile> <reference_fasta> [bitwidth]"
    echo "bitwidth: 7 or 8 (default: 8)"
    exit 1
fi

BAM_FILE=$1
REF_FILE=$2
BITWIDTH=${3:-8}

echo "Using BITWIDTH = $BITWIDTH"
echo "Using reference FASTA = $REF_FILE"

# ------------------------------
# Check reference file exists
# ------------------------------
if [ ! -f "$REF_FILE" ]; then
    echo "ERROR: Reference FASTA file '$REF_FILE' not found."
    exit 1
fi

# ------------------------------
# Check environment sanity
# ------------------------------
echo "Checking environment..."

if ! command -v modkit >/dev/null 2>&1; then
    echo "ERROR: modkit not found in PATH. Activate modkit_env before running."
    exit 1
fi

if ! command -v samtools >/dev/null 2>&1; then
    echo "ERROR: samtools not found in PATH. Activate modkit_env before running."
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 not found in PATH. Activate modkit_env before running."
    exit 1
fi

echo "Environment looks good."
echo "modkit: $(which modkit)"
echo "samtools: $(which samtools)"
echo "python: $(which python3)"

# ------------------------------
# Logging
# ------------------------------
LOGDIR="ASCII_logs"
mkdir -p "$LOGDIR"
ERROR_LOGDIR="ErrorStats_logs"
mkdir -p "$ERROR_LOGDIR"

LOGFILE="$LOGDIR/ASCII_Log_$(date +%d%m%y_%H%M%S).log"
echo "Logging output to $LOGFILE"

exec > >(tee -a "$LOGFILE") 2>&1

# ------------------------------
# Intermediate/output files
# ------------------------------
BED_FILE="methylation_cpg.bed"
METHPOS_FILE="methpos.txt"

# ------------------------------
# 0. Check BAM index
# ------------------------------
if [ ! -f "${BAM_FILE}.bai" ]; then
    echo "BAM index not found. Creating index with samtools..."
    samtools index "$BAM_FILE"
fi

# ------------------------------
# 1. Verify modkit version
# ------------------------------
REQUIRED_MODKIT_VERSION="0.5.0"

echo "Checking modkit version..."
INSTALLED_MODKIT_VERSION=$(modkit --version | awk '{print $NF}')
echo "Found modkit version: $INSTALLED_MODKIT_VERSION"

if [ "$INSTALLED_MODKIT_VERSION" != "$REQUIRED_MODKIT_VERSION" ]; then
    echo "ERROR: modkit version mismatch."
    echo "Required: $REQUIRED_MODKIT_VERSION"
    echo "Installed: $INSTALLED_MODKIT_VERSION"
    echo "Fix by activating correct environment or reinstalling modkit."
    exit 1
fi

echo "modkit version OK."

# ------------------------------
# 2. Run modkit pileup
# ------------------------------
echo "Running modkit pileup..."
modkit pileup --cpg --mod-thresholds C:0.0 --ref "$REF_FILE" "$BAM_FILE" "$BED_FILE"

# ------------------------------
# 3. Filter methylation data (M only)
# ------------------------------
echo "Filtering methylation data..."

BED_M_FILE="methylation_M.txt"
awk '$4 == "m" && $11 != 0 {print $3, $11}' "$BED_FILE" > "$BED_M_FILE"

echo "Saved BED with only M-modified bases to $BED_M_FILE"

# ------------------------------
# 4. Dynamic threshold from Python
# ------------------------------
echo "Computing dynamic mean and median thresholds..."

read MEAN MEDIAN <<< "$(python3 ./get_stats.py)"

echo "Mean = $MEAN"
echo "Median = $MEDIAN"

awk -v threshold="$MEAN" '$11 > threshold {print $3, $11}' "$BED_FILE" > "$METHPOS_FILE"

FULL_BED_TEXT="full_bed.txt"
cp "$BED_FILE" "$FULL_BED_TEXT"

# ------------------------------
# 5. Convert methylation → binary → ASCII
# ------------------------------
echo "Processing methylation positions in Python..."
echo "Selected BITWIDTH = $BITWIDTH"

python3 ./meth_analysis.py "$METHPOS_FILE" "$BITWIDTH"

cp "$METHPOS_FILE" "$LOGDIR/methpos_$(date +%d%m%y_%H%M%S).txt"

# ------------------------------
# Done
# ------------------------------
echo "Pipeline completed successfully."
echo "Logged output to $LOGFILE"
