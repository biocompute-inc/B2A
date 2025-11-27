import sys
import statistics
def process_methylation(file_path):
    # File with M-tag positions and non-zero fraction
    all_meth = "methylation_M.txt"

# Initialize dictionary
    meth_dict = {}
    meth_values = []
    with open(all_meth) as f:
        for line in f:
            pos, frac = line.split()
            pos = int(pos)
            frac = float(frac)
            meth_dict[pos] = frac
    for i in meth_dict:
        if i>=60 and i%12==0:
            meth_values.append(meth_dict[i])
            # print(i)
    print(meth_values)
    mean_value = statistics.mean(meth_values)
    print("\n Mean Value:",mean_value)
    median_value = statistics.median(meth_values)
    print("\n Median: ",median_value)
    methpositions = []
    perc= []

    # Read methylation positions from file
    with open(file_path, 'r') as file:
        for line in file:
            parts = line.split()
            if len(parts) == 2:
                try:
                    end_position = int(parts[0])
                    methpositions.append(end_position)
                except ValueError:
                    print(f"Skipping line due to invalid format: {line}")
            else:
                print(f"Skipping line with unexpected number of columns: {line}")


    start = 60
    end = 912
    step = 24
    sites = list(range(start, end + 1, step))
    print(f"CG sites: {sites}")

    # Determine methylation status for each site
    methylation_status = []
    for pos in sites:
        if pos in methpositions:
            methylation_status.append(1)  # methylated
        else:
            methylation_status.append(0)  # not methylated

    print(f"Methylation status (1 = methylated, 0 = not methylated): {methylation_status}")

    # Print positions with their methylation status
    for pos, status in zip(sites, methylation_status):
        print(f"Position: {pos}, Methylation status: {status}")

    # Group methylation status into 8-bit chunks
    group_size = 8
    grouped_strings = []

    for i in range(0, len(methylation_status), group_size):
        chunk = methylation_status[i:i + group_size]
        chunk_str = ''.join(str(x) for x in chunk)
        grouped_strings.append(chunk_str)

    print("Grouped strings (8-bit chunks):", grouped_strings)

    # Convert chunks to ASCII
    ascii_chars = []
    for s in grouped_strings:
        if len(s) == 8:
            num = int(s, 2)
            char = chr(num)
            ascii_chars.append(char)
    print("ASCII characters:", ascii_chars)

    return ascii_chars

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 pipe.py <methpos_file>")
        sys.exit(1)

    file_path = sys.argv[1]
    process_methylation(file_path)
