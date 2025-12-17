# B2A
This repository contains the script to convert .BAM files to ASCII values.

## Required packages
- [Modkit](https://github.com/nanoporetech/modkit/blob/master/README.md)
- [Samtools](https://anaconda.org/bioconda/samtools)
- [Conda](https://anaconda.org/anaconda/conda)

## Inputs:
The script takes 3 inputs in the following order:
- Input file path (.bam)
- Reference Sequence file path (.fasta or .fa)
- Number of Bits in Byte as set in the wet lab experiments- 7 or 8, defaults to 8

Command Line:
```
./run_pipeline.sh input.bam reference.fasta 8

```
**Note**: The .bam file and has to be in the same root directory as that of the bash script according to the example. Otherwise, full path lengths should be given

## Outputs:
- A log directory folder named ASCII logs is created and the following are logged:
    - ASCII Log_ddmmyy_hhmmss.txt: Contains the output shown on the terminal, contains the binary and ASCII sequence extracted from the .BAM file.
    - methpos_ddmmyy_hhmmss.txt: Contains the position and the methylation fractions of sites that have methylation fractions above the threshold set.
- A log directory folder named Error logs is created and the following are logged:
    - ErrorStats_ddmmyyy_hhmmss.txt: Contains error statistics: Error Percentage, Count and position of Bit flips
- Intermediate files:
    - full_bed.txt: Contains the entire .bed file generarted by modkit (Column descriptions are given in the [modkit documentation](https://github.com/nanoporetech/modkit)) 



