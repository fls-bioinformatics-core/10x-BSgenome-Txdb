#!/bin/bash

# Usage function
function usage()
{
   cat << HEREDOC

   Build 10x BSgenome Txdb v$version

   Use this build script to create a BSgenome source package and a TxDb object stored as a SQLite database file.
   Current, it supports the 10x Genomics Human and Mouse references 2020-A and 2024-A.

   To run this script, it requires internet connectivity and the following software and R packages installed:
   - faToTwoBit and twoBitInfo from the UCSC Genome Browser suite
   - R (tested in R 4.5)
   - BSgenomeForge, txdbmaker, and GenomeInfoDbData R/Bioconductor packages

   Usage: $progname [--release VER] [--name ORG] [--outdir OUT_DIR]

   optional arguments:
     -r, --release VER        The release name of pre-built Cell Ranger or Cell Ranger ARC reference package.
                              It can be can be 2020-A or 2024-A, default is 2024-A.
     -n, --name ORG           The organism name of pre-built Cell Ranger or Cell Ranger ARC reference package
                              It can be Human or Mouse, default is Human.
     -o, --outdir OUT_DIR     Save all outputs to OUT_DIR, default is constructed as 10x_ORG_VER
     -h, --help               Show this help message and exit

HEREDOC
}

# Initialize variables
version="1.0.0"
curdir=$(pwd)
progname=$(basename $0)
release=
name=
outdir=

while [[ $# -gt 0 ]]; do
  case $1 in
    -h | --help) 
      usage
      exit 
      ;;
    -r |--release)
      release="$2"
      shift 2
      ;;
    -n |--name)
      name="$2"
      shift 2
      ;;
    -o |--outdir)
      name="$2"
      shift 2
      ;;
    *) 
      echo "Unknown parameter passed: $1"
      exit 1
      ;;
  esac
done

if [[ "$release" != "2020-A" && "$release" != "2024-A" ]]; then
    release="2024-A"
fi

if [[ "$name" != "Human" && "$name" != "Mouse" ]]; then
    name="Human"
fi

if [ -z $outdir ]; then
    outdir="10x-$name-$release"
fi

# Make output folder and cd to it
if [ -d $outdir ]; then
    echo "The output folder \"$outdir\" already exists, build script stops."
    exit 1
fi

mkdir $outdir
cd $outdir

# Check required programs
if [[ -z $(which faToTwoBit) || -z $(which twoBitInfo) ]]; then
    echo "Requires 'faToTwoBit' and 'twoBitInfo' from the UCSC Genome Browser suite installed."
    exit 1
fi

if [ -z $(which R) ]; then
    echo "Requires 'R' installed."
    exit 1
fi

