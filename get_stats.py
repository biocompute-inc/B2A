import statistics

def compute_stats(mfile="./methylation_M.txt"):
    meth_values = []
#Parsing the methylation fraction and position
    with open(mfile) as f:
        for line in f:
            pos, frac = line.split()
            pos = int(pos)
            frac = float(frac)

            # filter for methylated C site specificity and  ONT baseline methylation
            # First 48 nt is non payload region. Every 12th position from 48th position is the desired methylation site. Ignore the G methylation sites
            if pos >= 60 and pos % 12 == 0 and frac > 15.5:
                meth_values.append(frac)

    if not meth_values:
        raise ValueError("No values passed the filters!")

    mean_value = statistics.mean(meth_values)
    median_value = statistics.median(meth_values)

    # Print both so the shell script can capture them
    print(mean_value, median_value)

if __name__ == "__main__":
    compute_stats()
