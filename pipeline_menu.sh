#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_SCRIPT="$SCRIPT_DIR/run_pipeline.sh"

if [[ ! -f "$PIPELINE_SCRIPT" ]]; then
    echo "ERROR: Could not find run_pipeline.sh in $SCRIPT_DIR"
    exit 1
fi

prompt_with_default() {
    local prompt="$1"
    local default_value="$2"
    local value

    read -r -p "$prompt [$default_value]: " value
    if [[ -z "$value" ]]; then
        value="$default_value"
    fi
    printf '%s\n' "$value"
}

prompt_required() {
    local prompt="$1"
    local value=""

    while [[ -z "$value" ]]; do
        read -r -p "$prompt: " value
        if [[ -z "$value" ]]; then
            echo "This value is required."
        fi
    done
    printf '%s\n' "$value"
}

prompt_yes_no() {
    local prompt="$1"
    local default_choice="${2:-y}"
    local answer

    while true; do
        if [[ "$default_choice" == "y" ]]; then
            read -r -p "$prompt [Y/n]: " answer
            answer="${answer:-y}"
        else
            read -r -p "$prompt [y/N]: " answer
            answer="${answer:-n}"
        fi

        case "${answer,,}" in
            y|yes)
                return 0
                ;;
            n|no)
                return 1
                ;;
            *)
                echo "Please enter y or n."
                ;;
        esac
    done
}

collect_word_options() {
    local -n out_option_args_ref=$1
    local choice
    local word
    local map_path

    echo
    echo "Error-stats mode:"
    echo "  1) Same intended word for all BAMs"
    echo "  2) Use word map file (per barcode/BAM)"
    echo "  3) Skip error stats"

    while true; do
        choice="$(prompt_with_default "Choose mode" "1")"
        case "$choice" in
            1)
                word="$(prompt_required "Enter intended word")"
                out_option_args_ref+=(--word "$word")
                return
                ;;
            2)
                map_path="$(prompt_with_default "Enter word map path" "$SCRIPT_DIR/words.map")"
                out_option_args_ref+=(--word-map "$map_path")
                return
                ;;
            3)
                return
                ;;
            *)
                echo "Invalid choice. Please select 1, 2, or 3."
                ;;
        esac
    done
}

collect_save_options() {
    local -n out_option_args_ref=$1
    local save_dir

    if prompt_yes_no "Save BED/error artifacts?" "n"; then
        save_dir="$(prompt_with_default "Save root directory" "$SCRIPT_DIR/Saved_BED_Error")"
        out_option_args_ref+=(--save-bed-error --save-dir "$save_dir")
    fi
}

run_pipeline_interactive() {
    local input_mode="$1"
    local input_path
    local ref_path
    local bitwidth
    local exit_code=0
    local option_args=()
    local positional_args=()
    local arg

    echo
    if [[ "$input_mode" == "file" ]]; then
        input_path="$(prompt_required "Enter BAM file path")"
    else
        input_path="$(prompt_required "Enter BAM folder path")"
    fi

    ref_path="$(prompt_with_default "Enter reference FASTA path" "$SCRIPT_DIR/reference.fasta")"

    while true; do
        bitwidth="$(prompt_with_default "Enter bitwidth (7 or 8)" "8")"
        if [[ "$bitwidth" == "7" || "$bitwidth" == "8" ]]; then
            break
        fi
        echo "Bitwidth must be 7 or 8."
    done

    collect_word_options option_args
    collect_save_options option_args

    positional_args+=("$input_path" "$ref_path" "$bitwidth")

    echo
    echo "Command preview:"
    printf 'bash %q' "$PIPELINE_SCRIPT"
    for arg in "${option_args[@]}" "${positional_args[@]}"; do
        printf ' %q' "$arg"
    done
    printf '\n\n'

    if ! prompt_yes_no "Run this command now?" "y"; then
        echo "Canceled."
        return
    fi

    bash "$PIPELINE_SCRIPT" "${option_args[@]}" "${positional_args[@]}" || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        echo
        echo "Pipeline run completed successfully."
    else
        echo
        echo "Pipeline run failed with exit code $exit_code."
    fi
}

create_word_map_interactive() {
    local output_path
    local key
    local word

    echo
    output_path="$(prompt_with_default "Word map output path" "$SCRIPT_DIR/words.map")"
    : > "$output_path"

    echo "Enter mapping rows as barcode/BAM key + intended word."
    echo "Leave key empty to finish."

    while true; do
        IFS= read -r -p "Key (e.g., barcode01 or sampleX): " key
        if [[ -z "$key" ]]; then
            break
        fi

        IFS= read -r -p "Intended word for '$key': " word
        if [[ -z "$word" ]]; then
            echo "Word cannot be empty; skipping '$key'."
            continue
        fi

        printf '%s %s\n' "$key" "$word" >> "$output_path"
    done

    echo "Saved word map: $output_path"
}

show_help_text() {
    echo
    echo "Quick notes:"
    echo "- Single BAM mode: choose menu option 1."
    echo "- Folder mode (multiple BAMs): choose menu option 2."
    echo "- Use word-map mode for per-barcode intended words."
    echo "- Use save option to preserve per-run BED/error artifacts."
    echo
}

while true; do
    echo
    echo "=========================================="
    echo "B2A Pipeline Menu"
    echo "=========================================="
    echo "1) Run pipeline for one BAM file"
    echo "2) Run pipeline for BAM folder (multi-barcode)"
    echo "3) Create/Edit word map file"
    echo "4) Help"
    echo "5) Exit"

    case "$(prompt_with_default "Choose an option" "1")" in
        1)
            run_pipeline_interactive "file"
            ;;
        2)
            run_pipeline_interactive "folder"
            ;;
        3)
            create_word_map_interactive
            ;;
        4)
            show_help_text
            ;;
        5)
            echo "Goodbye."
            exit 0
            ;;
        *)
            echo "Invalid option. Please choose 1-5."
            ;;
    esac
done