
if [ -z "$1" ]; then
    echo "Usage: $0 <bamfile> [bitwidth]"
    echo "bitwidth: 7 or 8 (default: 8)"
    exit 1
fi

# ------------------------------
# Input files and parameters
# ------------------------------
BAM_FILE=$1
BITWIDTH=${2:-8}   # Default to 8 if not provided
echo "Using BITWIDTH = $BITWIDTH"

BED_FILE="methylation_cpg.bed"
METHPOS_FILE="methpos.txt"
LOGDIR="ASCII logs"
mkdir -p "$LOGDIR"  # create folder if it doesn't exist

LOGFILE="$LOGDIR/ASCII Log_$(date +%d%m%y_%H%M%S).log"
echo "Logging output to $LOGFILE"

exec > >(tee -a "$LOGFILE") 2>&1
# ------------------------------
# 0. Check BAM index
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
# 2. Activate conda environment
# ------------------------------
echo "Activating conda environment..."
conda activate modkit_env

# ------------------------------
# 3. Verify modkit
# ------------------------------
echo "Verifying modkit availability..."
modkit --version

# ------------------------------
# 4. Run modkit pileup
# ------------------------------
echo "Running modkit pileup..."
modkit pileup --cpg --mod-thresholds C:0.0 --ref 960nt.fasta "$BAM_FILE" "$BED_FILE"

# ------------------------------
# 5. Filter methylation data
# ------------------------------
echo "Filtering methylation data..."

BED_M_FILE="methylation_M.txt"
awk '$4 == "m"  && $11 != 0 {print $3, $11}' "$BED_FILE" > "$BED_M_FILE"
echo "Saved BED with only M-modified bases to $BED_M_FILE"
#Above is for getting stuff with non zero M methylation, and ignoring STUPIDASS HYDROXYMETHYLATION
awk '$11 > 37 {print $3, $11}' "$BED_FILE" > "$METHPOS_FILE"
FULL_BED_TEXT="full_bed.txt"
cp "$BED_FILE" "$FULL_BED_TEXT"
echo "Saved full BED content to $FULL_BED_TEXT"
# Above is for saving Full BedFile
# ------------------------------
# 6. Run Python script based on BITWIDTH
# ------------------------------
echo "Processing methylation positions in Python..."
echo "Selected BITWIDTH = $BITWIDTH"

if [ "$BITWIDTH" = "8" ]; then
    echo "in 1"
    python3 ./pipe.py "$METHPOS_FILE"

elif [ "$BITWIDTH" = "7" ]; then
    echo "in 2"
    python3 ./pipe_7bit.py "$METHPOS_FILE"
else
    echo "Invalid BITWIDTH: $BITWIDTH. Please choose 7 or 8."
    exit 1
fi
cp "$METHPOS_FILE" "$LOGDIR/methpos_$(date +%d%m%y_%H%M%S).txt"
# ------------------------------
# 7. Deactivate conda environment
# ------------------------------
echo "Deactivating conda environment..."
conda deactivate
echo "Logged output to $LOGFILE"
# ------------------------------
# Optional cleanup
# ------------------------------
# rm "$BED_FILE" "$METHPOS_FILE"
