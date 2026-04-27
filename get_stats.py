import statistics
import sys


def compute_stats(mfile):
    meth_values = []

    # Parsing the methylation fraction and position.
    with open(mfile) as f:
        for line in f:
            parts = line.split()
            if len(parts) < 2:
                continue

            pos = int(parts[0])
            frac = float(parts[1])

            # Filter for methylated C site specificity and ONT baseline methylation.
            # First 48 nt is non payload region. Every 12th position from 48th
            # position is the desired methylation site. Ignore G methylation sites.
            if pos >= 60 and pos % 12 == 0 and frac > 15.5:
                meth_values.append(frac)

    if not meth_values:
        raise ValueError("No values passed the filters!")

    mean_value = statistics.mean(meth_values)
    median_value = statistics.median(meth_values)

    # Print both so the shell script can capture them.
    print(mean_value, median_value)


if __name__ == "__main__":
    if len(sys.argv) > 2:
        print("Usage: python3 get_stats.py [methylation_M_file]")
        sys.exit(1)

    methylation_file = sys.argv[1] if len(sys.argv) == 2 else "./methylation_M.txt"
    compute_stats(methylation_file)
