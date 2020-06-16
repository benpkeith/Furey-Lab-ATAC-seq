#!/bin/bash -i
# Ben Keith
# Script to load the various environmental variables for pepatac
# USAGE: bash PEPATACenv.sh <genome>

if (($# == 0)); then
  echo "NO INPUT PARAMETERS! Enter either "human" or "mouse" for the first\
   argument"; exit;
fi


genome="$1"
echo "Setting env for $genome sample processing"

#################
#### MODULES ####
#################

echo "LOADING MODULES"
module load python/3.6.6
module load r/3.6.0
module load bedtools/2.29
module load bowtie2/2.4.1
module load fastqc/0.11.8
module load samblaster/0.1.24
module load samtools/1.9
module load skewer/0.2.2
module load macs/2.2.7.1

echo "MODULES LOADED:"
module list

###################
#### ENV SETUP ####
###################

# Furey lab bin
export PATH='$PATH:/proj/fureylab/bin/'

export PATH='$PATH:/path/pepatac/tools/'


##### MIGHT BE BEST TO HARD CODE THESE INTO THE CONFIG FILES!
export CODEBASE='/proj/fureylab/pipelines/ATAC/pepatac_0.9.0/tools'
export PEPENV='/proj/fureylab/pipelines/ATAC/pepatac_0.9.0/pipelines/pepatac.yaml'
export DIVCFG='/proj/fureylab/pipelines/ATAC/pepatac_0.9.0/divcfg/unc_longleaf.yaml'

# Loading the correct genome according to 1st argument
if [ "$genome" = "human" ]
then
  export GENOMES='/proj/fureylab/genomes/human/refgenie/'
elif [ "$genome" = "mouse" ]
then
  export GENOMES='/proj/fureylab/genomes/mouse/refgenie/'
fi

echo "Environmental variables set. Exiting..."