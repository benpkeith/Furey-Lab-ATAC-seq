# Ben Keith
# Last updated 2020.06.09
# Furey Lab Pipeline 2020
# Snakemake 1.1

########################
#### Initial set up ####
########################

import os
import glob
import re
import sys
import os.path
import numpy
from os import path
from datetime import date

configfile: "postProcessing_config.yaml"
configFilename = "postProcessing_config.yaml"
today = date.today()
baseDir = os.getcwd()

samples = config["samples"]
conditions = config["conditions"]
genomeBuild = config["genomeBuild"]

# check number of samples to use as threshold from lowest sample number conditions
conditionNp = numpy.array(conditions)
unique_elements, counts_elements = numpy.unique(conditionNp, return_counts=True)
minCondition = min(counts_elements)

#creating soft-links to Files and directories

os.makedirs("post-processing/temp/coverage", exist_ok=True)
os.makedirs("post-processing/peakFiles", exist_ok=True)
os.makedirs("post-processing/countMatrices", exist_ok=True)

if config["moveOut"]:
    projectDir = "%s/%s" % (config["projectDir"], config["projectName"])
    os.makedirs(projectDir, exist_ok=True)
    print("Moving project files to " + projectDir)

    os.system("cp -rf post-processing/countMatrices %s; \
              cp -rf post-processing/peakFiles %s; \
              cp -rf post-processing/logs %s; \
              cp %s %s" % \
              (projectDir, projectDir, projectDir, configFilename, projectDir))

    if config["post-PEPATAC"]:
        os.system("cp -rf %s* %s" % (config["projectName"], projectDir))
        os.system("cp -rf submission %s/PEPATAC_submission" % projectDir)

    print("Files moved! Exiting...")
    print("The SystemExit message below this is normal!")
    sys.exit()

for i in range(0,len(samples)):
    if config["post-PEPATAC"]:
        os.makedirs("post-processing/temp/%s" % conditions[i], exist_ok=True)
        os.makedirs("post-processing/logs/%s" % samples[i], exist_ok=True)
        os.system("ln -s %s/results_pipeline/%s/peak_calling_%s/%s_peaks_rmBlacklist.narrowPeak post-processing/temp/%s >/dev/null 2>&1" \
          % (baseDir, samples[i], genomeBuild, samples[i], conditions[i]))
        os.system("ln -s %s/results_pipeline/%s/aligned_%s_exact/%s_shift.bed post-processing/temp/coverage >/dev/null 2>&1"\
          % (baseDir, samples[i], genomeBuild, samples[i]))
    else:
        samplePath = samples[i]
        samplePath = re.sub(r"\W+$", "", samplePath)
        sample = samplePath.rsplit('/', 1)[1]

        os.makedirs("post-processing/temp/%s" % conditions[i], exist_ok=True)
        os.makedirs("post-processing/logs/%s" % sample, exist_ok=True)

        os.system("ln -s %s/pepatac_%s/out/peak_calling_%s/%s_peaks_rmBlacklist.narrowPeak post-processing/temp/%s >/dev/null 2>&1" \
          % (samplePath, genomeBuild, genomeBuild, sample, conditions[i]))
        os.system("ln -s %s/pepatac_%s/out/aligned_%s_exact/%s_shift.bed post-processing/temp/coverage >/dev/null 2>&1"\
          % (samplePath, genomeBuild, genomeBuild, sample))

if not (config["post-PEPATAC"]):
    samplePaths = config["samples"]
    samplePaths = [re.sub(r"\W+$", "", i) for i in samplePaths]
    samples = [i.rsplit('/', 1)[1] for i in samplePaths]

rule all:
    input:
        expand("post-processing/temp/{condition}/{sample}_peaks_rmBlacklist.fixed.narrowPeak.cut.named",
          zip, sample = samples, condition = conditions),
        expand("post-processing/peakFiles/{condition}.peaks.bed", condition = conditions),
        expand("post-processing/temp/coverage/{sample}_shift.fixed.bed",
          sample = samples),
        "post-processing/peakFiles/peaks.300bp.bed",
        expand("post-processing/logs/{sample}/coverageSubmitted_done.flag",
          sample = samples),
        "post-processing/logs/countMatSubmitted_done.flag"


rule fixNarrowPeak:
    input:
        "post-processing/temp/{condition}/{sample}_peaks_rmBlacklist.narrowPeak"
    output:
        "post-processing/temp/{condition}/{sample}_peaks_rmBlacklist.fixed.narrowPeak"
    shell:
        """
        egrep -v 'chr\w{{1,2}}_' {input} > {output}
        """


