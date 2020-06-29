# Furey-Lab-ATAC-seq
Adaptation of the PEPATAC pipeline for use on UNCs Longleaf with additional post-processing steps.

## Summary

Assuming you have your config and annotation file set up, all you'll need to do is go to the directory **in scratch space** that you want to work in, and execute the following commands:

```
git clone https://sc.unc.edu/dept-fureylab/atac_pepatac.git
cd atac_pepatac
source PEPATACenv.sh human
looper run /path/to/PEPATAC_config.yaml
```

If working with mouse samples, the _"source PEPATACenv.sh human"_ is replaced with _"source PEPATACenv.sh mouse"_

## Set up

#### Cloning the pipeline files and setting up your environment

Setting up the pipelines itself _should_ be easy, requiring a clone of the ATAC_pepatac repo from the lab git and a single command to load module and environmental variables. The pipeline is currently only set up for **hg38** and **mm10**.

The pipeline will need to run from a suitable directory in your scratch space. the path to your scratch space is relative to your UNC onyen, e.g. /pine/scr/O/N/ONYEN. Once there, create a directory that you can run the analysis out of. For example:

```
cd /pine/scr/b/p/bpk
mkdir 2020_06_19_analysis
cd 2020_06_19_analysis
```

You're now set to grab the files you need. To clone the files you'll need, use the command:

```
git clone https://sc.unc.edu/dept-fureylab/atac_pepatac.git
mv atac_pepatac/* .
rm -rf atac_pepatac
```

Various software and environmental pointers are needed to run PEPATAC. To set all of this up, you will need to source the _PEPATACenv.sh_ file as follows:

```
source PEPATACenv.sh human
```

or for mouse samples:

```
source PEPATACenv.sh mouse
```

Although the pipeline (at time of writing: June 19th 2020) is only set up for mm10 and hg38, these commands will not need to change. Rather the /proj/fureylab/genomes/human/refgenie/ and /proj/fureylab/genomes/mouse/refgenie/ directories will just need to updated with the needed genome builds which can then be added to the PEPATAC config file, which we'll get to next.

#### Config and annotation files

PEPATAC uses the PEP 2.0 standard for configuration files, which is a way of standardizing pointers to various things and options you may want to set when running a pipeline. The files _PEPATAC_config.yaml_ and _PEPATAC_annotation.csv_, which are now in your analysis directory after cloning the atac repo, will serve as templates which you can use to set up your run of the pipeline.

Setting these files up is easy!

<ins>**Annotation file**<ins/> - PEPATAC_annotation.csv


Populate your annotation file with the samples you want to run through the pipeline. The format is one sample per row. The only potential pitfall here may be the _read1_ and _read2_ columns. These are just variable names that will be used in the config file to point to where the pipeline can fine you forward and reverse read files. To keep things easy, just call these "sampleName_R1" and "sampleName_R2".


<ins>**Config file**<ins/> - PEPATAC_config.yaml

The config file contain a number of fields that you will need to edit, and a few that should not be changed. The fields that you should not change (pipeline_interfaces) are marked with the comments "_# DO NOT CHANGE!_".

Fields to edit:

- name - This is used in summary files. Give your project a useful name and a date that you can easily reference. **Do not include any spaces in this project name**, use underscores instead.
- sample_table - This will only need to be changed if you have edited the name of your annotation files
- output_dir - This is probably the directory you are currently in (or where you clone to pipeline files to). Use the command "pwd" to get the path of the directory you are in.
- sources - Like I mentioned in the annotation file section, those read1 and read2 columns now come into place. For paired end data, you'll need two entries per sample, with each entry pointing to the full path of the forward or reverse gzipped fastq file.

## Running the pipeline

Once everything is in place, running the pipeline is really easy. You will only need one command:

```
looper run PEPATAC_config.yaml
```

This should project a commands and tell you how many samples were submitted to the cluster. To check whether jobs are running and the status of jobs, use the command:

```
looper check PEPATAC_config.yaml
```

or to see how jobs are running on SLURM directly:

```
squeue -u ONYEN
```

## QC and moving files

##### Checking and resubmitting

As a reminder, to use any looper commands you need all the module and environmental variables loaded. If you have logged out of longleaf since running or submitting looper commands, make sure to rerun the "source" command for _PEPATACenv.sh_.

Once all jobs have finished, check to see whether all jobs have finished using:

```
looper check PEPATAC_config.yaml
```

You should see 0 failed jobs. In the event that you do see failed jobs, you can use the command:

```
looper rerun PEPATAC_config.yaml
```

to resubmit those jobs that failed. **You will not have to delete any files and the pipeline will not resubmit any samples that finished successfully**.

##### Producing QC stats tables and html outputs

To create a QC metadata table along with html outputs summarizing QC across samples in the run, you will need to use the command:

```
looper report PETATAC_config.yaml
```

There will be a number of files that cannot be generated during this step, meaning that you'll get the message _Not found_ at the end of running this command. **This is normal** and is due to the R script used during section not being fully completed.

One of the files that is output from this step, _"[analysisName]stats_summary.tsv"_ is used by the script that handles the copying of files to permanent space.

##### Copying files to permanent space

To move your files from scratch space to the data directory, you can use the script _pepatacPostMove.py_, which is located in the labs' bin directory. The script takes 3/4 arguments:

- The stats.summary.tsv files generated from the "looper report" step
- A column that points to where the fastq files are located (This will almost always be 'read1')
- The genome build used in this run
- the flag '--run' when you're ready to initiate copying

Before we potentially copy over TBs of data, lets make sure the copy commands look right by **not** including the '--run' flag.

```
module load python/3.6.6
python /proj/fureylab/bin/pepatacPostMove.py -i [analysisName]stats_summary.tsv -r read1 -g hg38
```

This will print the commands that would be executed if the '--run' flag was added. When everything looks good, add '--run':

```
python /proj/fureylab/bin/pepatacPostMove.py -i [analysisName]stats_summary.tsv -r read1 -g hg38 --run
```

If you need more information about how to format the command or the inputs you need, you can use the command:

```
python /proj/fureylab/bin/pepatacPostMove.py -h
```

**NOTE:** When processing 10+ samples through this command, submit this command through SLURM as it may take a little while to run. This could be formatted like the below command:

```
module load python/3.6.6
sbatch -o sampleMove.out -t 1-0 --wrap="/proj/fureylab/bin/pepatacPostMove.py \
-i [analysisName]stats_summary.tsv -r read1 -g hg38 --run"
```

FURTHER DOCUMENTATION TO COME! -Ben
