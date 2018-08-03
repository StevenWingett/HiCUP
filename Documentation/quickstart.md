---
layout: page
title: Quick Start
permalink: /quickstart/
---

##HiCUP Quick Start Guide

HiCUP is a bioinformatics pipeline for processing Hi-C data. The pipeline maps FASTQ data against a reference genome and filters out frequently encountered experimental artefacts. The pipeline produces paired-read files in SAM/BAM format, each read pair corresponding to a putative Hi-C di-tag. HiCUP also produces summary statistics at each stage of the pipeline providing quality control, helping pinpoint potential problems and refine the experimental protocol.

###Requirements

HiCUP should work on most Linux-based operating systems. It requires a working version of [Perl](http://www.perl.org) and uses [Bowtie](http://bowtie-bio.sourceforge.net) or [Bowtie2](http://bowtie-bio.sourceforge.net/bowtie2) to perform the mapping.  

Full functionality requires [R](http://www.r-project.org) (tested with version 3.1.2) and [SAM tools]( http://sourceforge.net/projects/samtools) (version 0.1.18 or later).

Memory requirements depend on the size of the input files, but as a rough guide allocating 2Gb of RAM per file processed simultaneously (defined by --threads argument) should suffice.

###Installation

HiCUP is written in Perl and executed from the command line. To install HiCUP download the hicup_v0.X.Y.tar.gz file and extract all files by typing:

    tar -xvzf hicup_v0.X.Y.tar.gz

Check after extracting that the Perl scripts are executable by **all**, which can be achieved with the command:

    chmod a+x [files] 

###Running HiCUP

####1) Create Aligner Indices
HiCUP uses the aligner Bowtie or Bowtie2 to map sequences to a reference genome, requiring the construction of genome index files. These indices **MUST** be constructed from the same reference genome files as used by the HiCUP Digester script.

On the command line enter ‘bowtie-build’ (or bowtie2-build) to construct the indices, followed by a comma-separated list of the sequence files and then a space followed by the name of the output indices:  

    bowtie-build 1.fa,2.fa,...,MT.fa Human_GRCh37

    bowtie2-build 1.fa,2.fa,...,MT.fa Human_GRCh37

Refer to the [Bowtie](http://bowtie-bio.sourceforge.net/manual.shtml#the-bowtie-build-indexer) or [Bowtie2](http://bowtie-bio.sourceforge.net/bowtie2/manual.shtml#the-bowtie2-build-indexer) manuals for further guidance.

####2) Create a digested reference genome

To filter out common experimental artefacts, HiCUP requires the positions at which the restriction enzyme(s) used in the protocol cut the genome. The script HiCUP Digester creates this reference genome digest file. The example below performs an *in silico* HindIII digest of all DNA sequences contained within the files in the current working directory suffixed with ‘.fa’.  The digest output file will be labelled as the genome ‘Human_GRCh37’. Provide the full path to HiCUP Digester or the sequence files to be digested if they are not in the current working directory.  

Execute the script:  

    hicup_digester --genome Human_GRCh37 --re1 A^AGCTT,HindIII *.fa

The argument '--re1' specifies the restriction enzyme used to digest the genome (a caret symbol '^' is used to denote the restriction enzyme cut site, and a comma separates the DNA sequence from the restriction enzyme name).  The argument '--genome' is for specifying the name of the genome to be digested, it is **NOT** used to specify the path to the genome aligner indices.

*Hi-C Protocol Variations: some Hi-C protocols may use two restriction enzymes at this stage (i.e. the creation of the initial Hi-C interaction). To specify two enzymes use the nomenclature: --re1 A^GATCT,BglII:A^AGCTT,HindIII*

####3) Run the HiCUP Pipeline

Create an example HiCUP configuration file in your current working directory:

    hicup --example

Use a text editor to edit the configuration file as required, such as in the following example:

    #Directory to which output files should be 
    #written (optional parameter)
    #Set to current working directory by default 
    Outdir:
    
    #Number of threads to use
    Threads: 1

    #Suppress progress updates (0: off, 1: on)
    #Quiet:0

    #Retain intermediate pipeline files (0: off, 1: on)
    Keep:0

    #Compress outputfiles (0: off, 1: on)
    Zip:1

    #Path to the alignment program (Bowtie or Bowtie2)
    #Remember to include the executable Bowtie/Bowtie2 filename.
    #Note: ensure you specify the correct aligner i.e. 
    #Bowtie when using Bowtie indices, or Bowtie2 when using Bowtie2 indices.
    #In the example below Bowtie2 is specified.
    Bowtie2: /usr/local/bowtie2/bowtie2

    #Path to the reference genome indices
    #Remember to include the basename of the genome indices
    Index: /data/public/Genomes/Mouse/NCBIM37/Mus_musculus.NCBIM37

    #Path to the genome digest file produced by hicup_digester
    Digest: Digest_Mouse_genome_HindIII_None_12-32-06_17-02-2012.txt

    #FASTQ format (valid formats: 'Sanger', 'Solexa_Illumina_1.0',

    #'Illumina_1.3' or 'Illumina_1.5'). If not specified, HiCUP will 
    #try to determine the format automatically by analysing one of 
    #the FASTQ files. All input FASTQ will assumed to be in that 
    #format.
    Format: Sanger 

    #Maximum di-tag length (optional parameter)
    Longest: 800

    #Minimum di-tag length (optional parameter)
    Shortest: 150

    #FASTQ files to be analysed, placing paired files on adjacent lines
    s_1_1_sequence.txt
    s_1_2_sequence.txt

    s_2_1_sequence.txt
    s_2_2_sequence.txt

    s_3_1_sequence.txt.gz
    s_3_2_sequence.txt.gz

Rename the configuration file if desired.

Enter the following text in the command line to run the whole HiCUP pipeline using the parameters specified in the configuration file:

    hicup --config [Configuration Filename]

The --config flag is used to specify the configuration filename.  Also, remember to provide the full path to the HiCUP script and/or the configuration file if they are not in the current working directory.  

*Please Note: HiCUP attempts to intelligently name files as the pipeline proceeds, so avoid passing HiCUP input files with identical names prior to the filename extension.  For example, the files 'sample.fa' and 'sample.fastq' would produce files with identical names as the pipeline progresses.  This problem could be overcome by renaming one the files to 'sample2.fa'.   To minimise inconvenience, HiCUP will immediately produce a warning message and not run if the input filenames are too similar.*

####4) Output

The pipeline produces paired-read BAM files representing the filtered di-tags. HiCUP also generates an HTML summary report for each sample and a text file summarising every sample processed. Summary text files and SVG-format charts are also created at each step along the pipeline.

The 'Conversion' folder within the main HiCUP directory contains Perl scripts to convert HiCUP BAM/SAM files into a format compatible with other analysis tools. Executing one of these files with the command line argument --help prints instructions on how to use the conversion script. 

**Bugs should be reported at:**
**[Bugzilla](http://www.bioinformatics.babraham.ac.uk/bugzilla)**

**We welcome your comments or suggestions, please email them to:**
**steven.wingett@babraham.ac.uk**
