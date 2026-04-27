import argparse
import sys


def load_methpositions(path):
    """Read first column (positions) from methpos file."""
    methpositions = []
    try:
        with open(path) as f:
            for line in f:
                parts = line.split()
                if not parts:
                    continue
                try:
                    pos = int(parts[0])
                    methpositions.append(pos)
                except ValueError:
                    # ignore malformed lines
                    continue
    except FileNotFoundError as exc:
        raise FileNotFoundError(f"methylation positions file '{path}' not found") from exc

    return methpositions


def ascii_to_binary(text, bitwidth):
    """Convert ASCII text to binary with given bitwidth (7 or 8)."""
    fmt = f"0{bitwidth}b"
    binary_representation = ' '.join(format(ord(char), fmt) for char in text)
    no_space = ''.join(format(ord(char), fmt) for char in text)
    return binary_representation, no_space


def build_error_report(methpos_file, bitwidth, desired_word):
    # 1) Load actual methylation positions from file.
    mpos = load_methpositions(methpos_file)

    # 2) Convert word to binary using the chosen bitwidth.
    each_letter_binary, desired_binary = ascii_to_binary(desired_word, bitwidth)

    # 3) Build CG sites grid (must match meth_analysis.py).
    start, end, step = 60, 912, 24
    sites = list(range(start, end + 1, step))

    # 4) Actual bits from methylation data (one per CG site).
    filtered_mpos = []
    actual_bits = []

    for site in sites:
        bit_value = 0
        for mp in mpos:
            if mp == site:
                bit_value = 1
                filtered_mpos.append(site)
                break
        actual_bits.append(bit_value)

    # 5) Desired bits from the word.
    desired_bits = [int(bit) for bit in desired_binary]

    # Align lengths: compare only up to the shorter of the two.
    n_compare = min(len(desired_bits), len(actual_bits))

    # 6) Compute matches and flips.
    matches = 0
    flips_1_to_0 = []
    flips_0_to_1 = []

    for idx in range(n_compare):
        desired = desired_bits[idx]
        actual = actual_bits[idx]
        cg_pos = sites[idx]

        if desired == actual:
            matches += 1
        elif desired == 1 and actual == 0:
            flips_1_to_0.append((idx, cg_pos))
        elif desired == 0 and actual == 1:
            flips_0_to_1.append((idx, cg_pos))

    # 7) Brick numbers for desired pattern.
    brick_counter = 2
    desired_bricks = []
    for bit in desired_binary:
        if bit == '1':
            desired_bricks.append(brick_counter)
        brick_counter += 1

    desired_cg_sites = []
    for brick_index in desired_bricks:
        cg_pos = 60 + (24 * (brick_index - 2))
        desired_cg_sites.append(cg_pos)

    total_bits = len(desired_bits)
    percent_ones = (len(desired_bricks) / total_bits) * 100 if total_bits > 0 else 0.0
    error_percentage = ((total_bits - matches) / total_bits) * 100 if total_bits > 0 else 0.0

    lines = []
    lines.append(f"Input methpos file: {methpos_file}")
    lines.append(f"Bitwidth: {bitwidth}")
    lines.append(f"Desired word: {desired_word}")
    lines.append("")
    lines.append(f"Each letter in binary: {each_letter_binary}")
    lines.append(f"Desired word in binary (no spaces): {desired_binary}")
    lines.append("")

    if len(desired_bits) > len(actual_bits):
        lines.append(
            f"Warning: desired pattern ({len(desired_bits)} bits) is longer than "
            f"available CG sites ({len(actual_bits)}). Only comparing first {n_compare} bits."
        )
        lines.append("")

    lines.append(f"Desired methylated brick numbers are: {desired_bricks}")
    lines.append(f"Desired methylated CG sites are: {desired_cg_sites}")
    lines.append(f"Actual methylated CG sites are: {filtered_mpos}")
    lines.append(f"Desired percentage of 1's: {percent_ones}")
    lines.append("")

    lines.append(f"Total positions compared: {n_compare}")
    lines.append(f"Matches (desired == actual): {matches}")
    lines.append("")

    lines.append(f"1 -> 0 flips (desired 1, actual 0): {len(flips_1_to_0)}")
    lines.append("Positions (index, CG site):")
    for idx, pos in flips_1_to_0:
        lines.append(f"  Bit/Brick number= {idx + 1}, CG_site= {pos}")
    lines.append("")

    lines.append(f"0 -> 1 flips (desired 0, actual 1): {len(flips_0_to_1)}")
    lines.append("Positions (index, CG site):")
    for idx, pos in flips_0_to_1:
        lines.append(f"  Bit/Brick number= {idx + 1}, CG_site= {pos}")
    lines.append(f"Error Percentage: {error_percentage}")

    return "\n".join(lines)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Compute desired-vs-actual methylation error statistics."
    )
    parser.add_argument("methpos_file", help="Path to methpos file")
    parser.add_argument("bitwidth", type=int, help="Bitwidth: 7 or 8")
    parser.add_argument("--word", dest="word", help="Desired text payload")
    parser.add_argument("--output", dest="output_path", help="Optional output report file")
    args = parser.parse_args()

    if args.bitwidth not in (7, 8):
        print("Error: bitwidth must be 7 or 8")
        sys.exit(1)

    desired_word = args.word
    if desired_word is None:
        if sys.stdin.isatty():
            desired_word = input("Please enter your word\n").strip()
        else:
            print("ERROR: --word is required in non-interactive mode.")
            sys.exit(1)

    if desired_word == "":
        print("ERROR: desired word cannot be empty.")
        sys.exit(1)

    try:
        report_text = build_error_report(args.methpos_file, args.bitwidth, desired_word)
    except FileNotFoundError as exc:
        print(f"ERROR: {exc}")
        sys.exit(1)

    print(report_text)

    if args.output_path:
        with open(args.output_path, "w") as out_file:
            out_file.write(report_text)
            out_file.write("\n")
