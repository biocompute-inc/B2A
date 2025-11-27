# B2A
This repository contains the script to convert .BAM files to ASCII values.

## Required packages
- [Modkit](https://github.com/nanoporetech/modkit/blob/master/README.md)
- [Samtools](https://anaconda.org/bioconda/samtools)


The script takes 3 inputs in the following order:
- Input file location
- Reference Sequence file location
- Number of Bits in Byte as set in the wet lab experiments- 7 or 8, defaults to 8


Outputs:
- A log directory folder named ASCII logs is created and the following are logged:
    - ASCII Log_ddmmyy_hhmmss: Contains the output shown on the terminal, contains the binary and ASCII sequence extracted from the .BAM file.
    - methpos_ddmmyy_hhmmss: Contains the position and the methylation fractions of sites that have methylation fractions above the threshold set.
- Intermediate files:
    a.


Command Line:
```
./run_pipeline.sh comptest_sorted.bam 960nt.fasta 8

```
**Note**: The .bam file and has to be in the same root directory as that of the bash script according to the example. Otherwise, full path lengths should be given
