# Create BSgenome and Txdb for 10x Genomics pre-built references

This repository documents the bash and R scripts used to create the BSgenome R/Bioconductor packages and TxDb objects 
from reference genomes and annotation files used by the 10x Genomics to build its human and mouse references, 
versions 2020-A and 2024-A, for Cell Ranger and Cell Ranger ARC.

To download the BSgenome R/Bioconductor packages and TxDb objects, 
please follow the link to Zenodo here: https://doi.org/10.5281/zenodo.17937032

## Build your own files

The main script is `build.sh`. Use `bash build.sh -h` to see help messages.

### For 2020-A Human

This version of the reference uses the GRCh38.p13 genome (Ensembl 98) and Gencode v32 annotation.

```sh
bash build.sh -r 2020-A -n Human
```

### For 2020-A Mouse

This version of the reference uses the GRCm38.p6 genome (Ensembl 98) and Gencode vM23 annotation.

```sh
bash build.sh -r 2020-A -n Mouse
```

### For 2024-A Human

This version of the reference uses the GRCh38.p13 genome (Ensembl 109\*) and Gencode v44 annotation.

\**Although Ensembl 110 is the advertised version used by 10x Genomics to build its 2024-A references,
the FASTA from release 109 (GRCh38) is used instead, as release 110 has moved from GRCh38.p13 to GRCh38.p14,
which unmasked the pseudo-autosomal region and causes ambiguous mappings to PAR locus genes.
There are no other sequence changes made to the primary assembly.*

```sh
bash build.sh -r 2024-A -n Human
```

### For 2024-A Mouse

This version of the reference uses the GRCm39 genome (Ensembl 110) and Gencode vM33 annotation.

```sh
bash build.sh -r 2024-A -n Mouse
```

## Build master blacklists

This section contains additional instructions if you wish to create a blacklist for ATAC, single-cell ATAC or Multiome (ATAC + Gene Expression) analysis.

First two are the main sources used, with the third offers problematic genomic regions from more organisms and assemblies:

1. ENCODE Blacklists (V2): https://github.com/Boyle-Lab/Blacklist
  - mm9 does not have a version 2 blacklist, hence version 1 is used instead
2. Mitochondrial blacklists: https://github.com/caleblareau/mitoblacklist
3. `excluderanges` R/Bioconductor package: https://bioconductor.org/packages/excluderanges

### hg19 (GRCh37)

```sh
wget -O hg19_peaks.narrowPeak "https://raw.githubusercontent.com/caleblareau/mitoblacklist/refs/heads/master/peaks/hg19_peaks.narrowPeak"
wget -O hg19-blacklist.v2.bed.gz "https://github.com/Boyle-Lab/Blacklist/raw/refs/heads/master/lists/hg19-blacklist.v2.bed.gz"
gunzip hg19-blacklist.v2.bed.gz

cat hg19-blacklist.v2.bed hg19_peaks.narrowPeak | \
    awk '{print $1"\t"$2"\t"$3"\t"$4}' | sortBed | \
    mergeBed -i stdin -d 10 -c 4 -o distinct > hg19.master.blacklist.bed
```

### hg38 (GRCh38)

```sh
wget -O hg38_peaks.narrowPeak "https://raw.githubusercontent.com/caleblareau/mitoblacklist/refs/heads/master/peaks/hg38_peaks.narrowPeak"
wget -O hg38-blacklist.v2.bed.gz "https://github.com/Boyle-Lab/Blacklist/raw/refs/heads/master/lists/hg38-blacklist.v2.bed.gz"
gunzip hg38-blacklist.v2.bed.gz

cat hg38-blacklist.v2.bed hg38_peaks.narrowPeak | \
    awk '{print $1"\t"$2"\t"$3"\t"$4}' | sortBed | \
    mergeBed -i stdin -d 10 -c 4 -o distinct > hg38.master.blacklist.bed
```

### mm9 (GRCm37)

```sh
wget -O mm9_peaks.narrowPeak "https://raw.githubusercontent.com/caleblareau/mitoblacklist/refs/heads/master/peaks/mm9_peaks.narrowPeak"
wget -O mm9-blacklist.bed.gz "https://github.com/Boyle-Lab/Blacklist/raw/refs/heads/master/lists/Blacklist_v1/mm9-blacklist.bed.gz"
gunzip mm9-blacklist.bed.gz

cat mm9-blacklist.bed | awk '{print $0"\tENCODE_v1"}' | cat - mm9_peaks.narrowPeak | \
    awk '{print $1"\t"$2"\t"$3"\t"$4}' | sortBed | \
    mergeBed -i stdin -d 10 -c 4 -o distinct > mm9.master.blacklist.bed
```

### mm10 (GRCm38)

```sh
wget -O mm10_peaks.narrowPeak "https://raw.githubusercontent.com/caleblareau/mitoblacklist/refs/heads/master/peaks/mm10_peaks.narrowPeak"
wget -O mm10-blacklist.v2.bed.gz "https://github.com/Boyle-Lab/Blacklist/raw/refs/heads/master/lists/mm10-blacklist.v2.bed.gz"
gunzip mm10-blacklist.v2.bed.gz

cat mm10-blacklist.v2.bed mm10_peaks.narrowPeak | \
    awk '{print $1"\t"$2"\t"$3"\t"$4}' | sortBed | \
    mergeBed -i stdin -d 10 -c 4 -o distinct > mm10.master.blacklist.bed
```

### mm39 (GRCm39)

The blacklisted regions for mm39 is available from the `excluderanges` R/Bioconductor package. 
You may also download the data from authors' Google Drive [here](https://drive.google.com/drive/folders/1sF9m8Y3eZouTZ3IEEywjs2kfHOWFBSJT?usp=sharing).
