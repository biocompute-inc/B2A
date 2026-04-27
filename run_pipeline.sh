#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 [options] <bam_file_or_folder> <reference_fasta> [bitwidth]"
    echo
    echo "Options:"
    echo "  --word <text>              Word used to compute per-barcode error stats"
    echo "  --word-map <path>          Mapping file: <barcode_or_bamname> <intended_word>"
    echo "  --save-bed-error           Save BED/error artifacts to per-barcode folders"
    echo "  --save-bed-error-files     Alias for --save-bed-error"
    echo "  --save-dir <path>          Root folder for saved BED/error files (default: Saved_BED_Error)"
    echo "  -h, --help                 Show this help"
    echo
    echo "bitwidth: 7 or 8 (default: 8)"
}

normalize_input_path() {
    local input_path="$1"

    if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
        if [[ "$input_path" =~ ^[A-Za-z]:\\.* ]]; then
            local drive rest
            drive="$(printf '%s' "${input_path:0:1}" | tr '[:upper:]' '[:lower:]')"
            rest="${input_path:2}"
            rest="${rest//\\//}"
            printf '/mnt/%s/%s\n' "$drive" "$rest"
            return
        fi

        if [[ "$input_path" =~ ^[A-Za-z]:/.* ]]; then
            local drive rest
            drive="$(printf '%s' "${input_path:0:1}" | tr '[:upper:]' '[:lower:]')"
            rest="${input_path:3}"
            printf '/mnt/%s/%s\n' "$drive" "$rest"
            return
        fi
    fi

    printf '%s\n' "$input_path"
}

derive_barcode_name() {
    local bam_path="$1"
    local parent_dir
    local bam_basename

    parent_dir="$(basename "$(dirname "$bam_path")")"
    bam_basename="$(basename "$bam_path" .bam)"

    if [[ "$parent_dir" =~ ^barcode[0-9A-Za-z._-]+$ ]]; then
        printf '%s\n' "$parent_dir"
    else
        printf '%s\n' "$bam_basename"
    fi
}

sanitize_name() {
    local raw_name="$1"
    printf '%s\n' "$raw_name" | sed 's/[^A-Za-z0-9._-]/_/g'
}

declare -A WORD_MAP=()

load_word_map() {
    local map_file="$1"

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Trim leading/trailing whitespace.
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        if [[ -z "$line" || "${line:0:1}" == "#" ]]; then
            continue
        fi

        local key="${line%%[[:space:]]*}"
        local value="${line#"$key"}"
        value="${value#"${value%%[![:space:]]*}"}"

        if [[ -z "$key" || -z "$value" ]]; then
            echo "ERROR: Invalid word-map line '$line'. Expected: <barcode_or_bamname> <intended_word>"
            exit 1
        fi

        WORD_MAP["$key"]="$value"
    done < "$map_file"

    if [[ "${#WORD_MAP[@]}" -eq 0 ]]; then
        echo "ERROR: Word map file '$map_file' has no valid entries."
        exit 1
    fi
}

resolve_word_for_bam() {
    local barcode_name="$1"
    local safe_barcode_name="$2"
    local bam_path="$3"
    local bam_stem

    bam_stem="$(basename "$bam_path" .bam)"

    if [[ -n "${WORD_MAP[$barcode_name]+x}" ]]; then
        printf '%s\n' "${WORD_MAP[$barcode_name]}"
        return
    fi

    if [[ -n "${WORD_MAP[$safe_barcode_name]+x}" ]]; then
        printf '%s\n' "${WORD_MAP[$safe_barcode_name]}"
        return
    fi

    if [[ -n "${WORD_MAP[$bam_stem]+x}" ]]; then
        printf '%s\n' "${WORD_MAP[$bam_stem]}"
        return
    fi

    printf '\n'
}

