---
layout: page
title: Test Dataset
permalink: /test_dataset/
---

#Processing the Test Dataset
To confirm HiCUP functions correctly on your system please download the [Test Hi-C dataset](http://www.bioinformatics.babraham.ac.uk/projects/hicup/test_dataset.tar.gz).  The test files 'test_dataset1.fastq'  and 'test_dataset2.fastq' both contain human Hi-C reads in Sanger FASTQ format. 

**1) Extract the tar archive before processing:**

    tar -xvzf hicup_v0.X.Y.tar.gz

**2)  If necessary, create Bowtie/Bowtie indices of the Homo sapiens GRCh37 genome (chromosomes 1,...,22, X, Y and MT).**

Example commands:

    bowtie-build 1.fa,2.fa,...,MT.fa human_GRCh37

    bowtie2-build 1.fa,2.fa,...,MT.fa human_GRCh37

**3) Using HiCUP Digester create a reference genome of Homo sapiens GRCh37 all chromosomes (1,...,22, X, Y and MT) digested with HindIII (A^AGCTT).**

Example command:

    hicup_digester --genome Human_GRCh37 --re1 A^AGCTT,HindIII *.fa

**4) Edit a copy of the hicup.conf configuration file so it has the following parameters:**

    Zip: 1
    Keep: 0
    Threads: 1
    Bowtie: [Path to Bowtie on your system, if using this aligner]
    Bowtie2: Path to Bowtie2 on your system, if using this aligner]
    Digest: [Path to digest file on your system]
    Index: [Path to Bowtie/Bowtie2 indices on your system]
    R: [Path to R on your system]
    Format: phred33-quals
    Shortest: 150
    Longest: 800
    test_dataset1.fastq
    test_dataset2.fastq

**5) Run the pipeline:**

Execute HiCUP with the command:

    hicup --config [Configuration Filename]