rule fixBed:
    input:
        "post-processing/temp/coverage/{sample}_shift.bed"
    output:
        "post-processing/temp/coverage/{sample}_shift.fixed.bed"
    params:
        temp = "post-processing/temp/coverage/{sample}_shift.temp.bed"
    shell:
        """
        egrep -v 'chr\w{{1,2}}_' {input} > {params.temp}
        python /proj/fureylab/bin/ppATAC_bedFix.py {params.temp} {output}
        """

rule extractName:
    input:
        "post-processing/temp/{condition}/{sample}_peaks_rmBlacklist.fixed.narrowPeak"
    output:
        "post-processing/temp/{condition}/{sample}_peaks_rmBlacklist.fixed.narrowPeak.cut.named"
    params:
        cut = "post-processing/temp/{condition}/{sample}_peaks_rmBlacklist.fixed.narrowPeak.cut"
    shell:
        """
        cut -f1-3 {input} > {params.cut}
        awk 'BEGIN {{ FS = OFS = "\t"}} {{$4 = "{wildcards.sample}"; print}}' {params.cut} > {output}
        """

rule conditionPeakSets:
    input:
        expand("post-processing/temp/{condition}/{sample}_peaks_rmBlacklist.fixed.narrowPeak.cut.named",
          zip, sample = samples, condition = conditions),
        dir = "post-processing/temp/{condition}"
    output:
        "post-processing/peakFiles/{condition}.peaks.bed"
    params:
        sampleCutoff = minCondition * config["sampleCutoff"]
    shell:
        """
        module load bedtools/2.29
        #combine
        cat {input.dir}/*.cut.named > {input.dir}/{wildcards.condition}.cat.npf

        #sort
        sortBed -i {input.dir}/{wildcards.condition}.cat.npf \
          > {input.dir}/{wildcards.condition}.cat.sorted.bed

        #merge
        mergeBed -i {input.dir}/{wildcards.condition}.cat.sorted.bed -c 4 -o distinct \
          > {input.dir}/{wildcards.condition}.union.bed

        #peakCount
        awk 'BEGIN {{ FS = OFS = "\t"}} {{print $1,$2,$3,gsub(/,/,$4)+1}}' {input.dir}/{wildcards.condition}.union.bed \
          > {input.dir}/{wildcards.condition}.union.unique.bed

        #peakFilter
        awk '(NR>0) && ($4 >= {params.sampleCutoff})' {input.dir}/{wildcards.condition}.union.unique.bed \
          | cut -f1-3 > post-processing/peakFiles/{wildcards.condition}.peaks.bed
        """

rule finalPeakSets:
    input:
        expand("post-processing/peakFiles/{condition}.peaks.bed",
          condition = conditions)
    output:
        "post-processing/peakFiles/peaks.300bp.bed",
        "post-processing/peakFiles/peaks.300bp.promoter.bed",
        "post-processing/peakFiles/peaks.300bp.distal.bed",
        "post-processing/peakFiles/peaks.bed",
        "post-processing/peakFiles/peaks.promoter.bed",
        "post-processing/peakFiles/peaks.distal.bed"
    params:
        genomeBuild = config["genomeBuild"]
    shell:
        """
        module load bedtools/2.29
        module load r/3.6.0

        #merge conditions, sort bed, merge bed
        cat post-processing/peakFiles/*.peaks.bed | uniq > post-processing/temp/union.filtered.bed
        sortBed -i post-processing/temp/union.filtered.bed > post-processing/temp/union.filtered.sorted.bed
        mergeBed -i post-processing/temp/union.filtered.sorted.bed \
          > post-processing/peakFiles/peaks.bed

        #peak Annotation
        Rscript /proj/fureylab/bin/ppATAC_peakAnnotation.R \
          post-processing/peakFiles/peaks.bed -g {params.genomeBuild}

        #300bp windows
        python /proj/fureylab/bin/ppATAC_windowing.py post-processing/peakFiles/peaks.bed \
          post-processing/peakFiles/peaks.300bp.bed
        python /proj/fureylab/bin/ppATAC_windowing.py post-processing/peakFiles/peaks.promoter.bed \
          post-processing/peakFiles/peaks.300bp.promoter.bed
        python /proj/fureylab/bin/ppATAC_windowing.py post-processing/peakFiles/peaks.distal.bed \
          post-processing/peakFiles/peaks.300bp.distal.bed
        """