SAVE_BED_ERROR=false
SAVE_ROOT="Saved_BED_Error"
TARGET_WORD=""
WORD_MAP_FILE=""
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --word)
            if [[ -z "${2:-}" ]]; then
                echo "ERROR: --word requires a value."
                exit 1
            fi
            TARGET_WORD="$2"
            shift 2
            ;;
        --word-map)
            if [[ -z "${2:-}" ]]; then
                echo "ERROR: --word-map requires a value."
                exit 1
            fi
            WORD_MAP_FILE="$2"
            shift 2
            ;;
        --save-bed-error|--save-bed-error-files)
            SAVE_BED_ERROR=true
            shift
            ;;
        --save-dir)
            if [[ -z "${2:-}" ]]; then
                echo "ERROR: --save-dir requires a value."
                exit 1
            fi
            SAVE_ROOT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            while [[ $# -gt 0 ]]; do
                POSITIONAL_ARGS+=("$1")
                shift
            done
            ;;
        -*)
            echo "ERROR: Unknown option '$1'"
            usage
            exit 1
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

set -- "${POSITIONAL_ARGS[@]}"

if [[ $# -lt 2 || $# -gt 3 ]]; then
    usage
    exit 1
fi

INPUT_PATH_RAW="$1"
REF_FILE_RAW="$2"
BITWIDTH="${3:-8}"

if [[ "$BITWIDTH" != "7" && "$BITWIDTH" != "8" ]]; then
    echo "ERROR: bitwidth must be 7 or 8"
    exit 1
fi

INPUT_PATH="$(normalize_input_path "$INPUT_PATH_RAW")"
REF_FILE="$(normalize_input_path "$REF_FILE_RAW")"
SAVE_ROOT="$(normalize_input_path "$SAVE_ROOT")"

if [[ -n "$WORD_MAP_FILE" ]]; then
    WORD_MAP_FILE="$(normalize_input_path "$WORD_MAP_FILE")"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Using BITWIDTH = $BITWIDTH"
echo "Using input path = $INPUT_PATH"
echo "Using reference FASTA = $REF_FILE"

# ------------------------------
# Check reference file exists
# ------------------------------
if [ ! -f "$REF_FILE" ]; then
    echo "ERROR: Reference FASTA file '$REF_FILE' not found."
    exit 1
fi

if [[ ! -f "$INPUT_PATH" && ! -d "$INPUT_PATH" ]]; then
    echo "ERROR: Input '$INPUT_PATH' is neither a BAM file nor a folder."
    exit 1
fi

if [[ -n "$WORD_MAP_FILE" && ! -f "$WORD_MAP_FILE" ]]; then
    echo "ERROR: Word map file '$WORD_MAP_FILE' not found."
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

RUN_STAMP="$(date +%d%m%y_%H%M%S)"
SAVE_RUN_DIR=""

if [[ "$SAVE_BED_ERROR" == "true" ]]; then
    SAVE_RUN_DIR="$SAVE_ROOT/run_${RUN_STAMP}"
    mkdir -p "$SAVE_RUN_DIR"
fi

LOGFILE="$LOGDIR/ASCII_Log_${RUN_STAMP}.log"
echo "Logging output to $LOGFILE"

exec > >(tee -a "$LOGFILE") 2>&1

if [[ -n "$WORD_MAP_FILE" ]]; then
    load_word_map "$WORD_MAP_FILE"
    echo "Loaded ${#WORD_MAP[@]} intended-word entries from $WORD_MAP_FILE"
fi

declare -a BAM_FILES=()

if [[ -f "$INPUT_PATH" ]]; then
    BAM_FILES+=("$INPUT_PATH")
else
    while IFS= read -r -d '' bam_path; do
        BAM_FILES+=("$bam_path")
    done < <(find "$INPUT_PATH" -type f -name "*.bam" -print0 | sort -z)
fi

if [[ "${#BAM_FILES[@]}" -eq 0 ]]; then
    echo "ERROR: No BAM files found in '$INPUT_PATH'."
    exit 1
fi

echo "Found ${#BAM_FILES[@]} BAM file(s) to process."

if [[ -z "$TARGET_WORD" && -z "$WORD_MAP_FILE" && -t 0 ]]; then
    read -r -p "Enter desired word for error stats (leave blank to skip): " TARGET_WORD
fi

CURRENT_WORKDIR=""
cleanup() {
    if [[ -n "$CURRENT_WORKDIR" && -d "$CURRENT_WORKDIR" ]]; then
        rm -rf "$CURRENT_WORKDIR"
    fi
}
trap cleanup EXIT

# ------------------------------
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

for BAM_FILE in "${BAM_FILES[@]}"; do
    BARCODE_NAME="$(derive_barcode_name "$BAM_FILE")"
    SAFE_BARCODE_NAME="$(sanitize_name "$BARCODE_NAME")"
    SAFE_BAM_STEM="$(sanitize_name "$(basename "$BAM_FILE" .bam)")"
    OUTPUT_ID="$SAFE_BARCODE_NAME"

    if [[ "$SAFE_BAM_STEM" != "$SAFE_BARCODE_NAME" ]]; then
        OUTPUT_ID="${SAFE_BARCODE_NAME}_${SAFE_BAM_STEM}"
    fi

    BARCODE_WORD="$TARGET_WORD"
    if [[ -n "$WORD_MAP_FILE" ]]; then
        MAP_WORD="$(resolve_word_for_bam "$BARCODE_NAME" "$SAFE_BARCODE_NAME" "$BAM_FILE")"

        if [[ -n "$MAP_WORD" ]]; then
            BARCODE_WORD="$MAP_WORD"
        elif [[ -n "$TARGET_WORD" ]]; then
            echo "Warning: no word-map entry for '$BARCODE_NAME' (${BAM_FILE}); using --word fallback."
        else
            echo "ERROR: No intended word found for '$BARCODE_NAME' (${BAM_FILE}) in '$WORD_MAP_FILE'."
            exit 1
        fi
    fi

    echo
    echo "========================================"
    echo "Processing BAM: $BAM_FILE"
    echo "Barcode label: $BARCODE_NAME"
    if [[ -n "$BARCODE_WORD" ]]; then
        echo "Intended word: $BARCODE_WORD"
    fi

    # ------------------------------
    # 0. Check BAM index
    # ------------------------------
    if [[ ! -f "${BAM_FILE}.bai" && ! -f "${BAM_FILE%.bam}.bai" ]]; then
        echo "BAM index not found. Creating index with samtools..."
        samtools index "$BAM_FILE"
    fi

    CURRENT_WORKDIR="$(mktemp -d)"
    BED_FILE="$CURRENT_WORKDIR/methylation_cpg.bed"
    BED_M_FILE="$CURRENT_WORKDIR/methylation_M.txt"
    METHPOS_FILE="$CURRENT_WORKDIR/methpos.txt"
    FULL_BED_TEXT="$CURRENT_WORKDIR/full_bed.txt"

    # ------------------------------
    # 2. Run modkit pileup
    # ------------------------------
    echo "Running modkit pileup..."
    modkit pileup --cpg --mod-thresholds C:0.0 --ref "$REF_FILE" "$BAM_FILE" "$BED_FILE"

    # ------------------------------
    # 3. Filter methylation data (M only)
    # ------------------------------
    echo "Filtering methylation data..."
    awk '$4 == "m" && $11 != 0 {print $3, $11}' "$BED_FILE" > "$BED_M_FILE"

    # ------------------------------
    # 4. Dynamic threshold from Python
    # ------------------------------
    echo "Computing dynamic mean and median thresholds..."
    read -r MEAN MEDIAN <<< "$(python3 "$SCRIPT_DIR/get_stats.py" "$BED_M_FILE")"

    echo "Mean = $MEAN"
    echo "Median = $MEDIAN"

    awk -v threshold="$MEAN" '$11 > threshold {print $3, $11}' "$BED_FILE" > "$METHPOS_FILE"
    cp "$BED_FILE" "$FULL_BED_TEXT"

    # ------------------------------
    # 5. Convert methylation -> binary -> ASCII
    # ------------------------------
    echo "Processing methylation positions in Python..."
    echo "Selected BITWIDTH = $BITWIDTH"
    python3 "$SCRIPT_DIR/meth_analysis.py" "$METHPOS_FILE" "$BITWIDTH"

    TIMESTAMP="$(date +%d%m%y_%H%M%S)"
    cp "$METHPOS_FILE" "$LOGDIR/${OUTPUT_ID}_methpos_${TIMESTAMP}.txt"

    ERROR_REPORT_PATH=""
    if [[ -n "$BARCODE_WORD" ]]; then
        ERROR_REPORT_PATH="$ERROR_LOGDIR/ErrorStats_${OUTPUT_ID}_${TIMESTAMP}.txt"
        python3 "$SCRIPT_DIR/error_stats.py" "$METHPOS_FILE" "$BITWIDTH" --word "$BARCODE_WORD" --output "$ERROR_REPORT_PATH"
    else
        echo "Skipping error stats for '$BARCODE_NAME' because no word was provided."
    fi

    if [[ "$SAVE_BED_ERROR" == "true" ]]; then
        BARCODE_SAVE_DIR="$SAVE_RUN_DIR/$OUTPUT_ID"
        mkdir -p "$BARCODE_SAVE_DIR"

        cp "$BED_FILE" "$BARCODE_SAVE_DIR/methylation_cpg.bed"
        cp "$BED_M_FILE" "$BARCODE_SAVE_DIR/methylation_M.txt"
        cp "$FULL_BED_TEXT" "$BARCODE_SAVE_DIR/full_bed.txt"

        if [[ -n "$ERROR_REPORT_PATH" && -f "$ERROR_REPORT_PATH" ]]; then
            cp "$ERROR_REPORT_PATH" "$BARCODE_SAVE_DIR/$(basename "$ERROR_REPORT_PATH")"
        fi

        echo "Saved BED/error artifacts to $BARCODE_SAVE_DIR"
    fi

    rm -rf "$CURRENT_WORKDIR"
    CURRENT_WORKDIR=""
done

# ------------------------------
# Done
# ------------------------------
echo "Pipeline completed successfully."
echo "Logged output to $LOGFILE"
