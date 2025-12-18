#Get inputs from the user
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <bamfile> <reference_fasta> [bitwidth]"
    echo "bitwidth: 7 or 8 (default: 8)"
    exit 1
fi

BAM_FILE=$1
REF_FILE=$2
BITWIDTH=${3:-8}   # Default to 8 if not provided

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
# Initialising intremediate and output files
# ------------------------------
BED_FILE="methylation_cpg.bed"
METHPOS_FILE="methpos.txt"
LOGDIR="ASCII logs"
mkdir -p "$LOGDIR"
ERROR_LOGDIR="ErrorStats logs"
mkdir -p "$ERROR_LOGDIR"
LOGFILE="$LOGDIR/ASCII_Log_$(date +%d%m%y_%H%M%S).log"
echo "Logging output to $LOGFILE"
exec > >(tee -a "$LOGFILE") 2>&1
# INTERMEDIATE_DIR="intermediate_files"
# mkdir -p "$INTERMEDIATE_DIR"

# ------------------------------
# 0. Check BAM index (https://github.com/samtools/samtools)
# ------------------------------
if [ ! -f "${BAM_FILE}.bai" ]; then
    echo "BAM index not found. Creating index with samtools..."
    samtools index "$BAM_FILE"
fi

# ------------------------------
# 1. Initialize conda
# ------------------------------
if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/miniconda3/etc/profile.d/conda.sh"
fi

# ------------------------------
# 2. Create and activate environment
# ------------------------------
ENV_NAME="modkit_env"

if ! conda env list | awk '{print $1}' | grep -qx "$ENV_NAME"; then
    echo "Conda environment '$ENV_NAME' not found. Creating it."

    conda create -y -n "$ENV_NAME" python=3.10
    conda activate "$ENV_NAME"

    echo "Installing required packages..."
    conda install -y -c bioconda samtools modkit
    pip install pysam numpy pandas

    echo "Conda environment '$ENV_NAME' created successfully."
else
    echo "Conda environment '$ENV_NAME' already exists."
fi

echo "Activating conda environment"
conda activate modkit_env

# ------------------------------
# 3. Verify Correct Version of modkit
# ------------------------------
REQUIRED_MODKIT_VERSION="0.5.0"

echo "Checking modkit version..."

if command -v modkit >/dev/null 2>&1; then
    INSTALLED_MODKIT_VERSION=$(modkit --version | awk '{print $NF}')
    echo "Found modkit version: $INSTALLED_MODKIT_VERSION"

    if [ "$INSTALLED_MODKIT_VERSION" != "$REQUIRED_MODKIT_VERSION" ]; then
        echo "modkit version mismatch. Required: $REQUIRED_MODKIT_VERSION"
        echo "Installing modkit==$REQUIRED_MODKIT_VERSION..."
        conda install -y -c bioconda modkit="$REQUIRED_MODKIT_VERSION"
    else
        echo "modkit version is correct."
    fi
else
    echo "modkit not found. Installing modkit==$REQUIRED_MODKIT_VERSION..."
    conda install -y -c bioconda modkit="$REQUIRED_MODKIT_VERSION"
fi

# Final verification
echo "Using modkit version:"
echo "Verifying modkit..."
modkit --version

# ------------------------------
# 4. Run modkit to get full .bed file
# ------------------------------
echo "Running modkit pileup..."
modkit pileup --cpg --mod-thresholds C:0.0 --ref "$REF_FILE" "$BAM_FILE" "$BED_FILE"

# ------------------------------
# 5a. Filtering methylation data to get only M reads, ignoring Hydroxymethylation tags
# ------------------------------
echo "Filtering methylation data..."

# BED_M_FILE="methylation_M.txt"
BED_M_FILE="methylation_M.txt"

awk '$4 == "m" && $11 != 0 {print $3, $11}' "$BED_FILE" > "$BED_M_FILE"
echo "Saved BED with only M-modified bases to $BED_M_FILE"
# ------------------------------
# 5b. Filtering using Dynamic Threshold determined from Python script called get_stats.py
# ------------------------------
echo "Computing dynamic mean and median thresholds"
read MEAN MEDIAN <<< "$(python3 ./B2A/get_stats.py)"
echo "Mean = $MEAN"
echo "Median = $MEDIAN"

awk -v threshold="$MEAN" '$11 > threshold {print $3, $11}' "$BED_FILE" > "$METHPOS_FILE"

FULL_BED_TEXT="full_bed.txt"
cp "$BED_FILE" "$FULL_BED_TEXT"

# ------------------------------
# 6. Run Python script to convert Methylation data --> Binary --> ASCII (meth_analysis.py)
# ------------------------------
echo "Processing methylation positions in Python..."
echo "Selected BITWIDTH = $BITWIDTH"

python3 ./B2A/meth_analysis.py "$METHPOS_FILE" "$BITWIDTH"

cp "$METHPOS_FILE" "$LOGDIR/methpos_$(date +%d%m%y_%H%M%S).txt"

# ------------------------------
# 7. Deactivate conda environment
# ------------------------------
echo "Deactivating conda environment..."
conda deactivate

echo "Logged output to $LOGFILE"
# ------------------------------
# 8. Error statistics from error_stats.py
# ------------------------------
echo "Do you want to enter test mode to check for errors? Enter Y/N"
read answer

if [[ "$answer" == "Y" || "$answer" == "y" ]]; then
    echo "Calculating Error stats"
    ERROR_LOGFILE="$ERROR_LOGDIR/ErrorStats_$(date +%d%m%y_%H%M%S).log"
    echo "Logging error statistics to $ERROR_LOGFILE"

    python3 ./B2A/error_stats.py "$METHPOS_FILE" "$BITWIDTH" \
    | tee -a "$ERROR_LOGFILE"

else
    echo "Skipping error stats."
fi