rule coverageFiles:
    input:
        bed = "post-processing/temp/coverage/{sample}_shift.fixed.bed",
        peaks300 = "post-processing/peakFiles/peaks.300bp.bed",
        peaks300P = "post-processing/peakFiles/peaks.300bp.promoter.bed",
        peaks300D = "post-processing/peakFiles/peaks.300bp.distal.bed",
        peaks = "post-processing/peakFiles/peaks.bed",
        peaksP = "post-processing/peakFiles/peaks.promoter.bed",
        peaksD = "post-processing/peakFiles/peaks.distal.bed"
    output:
        touch("post-processing/logs/{sample}/coverageSubmitted_done.flag")
    shell:
        """
        module load bedtools/2.29
        #300bp coverage
        sbatch --mem 75G --time 2-0 -J winCovMatP \
          -o post-processing/logs/{wildcards.sample}/covP.win.out \
          --wrap="bedtools coverage -counts -b {input.bed} -a {input.peaks300} \
          > post-processing/temp/coverage/{wildcards.sample}.coverage.300bp.promoter.bed"
        sbatch --mem 75G --time 2-0 -J winCovMatD \
          -o post-processing/logs/{wildcards.sample}/covD.win.out \
          --wrap="bedtools coverage -counts -b {input.bed} -a {input.peaks300P} \
          > post-processing/temp/coverage/{wildcards.sample}.coverage.300bp.distal.bed"
        sbatch --mem 75G --time 2-0 -J winCovMat \
          -o post-processing/logs/{wildcards.sample}/cov.win.out \
          --wrap="bedtools coverage -counts -b {input.bed} -a {input.peaks300D} \
          > post-processing/temp/coverage/{wildcards.sample}.coverage.300bp.bed"

        #peak level coverage
        sbatch --mem 75G --time 2-0 -J peakCovMatP \
          -o post-processing/logs/{wildcards.sample}/covP.peak.out \
          --wrap="bedtools coverage -counts -b {input.bed} -a {input.peaks} \
          > post-processing/temp/coverage/{wildcards.sample}.coverage.peak.promoter.bed"
        sbatch --mem 75G --time 2-0 -J peakCovMatD \
          -o post-processing/logs/{wildcards.sample}/covD.peak.out \
          --wrap="bedtools coverage -counts -b {input.bed} -a {input.peaksP} \
          > post-processing/temp/coverage/{wildcards.sample}.coverage.peak.distal.bed"
        sbatch --mem 75G --time 2-0 -J peakCovMat \
          -o post-processing/logs/{wildcards.sample}/cov.peak.out \
          --wrap="bedtools coverage -counts -b {input.bed} -a {input.peaksD} \
          > post-processing/temp/coverage/{wildcards.sample}.coverage.peak.bed"
        """

rule countMatrix:
    input:
        expand("post-processing/logs/{sample}/coverageSubmitted_done.flag",
          sample = samples)
    output:
        touch("post-processing/logs/countMatSubmitted_done.flag")
    shell:
        """
        module load python/2.7.12

        #300bp matrices
        sbatch -J winCovMatP --dependency=singleton \
          -o post-processing/logs/countMatrix_300bp_promoter.out --mem=50G -t 02:00:00 \
          --wrap="python /proj/fureylab/bin/ppATAC_countMat.py \
          'post-processing/temp/coverage/*.coverage.300bp.promoter.bed' \
          post-processing/countMatrices/counts.300bp.promoter.txt"
        sbatch -J winCovMatD --dependency=singleton \
          -o post-processing/logs/countMatrix_300bp_distal.out --mem=50G -t 02:00:00 \
          --wrap="python /proj/fureylab/bin/ppATAC_countMat.py \
          'post-processing/temp/coverage/*.coverage.300bp.distal.bed' \
          post-processing/countMatrices/counts.300bp.distal.txt"
        sbatch -J winCovMat --dependency=singleton \
          -o post-processing/logs/countMatrix_300bp_all.out --mem=50G -t 02:00:00 \
          --wrap="python /proj/fureylab/bin/ppATAC_countMat.py \
          'post-processing/temp/coverage/*.coverage.300bp.bed' \
          post-processing/countMatrices/counts.300bp.all.txt"

        #peak level matrices
        sbatch -J peakCovMatP --dependency=singleton \
          -o post-processing/logs/countMatrix_peaks_promoter.out --mem=50G -t 02:00:00 \
          --wrap="python /proj/fureylab/bin/ppATAC_countMat.py \
          'post-processing/temp/coverage/*.coverage.peak.promoter.bed' \
          post-processing/countMatrices/counts.peaks.promoter.txt"
        sbatch -J peakCovMatD --dependency=singleton \
          -o post-processing/logs/countMatrix_peaks_distal.out --mem=50G -t 02:00:00 \
          --wrap="python /proj/fureylab/bin/ppATAC_countMat.py \
          'post-processing/temp/coverage/*.coverage.peak.distal.bed' \
          post-processing/countMatrices/counts.peaks.distal.txt"
        sbatch -J peakCovMat --dependency=singleton \
          -o post-processing/logs/countMatrix_peaks_all.out --mem=50G -t 02:00:00 \
          --wrap="python /proj/fureylab/bin/ppATAC_countMat.py \
          'post-processing/temp/coverage/*.coverage.peak.bed' \
          post-processing/countMatrices/counts.peaks.all.txt"
        """