if [[ $(Rscript -e "cat(sum(c('BSgenomeForge','txdbmaker','GenomeInfoDbData') %in% rownames(installed.packages())) == 3)") == "FALSE" ]]; then
    echo "Requires R packages BSgenomeForge, txdbmaker and GenomeInfoDbData."
    echo "Please install them with:
    BiocManager::install(c(\"BSgenomeForge\",\"txdbmaker\",\"GenomeInfoDbData\"))"
    exit 1
fi

# 2020-A Human v32, GRCh38.p13, Ensembl 98
# 2020-A Mouse vM23, GRCm38.p6, Ensembl 98
# 2024-A Human v44, GRCh38.p13, Ensembl 110 * Note: Ensembl 109 FASTA is used by 10x Genomics, see build notes
# 2024-A Mouse vM33, GRCm39, Ensembl 110

# Setup some metadata
# 1. Genome
if [[ "$name" == "Human" ]]; then
    organism="Homo sapiens"
    organism_biocview="Homo_sapiens"
    genomeObjname="Hsapiens"
    genome="GRCh38" # used in both 2020-A and 2024-A
    assembly="GRCh38.p13"

    if [[ "$release" != "2024-A" ]]; then
        build="GRCh38-2020-A_build"
	build_sh="10x_GRCh38-2020-A.sh"
	gtf_filtered="$build/gencode.v32.primary_assembly.annotation.gtf.filtered"
    else
        build="GRCh38-GENCODEv44_build"
	build_sh="10x_GRCh38-2024-A.sh"
	gtf_filtered="$build/gencode.v44.primary_assembly.annotation.gtf.filtered"
    fi
    fasta_modified="$build/Homo_sapiens.GRCh38.dna.primary_assembly.fa.modified"
else
    organism="Mus musculus"
    organism_biocview="Mus_musculus"
    genomeObjname="Mmusculus"

    if [[ "$release" != "2024-A" ]]; then
        genome="GRCm38"
	assembly="GRCm38.p6"
        build="mm10-2020-A_build"
	build_sh="10x_mm10-2020-A.sh"
	fasta_modified="$build/Mus_musculus.GRCm38.dna.primary_assembly.fa.modified"
	gtf_filtered="$build/gencode.vM23.primary_assembly.annotation.gtf.filtered"
    else
        genome="GRCm39"
	assembly="GRCm39" # no patch
        build="GRCm39-GENCODEv33_build"
	build_sh="10x_GRCm39-2024-A.sh"
	fasta_modified="$build/Mus_musculus.GRCm39.dna.primary_assembly.fa.modified"
	gtf_filtered="$build/gencode.vM33.primary_assembly.annotation.gtf.filtered"
    fi
fi

# 2. BSgenome package
package="BSgenome.$genomeObjname.10x.$genome.$release"
package=$(echo $package | sed 's/[ -]/./g')
seedfile="$package-seed"

# 3. twoBit and chrom.sizes file names
twoBit="$build/${genome}-${release}.2bit"
chromsize="$build/${genome}-${release}.chrom.sizes"

# Run reference build steps
echo "
===| Run build steps in $build_sh |===
"
while sleep 1; do printf "."; done & # print dots while waiting
bash $curdir/scripts/$build_sh
kill $!
echo

# Create twoBit and chrom.sizes files
echo "
===| Create twoBit and chrom.sizes files |===
"

if [ ! -e $fasta_modified ]; then
    echo "Cannot find the required reference fasta file in \"$fasta_modified\""
    exit 1
fi

while sleep 1; do printf "."; done & # print dots while waiting
faToTwoBit $fasta_modified $twoBit
kill $!
echo

srcDate=$(date '+%F %T %z (%a, %d %b %Y)')
twoBitInfo $twoBit stdout | sort -k2rn > $chromsize

# Create seed file
cat > $seedfile <<EOL
Package: $package
Title: Full genomic sequences for $organism ($genome-$release)
Description: Full genomic sequences for $organism generated by following the $release build notes as provided by 10x Genomics and stored in Biostrings objects.
Version: $version
Author: I-Hsuan Lin, 10x Genomics
Maintainer: I-Hsuan Lin <ycl6.gel@gmail.com>
License: GPL (>=3)
organism: $organism
common_name: $name
provider: 10x Genomics
genome: $assembly
release_date: $(date '+%F')
source_url: https://www.10xgenomics.com/support/software/cell-ranger/downloads/cr-ref-build-steps
organism_biocview: $organism_biocview
BSgenomeObjname: $genomeObjname
circ_seqs: "chrM"
PkgDetails: The modified fasta used to build BSgenome is identical for Cell Ranger and Cell Ranger ARC in $release.
SrcDataFiles: $genome-$release.2bit, created from the modified reference build on $srcDate
PkgExamples: bsg\$chr1 # same as bsg[["chr1"]]
seqs_srcdir: $build
seqfile_name: $genome-$release.2bit
EOL

# Build BSgenome
echo "
===| Forge $package BSgenome package |===
"
R --quiet -e "BSgenomeForge::forgeBSgenomeDataPkg(\"$seedfile\")"

echo "
===| Build the source package |===
"
R CMD build $package

echo "
===| Check the source package |===
"
R CMD check ${package}_${version}.tar.gz

echo "
* To install the BSgenome package, run \`R CMD INSTALL ${package}_${version}.tar.gz\` from terminal."

# Build TxDB
echo "
===| Build TxDb from Gencode GTF |===
"
Rscript $curdir/scripts/create_txdb.R organism="$organism" assembly="$assembly" gtfFile="$gtf_filtered" chromSize="$chromsize"

# Return to original directory
cd $curdir

echo "
Completed. All output files can be found in \"$outdir\".
"

