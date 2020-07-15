package hicup_module;
require Exporter;

our @ISA    = qw (Exporter);
our @EXPORT = qw(VERSION hasval deduplicate_array checkR process_config check_files_exist
  datestampGenerator print_example_config_file fileNamer arrayAppend versioner calc_perc cutsite_deduce);

our @EXPORT_OK = qw(hashVal outdirFileNamer check_no_duplicate_filename check_filenames_ok 
    checkAligner checkAlignerIndices newopen quality_checker determineAlignerFormat get_csome_position);

our $VERSION = "0.7.5.dev";

use Data::Dumper;
use strict;
use warnings;
use File::Basename;
use FindBin '$Bin';
use lib $Bin;

###################################################################################
###################################################################################
##This file is Copyright (C) 2020, Steven Wingett (steven.wingett@babraham.ac.uk)##
##                                                                               ##
##                                                                               ##
##This file is part of HiCUP.                                                    ##
##                                                                               ##
##HiCUP is free software: you can redistribute it and/or modify                  ##
##it under the terms of the GNU General Public License as published by           ##
##the Free Software Foundation, either version 3 of the License, or              ##
##(at your option) any later version.                                            ##
##                                                                               ##
##HiCUP is distributed in the hope that it will be useful,                       ##
##but WITHOUT ANY WARRANTY; without even the implied warranty of                 ##
##MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                  ##
##GNU General Public License for more details.                                   ##
##                                                                               ##
##You should have received a copy of the GNU General Public License              ##
##along with HiCUP.  If not, see <http://www.gnu.org/licenses/>.                 ##
###################################################################################
###################################################################################

#########################################################
#A collection of Perl subroutines for the HiCUP pipeline#
#########################################################

###############################################################
#Sub: get_version
#Returns the version number of HiCUP
sub get_version {
    return $VERSION;
}

###############################################################
#Sub: hasval
#Takes a string and returns true (i.e. '1') if the string has a value
#(i.e. is not equal to nothing (''). This is useful since some
#variables may be set to nothing allowing them to be evaluated
#without initialisation errors, while simultaneously containing
#no information.
sub hasval {
    if ( $_[0] ne '' ) {
        return 1;
    } else {
        return 0;
    }
}

###############################################################
#Sub: hashVal
#Takes a hash and returns 1 if any of the hash's keys has a
#value ne '' associated with it, else returns 0
sub hashVal {
    my %hash       = @_;
    my $valueFound = 0;

    foreach my $key ( keys %hash ) {
        $valueFound = 1 if hasval( $hash{$key} );
    }
    return $valueFound;
}

#Sub: deduplicate_array
#Takes and array and returns the array with duplicates removed
#(keeping 1 copy of each unique entry).
sub deduplicate_array {
    my @array = @_;
    my %uniques;

    foreach (@array) {
        $uniques{$_} = '';
    }
    my @uniques_array = keys %uniques;
    return @uniques_array;
}

#Sub: checkR
#Takes the config hash and and modifies $config{r} directly
#Script returns '0' if no path to R found
#The script checks whether the user specified path to R is valid and if
#not tries to locate R automatically
sub checkR {

    my $configHashRef = $_[0];

    return if ( $$configHashRef{r} eq '0' );    #Already determined R not present, so don't repeat warnings

    if ( hasval( $$configHashRef{r} ) ) {       #Check whether user specified a path
        if ( -e $$configHashRef{r} ) {          #Check if R path exists

            #Check R runs
            my $versionR = `$$configHashRef{r} --version 2>/dev/null`;
            unless ( $versionR =~ /^R version/ ) {
                warn "R not found at '$$configHashRef{r}'\n";
                $$configHashRef{r} = '';
            }

        } else {
            warn "'$$configHashRef{r}' is not an R executable file\n";
            $$configHashRef{r} = '';
        }
    }

    unless ( hasval $$configHashRef{r} ) {
        warn "Detecting R automatically\n";
        if ( !system "which R >/dev/null 2>&1" ) {
            $$configHashRef{r} = `which R`;
            chomp $$configHashRef{r};
            warn "Found R at '$$configHashRef{r}'\n";
        } else {
            warn "Could not find R (www.r-project.org), please install if graphs are required\n";
            $$configHashRef{r} = 0;    #Tells later scripts that R is not installed
        }
    }
}

#Sub: outdirFileNamer
#Takes an array of filenames as a reference and the output file directory name/path
#returns a hash of %{path/filename} = outdir/filename
sub outdirFileNamer {
    my $fileArrayRef = $_[0];    #Passed by reference
    my $outdir       = $_[1];
    my %inOutFilenames;

    $outdir .= '/' unless ( $outdir =~ /\/$/ );    #Ensure outdir ends with forward slash

    foreach my $file (@$fileArrayRef) {
        my @elements = split( '/', $file );
        my $outFile = $outdir . $elements[-1];
        $inOutFilenames{$file} = $outFile;
    }
    return %inOutFilenames;
}

#Subroutine: arrayAppend
#Takes a reference to an array and a scalar variable and returns a array with the string variable with
#prefixes to the start of every element of the array.
#This is useful if wanting to prefix the output directory to every filename stored in an array
sub arrayAppend {
    my $array_ref = $_[0];
    my $prefix    = $_[1];

    my @output_array;

    foreach my $element (@$array_ref) {
        push( @output_array, $prefix . $element );
    }
    return @output_array;
}

############################
#Subroutine "process_config":
#Takes i) configuration file name and ii) %config hash (as a reference).
#The script then uses the configuration file to populate the hash as
#appropriate. Parameters passed via the command line take priority
#over those defined in the configuration file.
#The script modifies the hash directly, but returns as a hash the filename pairs (i.e the
#lines in the configuration #file that could did not correspond configuration parameters
#Each file is on a separate line with pairs on adjacent lines, or a pair may be placed on
#the same line separated by pipe ('\')
sub process_config {
    my ( $config_file, $config_hash_ref ) = @_;
    my @non_parameters;    #Stores lines in the configuration file not defined as parameters

    #Open configuration file
    open( CONF, "$config_file" ) or die "Can't read $config_file: $!";

    while (<CONF>) {

        my $line = $_;
        chomp $line;
        $line =~ s/^\s+//;
        $line =~ s/\s+$//;    #Remove starting/trailing white spaces

        next if $line =~ /^\s*\#/;    #Ignore comments
        next if $line =~ /^\s*$/;     #Ignore whitespace

        #Check if this is a parameter
        my ( $parameter, $setting ) = split( /:/, $line );
        $parameter =~ s/^\s+//;
        $parameter =~ s/\s+$//;       #Remove starting/trailing white spaces
        $parameter = lc $parameter;
        $setting =~ s/^\s+// if defined($setting);
        $setting =~ s/\s+$// if defined($setting);    #Remove starting/trailing white spaces

        if ( exists $$config_hash_ref{$parameter} ) {
            if ( $$config_hash_ref{$parameter} eq '' ) {    #Check parameter not assigned value in command line
                $$config_hash_ref{$parameter} = $setting;    #Edit the configuration hash
            }
        } else {
            my @lineElements = split( /\|/, $line );         #There may be a pipe separating two files
            foreach my $element (@lineElements) {
                $element =~ s/^\s+//;
                $element =~ s/\s+$//;                        #Remove starting/trailing white spaces
                push( @non_parameters, $element );
            }
        }
    }
    close CONF or die "Could not close filhandle on configuration file: '$config_file'\n";
    
    return @non_parameters;
}

# Subroutine: check_filenames_ok
# Receives an array of filename pairs delimited by comma ','
# Checks the files exist and returns a hash of %{forward file} = reverse file1F
sub check_filenames_ok {
    my @files = @_;
    my %paired_filenames;

    foreach (@files) {
        my @file_combination = split /,/;
        if ( scalar @file_combination != 2 ) {
            die "Files need to be paired in the configuration file an/or command-line, see hicup --help for more details.\n";
        }

        foreach my $file (@file_combination) {
            if ( $file eq '' ) {
                die "Files need to be paired in the configuration file and/or command-line, see hicup --help for more details.\n";
            }
            $file =~ s/^\s+//;    #Remove white space at start and end
            $file =~ s/\s+$//;
        }
        $paired_filenames{ $file_combination[0] } = $file_combination[1];
    }
    return %paired_filenames;
}

# Subroutine: check_filenames_ok
# Receives a hash of filename pairs %{forward file} = reverse file1F
# Checks that no filename occurs more than once, irrespective of path
sub check_no_duplicate_filename {
    my %filePair = @_;
    my %uniqueNames;
    my %duplicateNames;    #Write here names that occurred multiple times
    my $ok = 1;            #Is the configuration acceptable?

    foreach my $key ( keys %filePair ) {
        my $fileF = ( split( /\//, $key ) )[-1];
        my $fileR = $filePair{$key};
        $fileR = ( split( /\//, $fileR ) )[-1];

        foreach my $file ( $fileF, $fileR ) {
            if ( exists $uniqueNames{$file} ) {
                $duplicateNames{$file} = '';
                $ok = 0;
            } else {
                $uniqueNames{$file} = '';
            }
        }
    }

    unless ($ok) {
        foreach my $duplicateName ( keys %duplicateNames ) {
            warn "Filename '$duplicateName' occurs multiple times\n";
        }
    }

    return $ok;
}

# Subroutine: checkAligner
# Receives the config hash and determines whether the specified aligners
# are present, if not the aligners are searched for automatically and
# the config hash is adjusted accordingly
# Returns 1 if successful or 0 if no valid aligner found
sub checkAligner {

    my $configRef     = $_[0];
    my @aligners      = ( 'bowtie', 'bowtie2' );    #List of aligners used by HiCUP
    my $parameters_ok = 1;

    #Check which aligner specified
    my $found_aligner_flag = 0;
    my $aligner_count      = 0;
    foreach my $aligner_name (@aligners) {
        if ( hasval( $$configRef{$aligner_name} ) ) {
            $$configRef{aligner} = $aligner_name;
            $aligner_count++;
        }
    }

    #Validate user input
    if ( $aligner_count > 1 ) {    #Too many aligners specified (i.e. more than 1)
        warn "Please only specify only one aligner: either --bowtie or --bowtie2.\n";
        $parameters_ok = 0;
    }

    if ( ( $aligner_count == 0 ) ) {    #Find an aligner if none specified
        warn "No aligner specified, searching for aligner\n";
        foreach my $aligner_name (@aligners) {
            if ( !system "which $aligner_name >/dev/null 2>&1" ) {
                my $aligner_path = `which $aligner_name`;
                chomp $aligner_path;
                warn "Path to $aligner_name found at: $aligner_path\n";
                $found_aligner_flag        = 1;
                $$configRef{$aligner_name} = $aligner_path;
                $$configRef{aligner}       = $aligner_name;
                last;
            } else {
                warn "Could not find path to '$aligner_name'\n";
            }
        }
    }
 	
 	#Correct number (i.e. one) of aligners specified, check path correct
	my $aligner_name = $$configRef{aligner};
	my $aligner_path = $$configRef{$aligner_name};

    if(-e $aligner_path){         #Check file present at this path
    	$found_aligner_flag = 1;
    }else{
    	warn "Aligner not found at '$aligner_path'\n";
    	$aligner_path =~ s/\/$//;    #Remove final '/' from path, if present
    	$aligner_path = $aligner_path . '/' . $aligner_name;
    	warn "Looking for aligner at '$aligner_path'\n";
    	if(-e $aligner_path){
    		warn "Aligner found at '$aligner_path'\n";
    		$$configRef{$aligner_name} = $aligner_path;    #Adjust config hash accordingly
    		$found_aligner_flag = 1
    	}else{
    		warn "Aligner not found at '$aligner_path'\n";
    	}
    }

    unless ($found_aligner_flag) {        #Try to find aligner automatically
        warn "Trying to find '$aligner_name' automatically\n";
        if ( !system "which $aligner_name >/dev/null 2>&1" ) {
            $aligner_path = `which $aligner_name`;
            chomp $aligner_path;
            warn "Path to '$aligner_name' found at: '$aligner_path'\n";
            $$configRef{$aligner_name} = $aligner_path;    #Adjust config hash accordingly
            $found_aligner_flag = 1;
        } else {
            warn "Could not find $aligner_name at '$aligner_path'\n";
        }
    }
    
    #Perform other checks
    if($found_aligner_flag) {
    	unless(-x $aligner_path){    #Check executable
    		warn "Aligner at '$aligner_path' is not executable\n";
    		$parameters_ok = 0;
    	}

    	my $deduced_name = basename($aligner_path);
    	unless( (lc $deduced_name) eq (lc $aligner_name) ){
    		warn "Expecting aligner '$aligner_name', but path is to '$aligner_path'\n";
    		warn "Which is correct '$aligner_name' or '$deduced_name'?\n";
    		$parameters_ok = 0;
    	}

    }else{    #No aligners found
        warn "Please specify a link to one valid aligner\n";
        $parameters_ok = 0;
    }

    if ( $$configRef{ambiguous} ) {
        unless ( hasval( $$configRef{bowtie2} ) ) {
            warn "Option 'ambiguous' is only compatible wtih Bowtie2\n";
            $parameters_ok = 0;
        }
    }
    return $parameters_ok;
}

# Subroutine: checkAlignerIndices
# Receives the config hash and determines whether the specified indices
# are present.
# Returns 1 if successful or 0 if no valid aligner found
sub checkAlignerIndices {
    my $configRef     = $_[0];
    my $parameters_ok = 1;

    #Check the index files exist
    if ( hasval $$configRef{index} ) {
        my @index_suffixes;
        if ( $$configRef{aligner} eq 'bowtie' ) {
            @index_suffixes = ( '.1.ebwt', '.2.ebwt', '.3.ebwt', '.4.ebwt', '.rev.1.ebwt', '.rev.2.ebwt' );
        } elsif ( $$configRef{aligner} eq 'bowtie2' ) {
            @index_suffixes = ( '.1.bt2', '.2.bt2', '.3.bt2', '.4.bt2', '.rev.1.bt2', '.rev.2.bt2' );
        }

        foreach my $suffix (@index_suffixes) {
            my $indexFilename = $$configRef{index} . $suffix;
            unless ( ( -e $indexFilename ) or ( -e $indexFilename . 'l' ) ) {    #Bowtie2 also has larger indices
                warn "$$configRef{aligner} index file '$indexFilename' does not exist\n";
                $parameters_ok = 0;
            }
        }
    } else {
        warn "Please specify alinger indices (--index)\n";
        $parameters_ok = 0;
    }
    return $parameters_ok;
}

###################################################################
#check_files_exist:
#Takes a reference to an array containing paths to filenames and verifies they exist
#Warns of files that do no exit. Returns 1 if all files exist but 0 if this is not
#the case.
#
#Also, takes a second argument:
#$_[1] should be 'EXISTS' or 'NOT_EXISTS'
#If 'NOT_EXIST' warns if file already exists.  Returns '1' if none of the
#files exists and '0' if one or multiple files already exist
sub check_files_exist {
    my $files      = $_[0];    #Reference to array
    my $check_for  = $_[1];
    my $all_exist  = 1;
    my $not_exists = 1;

    if ( $check_for eq 'EXISTS' ) {
        foreach my $file (@$files) {
            unless ( -e $file ) {
                warn "File '$file' does not exist\n";
                $all_exist = 0;
            }
        }
    } elsif ( $check_for eq 'NOT_EXISTS' ) {
        foreach my $file (@$files) {
            if ( -e $file ) {
                warn "File '$file' already exists\n";
                $not_exists = 0;
            }
        }
    } else {
        die "Subroutine 'check_files_exist' requires argument 'EXISTS' or 'NOT_EXISTS'.\n";
    }

    if ( $check_for eq 'EXISTS' ) {
        return $all_exist;
    } else {
        return $not_exists;
    }
}

#############################################################
#Subroutine datestampGenerator:
#Returns a suitably formatted datestamp
sub datestampGenerator {
    my @now       = localtime();
    my $datestamp = sprintf(
        "%02d-%02d-%02d_%02d-%02d-%04d",

        $now[2], $now[1],     $now[0],
        $now[3], $now[4] + 1, $now[5] + 1900
    );
	
	$datestamp = generateRandomString(10) . '_' . $datestamp;    #Add random string to datestamp
    return $datestamp;
}



#####################################
#Subroutine versioner
#Receives a string and then folder path(s)
#Subroutine checks whether the string appears in any filenames in the folders
#if so, it appends v1, v2, v3 etc. to the string, if not returns the string unchanged
#This subroutine in used with datestampGenerator to create unique datestamps
sub versioner{
    my $to_check = shift @_;
    my @folders;

    #Do not process undefined or folders named ''
    foreach my $folder (@_){
        next if !defined $folder;
        next if $folder eq '';
        push (@folders, $folder);
    }
   
    my $v_nos = 1;
    my $suffix = ''; 
    my $found_flag = 1;
  
    while(1){
        $found_flag = 0;
        foreach my $folder (@folders){
            my @found_files = glob("$folder*$to_check" . "$suffix*");
            if( (scalar @found_files) > 0 ){    #Files found
                $found_flag = 1;
            }
        }

        unless($found_flag){
            return $to_check.$suffix;
        }else{
            $suffix = '_v' . $v_nos;
            $v_nos++;
        }
    }
}



######################
#Subroutine "newopen":
#links a file to a filehandle
sub newopen {
    my $path = shift;
    my $fh;

    open( $fh, '>', $path ) or die "\nCould not create filehandles in subroutine \'newopen\'\n";

    return $fh;
}

##############################
#Subroutine 'quality_checker':
#determines the FASTQ format of a sequence file
#
#FASTQ FORMAT OVERVIEW
#---------------------
#Sanger: ASCII 33 to 126
#Sanger format can encode a Phred quality score from 0 to 93 using ASCII 33 to 126
#(although in raw read data the Phred quality score rarely exceeds 60, higher
#scores are possible in assemblies or read maps)
#
#Solexa/Illumina 1.0 format: ASCII 59 to 126
#-5 to 62 using ASCII 59 to 126 (although in raw read data Solexa scores from -5
#to 40 only are expected)
#
#Illumina 1.3 and before Illumina 1.8: ASCII 64 to 126
#the format encoded a Phred quality score from 0 to 62 using ASCII 64 to 126
#(although in raw read data Phred scores from 0 to 40 only are expected).
#
#Illumina 1.5 and before Illumina 1.8: ASCII 66 to 126
#the Phred scores 0 to 2 have a slightly different meaning. The values 0 and
#1 are no longer used and the value 2, encoded by ASCII 66 "B", is used also
#at the end of reads as a Read Segment Quality Control Indicator.
#
#phred64-quals:
#ASCII chars begin at 64
#
#Starting in Illumina 1.8, the quality scores have basically returned to
#Sanger format (Phred+33)
#
#solexa-quals: ASCII chars begin at 59
#integer-qual: quality values integers separated by spaces
sub quality_checker {
    my $file       = $_[0];
    my $score_min  = 999;     #Initialise at off-the-scale values
    my $read_count = 1;

    if ( $file =~ /\.gz$/ ) {
        open( IN, "zcat $file |" ) or die "Could not read file '$file' : $!";
    } else {
        open( IN, $file ) or die "Could not read file '$file' : $!";
    }

    while (<IN>) {

        next if (/^\s$/);     #Ignore blank lines

        if (/^@/) {
            scalar <IN>;
            scalar <IN>;

            my $quality_line = scalar <IN>;
            chomp $quality_line;
            my @scores = split( //, $quality_line );

            foreach (@scores) {
                my $score = ord $_;    #Determine the value of the ASCII character

                if ( $score < $score_min ) {
                    $score_min = $score;
                }

                if ( $score_min < 59 ) {
                    return 'Sanger';
                }
            }
        }
        $read_count++;
    }

    close IN or die "Could not clode filehandle on '$file' : $!";

    if ( $read_count < 1_000_000 ) {
        return 0;    #File did not contain enough lines to make a decision on quality
    }

    if ( $score_min < 64 ) {
        return 'Solexa_Illumina_1.0';
    } elsif ( $score_min < 66 ) {
        return 'Illumina_1.3';
    } else {
        return 'Illumina_1.5';
    }

}

################################
#Subroutine: determineAlignerFormat
#Receives the FASTQ format and the aligner and determines the aligner-specific format flag
#Input values are Sanger, Solexa_Illumina_1.0, Illumina_1.3, Illumina_1.5 for the FASTQ fromat
#and bowtie or bowtie2 for the aligner
#If only the FASTQ format is specified 'NO_ALIGNER' will be returned, so the subroutine can
#be used to check whether the FASTQ format is valid.
sub determineAlignerFormat {

    my ( $fastqFormat, $aligner ) = @_;
    $fastqFormat = uc $fastqFormat;

    unless ( $fastqFormat =~ /^SANGER$|^SOLEXA_ILLUMINA_1.0$|^ILLUMINA_1.3$|^ILLUMINA_1.5$/ ) {
        warn "'$fastqFormat' is not a valid FASTQ format (valid formats changed in HiCUP v0.5.2)\n";
        warn "Valid formats are: 'Sanger', 'Solexa_Illumina_1.0', 'Illumina_1.3' or 'Illumina_1.5'\n";
        return 0;
    }

    unless ( defined $aligner ) {    #By returning this message if no aligner specified, the
        return 'NO_ALIGNER';
    }

    if ( $aligner eq 'bowtie' ) {
        if ( $fastqFormat eq 'SANGER' ) {
            return 'phred33-quals';
        } elsif ( $fastqFormat eq 'SOLEXA_ILLUMINA_1.0' ) {
            return 'solexa-quals';
        } elsif ( $fastqFormat eq 'ILLUMINA_1.3' ) {
            return 'phred64-quals';
        } elsif ( $fastqFormat eq 'ILLUMINA_1.5' ) {
            return 'phred64-quals';
        }
    }

    if ( $aligner eq 'bowtie2' ) {
        if ( $fastqFormat eq 'SANGER' ) {
            return 'phred33';
        } elsif ( $fastqFormat eq 'SOLEXA_ILLUMINA_1.0' ) {
            return 'solexa-quals';
        } elsif ( $fastqFormat eq 'ILLUMINA_1.3' ) {
            return 'phred64';
        } elsif ( $fastqFormat eq 'ILLUMINA_1.5' ) {
            return 'phred64';
        }
    }

}

#Subroutine "print_example_config_file"
#Takes the name of the config file and then copies to the current working directory
sub print_example_config_file {
    my $file        = $_[0];
    my $fileAndPath = "$Bin/config_files/$file";
    !system("cp $fileAndPath .") or die "Could not create example configuratation file '$file' : $!";
    print "Created example configuration file '$file'\n";

}

#Reference to array of filenames / or value string the relevant filename, 
#reference to config_hash, name of script processing files
#1 or 0 for i) Sequence outfiles, ii) Summary file, iii) graphical file, iv) Temp files, v) other files
#(the HiC-rejects folder)
#If none selected, default is 1,0,0,0,0
#Generally an array is returned, but if one file is passed with the default 1,0,0,0,0 then
#a string is returned
#The subroutine does NOT handle paths (e.g. process config{outdir} or $config{temp})
#Indeed, all paths to the filename are removed
sub fileNamer {

    #Input and output variables and set defaults
    my ( $dataIn, $configRef, $script, $seqOutfile, $summaryOutfile, $graphicOutfiles, $tempOutfiles, $otherOutfiles ) = @_;
    my @namesIn;
    my @outNames;
    my $passedArrayRef = ref($dataIn) ? 1 : 0;    #Check if reference to an array

    $seqOutfile      = 1 unless ( defined $seqOutfile );
    $summaryOutfile  = 0 unless ( defined $summaryOutfile );
    $graphicOutfiles = 0 unless ( defined $graphicOutfiles );
    $graphicOutfiles = 0 if ( $$configRef{r} eq '0' );    #No R, no graphics
    $otherOutfiles = 0 unless ( defined $otherOutfiles );

    $tempOutfiles = 0 unless ( defined $tempOutfiles );

    if ($passedArrayRef) {
        @namesIn = @$dataIn;
    } else {                                              #Is a string
        push( @namesIn, $dataIn );
    }

    #Perform input checks
    if ( !$seqOutfile and !$summaryOutfile and !$graphicOutfiles and !$tempOutfiles and !$otherOutfiles ) {
        warn "Subroutine 'fileNamer' instructed to return no values\n";
        return;
    }

    if ( !defined $configRef ) {
        warn "Subroutine 'fileNamer' not passed a config hash reference\n";
        return;
    }

    if ( !defined $script ) {
        warn "Subroutine 'fileNamer' not instructed for which script to generate output filenames\n";
        return;
    }

    if ( !defined $dataIn ) {
        warn "Subroutine 'fileNamer' not passed a filename to process\n";
        return;
    }

    unless ( defined($dataIn) ) {
        $dataIn = '';    #Do not allow empty values.  This will be ok if just require the summary filename etc., since no inputfile name is required
    }

    if ( $script eq 'all' ) {
        my $parameters = $seqOutfile . $summaryOutfile . $graphicOutfiles . $tempOutfiles . $otherOutfiles;
        unless ( ( $parameters eq '10000' ) or ( $parameters eq '11111' ) ) {
            die "When selecting 'all' for fileNamer, input options need to be 10000 or 11111.\n";

        }
    }

    #Remove all paths from @namesIn
    foreach my $file (@namesIn) {
        $file =~ s/^.+\///;    #Remove folder references
    }

    #Process the filenames as appropriate for the defined pipeline script
    if ( $seqOutfile or $summaryOutfile or $graphicOutfiles or $tempOutfiles ) {    #Need a loop for for these
        foreach my $file (@namesIn) {
            if ( $script eq 'truncater' ) {

                $file =~ s/\.gz$|\.bz2$//;
                $file =~ s/\.fastq$|\.fq$//;

                if ($graphicOutfiles) {
                    my $graphicFile = "$file.truncation_barchart.svg";
                    push( @outNames, $graphicFile );
                }

                $file .= '.trunc.fastq';
                $file .= '.gz' if ( $$configRef{zip} );
                push( @outNames, $file ) if $seqOutfile;

            } elsif ( $script eq 'mapper' ) {

                $file =~ s/\.gz$//;
                $file =~ s/\.fastq$|\.fq$//;
                $file =~ s/\.trunc$//;

                if ($graphicOutfiles) {
                    my $graphicFile = "$file.mapper_barchart.svg";
                    push( @outNames, $graphicFile );
                }

                if ($tempOutfiles) {
                    my $tempFile = "$file.map.sam";    #Output not compressed at this point
                    push( @outNames, $tempFile );
                }

            } elsif ( $script eq 'filter' ) {

                my $filenameBeforeEditing = $file;

                $file =~ s/\.gz$//;
                $file =~ s/\.sam$//;
                $file =~ s/\.bam$//;
                $file =~ s/\.pair$//;

                if ($graphicOutfiles) {
                    my @graphicFiles = ( "$file.ditag_size_distribution.svg", "$filenameBeforeEditing.filter_piechart.svg" );    #R script reads filter summary file to determine filenames
                    push( @outNames, @graphicFiles );
                }

                if ($tempOutfiles) {
                    my @tempFiles = ("$file.ditag_size_distribution", "$file.ditag_size_distribution_report.txt");   
                    push( @outNames, @tempFiles );
                }

                if ($seqOutfile) {
                    $file .= '.filt';

                    if ( $$configRef{zip} and $$configRef{samtools} ) {
                        $file .= '.bam';
                    } elsif ( $$configRef{zip} ) {
                        $file .= '.sam.gz';
                    } else {
                        $file .= '.sam';
                    }

                    push( @outNames, $file );
                }

            } elsif ( $script eq 'deduplicator' ) {

                if ($graphicOutfiles) {
                    my @graphicFiles = ( "$file.deduplicator_cis_trans_piechart.svg", "$file.deduplicator_uniques_barchart.svg" );
                    push( @outNames, @graphicFiles );
                }

                $file =~ s/\.gz$//;
                $file =~ s/\.sam$//;
                $file =~ s/\.bam$//;
                $file =~ s/\.filt$//;

                if ($tempOutfiles) {
                    my $tempFolder = $file . ".deduplicator_temporary_batch_folder";
                    push( @outNames, $tempFolder );
                }

                if ($seqOutfile) {
                    $file .= '.dedup';

                    if ( $$configRef{zip} and $$configRef{samtools} ) {
                        $file .= '.bam';
                    } elsif ( $$configRef{zip} ) {
                        $file .= '.sam.gz';
                    } else {
                        $file .= '.sam';
                    }

                    push( @outNames, $file );
                }

            } elsif ( $script eq 'hicup' ) {    #Deduce final sequence output files and the HTML and text summary files

                $file =~ s/\.gz$//;
                $file =~ s/\.sam$//;
                $file =~ s/\.bam$//;
                $file =~ s/\.dedup$//;

                if ($summaryOutfile) {
                    my $htmlSummaryFile = ("$file." . $$configRef{datestamp} . ".HiCUP_summary_report.html");                  
                    push( @outNames, $htmlSummaryFile);
                }

                if ($seqOutfile) {
                    $file .= '.hicup';

                    if ( $$configRef{zip} and $$configRef{samtools} ) {
                        $file .= '.bam';
                    } elsif ( $$configRef{zip} ) {
                        $file .= '.sam.gz';
                    } else {
                        $file .= '.sam';
                    }

                    push( @outNames, $file );
                }

            } elsif ( $script eq 'all' ) {    #Do nothing here, but don't fail in the 'else' below

            } else {
                warn "Subroutine 'fileName' passed invald 'script' parameter: '$script'\n";
                return;
            }

        }
    }

    #To determine these filenames, keep this code outside the main loop above
    if ( $script eq 'mapper' ) {              #Calculate paired filenames if required

        if ($seqOutfile) {

            if ( ( scalar @namesIn ) % 2 ) {    #Odd number of files and need final output files (which will be paired)
                warn "Odd number of files sent to subroutine 'fileNamer' when using 'mapper' parameter\n";
                return;
            }

            my %filePairs = @namesIn;
            foreach my $file1 ( keys %filePairs ) {
                my $file2 = $filePairs{$file1};
                my $pairedFilename;

                #If the filenames are the same length and differ at one position, one filename shall be used, with
                #the position of difference substituted with an the differing positions separated by '_'
                #e.g. file1.sam, file2.sam -> file1_2.sam
                #else, the two file names are combined
                #e.g. fileABC.sam, fileDEF.sam -> fileABC.fileDEF.sam
                if ( length $file1 == length $file2 ) {
                    my @elementsFile1 = split( //, $file1 );
                    my @elementsFile2 = split( //, $file2 );

                    my @differences;
                    for ( my $i = 0 ; $i < length $file1 ; $i++ ) {
                        if ( $elementsFile1[$i] ne $elementsFile2[$i] ) {
                            push( @differences, $i );
                        }
                    }

                    if ( scalar @differences == 1 ) {
                        my $position2change = $differences[0];
                        $elementsFile1[$position2change] = $elementsFile1[$position2change] . '_' . $elementsFile2[$position2change];
                        $pairedFilename = join( '', @elementsFile1 );
                    }
                }

                unless ( defined $pairedFilename ) {
                    $pairedFilename = "$file1.$file2";
                }

                $pairedFilename .= '.pair';
                if ( $$configRef{zip} and $$configRef{samtools} ) {
                    $pairedFilename .= '.bam';
                } elsif ( $$configRef{zip} ) {
                    $pairedFilename .= '.sam.gz';
                } else {
                    $pairedFilename .= '.sam';
                }

                push( @outNames, $pairedFilename );

            }
        }
    }

    if ( $summaryOutfile and ( $script eq 'hicup' ) ) {
        my $textSummaryFile = 'HiCUP_summary_report_' . $$configRef{datestamp} . '.txt';
        push( @outNames, $textSummaryFile);
    }

    if ( $summaryOutfile and ( $script ne 'hicup' ) and ( $script ne 'all' ) ) {
        my $summaryFile = 'hicup_' . $script . '_summary_' . $$configRef{datestamp} . '.txt';
        push( @outNames, $summaryFile );
    }

    if ( $tempOutfiles and ( $script eq 'mapper' ) ) {
        my $summaryFileTemp = 'hicup_mapper_summary_' . $$configRef{datestamp} . '.temp.txt';
        push( @outNames, $summaryFileTemp );
    }

    if ( $otherOutfiles and ( $script eq 'filter' ) ) {
        my $rejectsFolder = "hicup_filter_ditag_rejects_" . $$configRef{datestamp};
        push( @outNames, $rejectsFolder );
    }

    if ($tempOutfiles and ( $script eq 'truncater' ) ) {
        my $tempFile =  'hicup_truncater_summary_temp_' . $$configRef{datestamp} . '.txt';
        push(@outNames, $tempFile);
    } 

    if ( $script eq 'all' ) {    #Run the whole pipeline - deduce filenames by performing a recursive function call

        my @truncaterSeqOutfiles = fileNamer( $dataIn,                $configRef, 'truncater',    1, 0, 0, 0, 0 );
        my @mapperSeqOutfiles    = fileNamer( \@truncaterSeqOutfiles, $configRef, 'mapper',       1, 0, 0, 0, 0 );
        my @filterSeqOutfiles    = fileNamer( \@mapperSeqOutfiles,    $configRef, 'filter',       1, 0, 0, 0, 0 );
        my @dedupSeqOutfiles     = fileNamer( \@filterSeqOutfiles,    $configRef, 'deduplicator', 1, 0, 0, 0, 0 );
        my @hicupSeqOutfiles     = fileNamer( \@dedupSeqOutfiles,     $configRef, 'hicup',        1, 0, 0, 0, 0 );

        if ($summaryOutfile) {    #If this is chosen then every output file should be returned since only 10000 and 11111 are allowed

            my @truncaterAllOutfiles = fileNamer( $dataIn,                $configRef, 'truncater',    1, 1, 1, 1, 1 );
            my @mapperAllOutfiles    = fileNamer( \@truncaterSeqOutfiles, $configRef, 'mapper',       1, 1, 1, 1, 1 );
            my @filterAllOutfiles    = fileNamer( \@mapperSeqOutfiles,    $configRef, 'filter',       1, 1, 1, 1, 1 );
            my @dedupAllOutfiles     = fileNamer( \@filterSeqOutfiles,    $configRef, 'deduplicator', 1, 1, 1, 1, 1 );
            my @hicupAllOutfiles     = fileNamer( \@dedupSeqOutfiles,     $configRef, 'hicup',        1, 1, 1, 1, 1 );

            push( @outNames, ( @truncaterAllOutfiles, @mapperAllOutfiles, @filterAllOutfiles, @dedupAllOutfiles, @hicupAllOutfiles ) );
        
        } else {

            push( @outNames, ( @truncaterSeqOutfiles, @mapperSeqOutfiles, @filterSeqOutfiles, @dedupSeqOutfiles, @hicupSeqOutfiles ) );

        }

    }

    #Terminate if any of the returned output filenames are duplicates
    #%nameFrequency{outfile name} = frequency
    {
        my $outfilesOK = 1;

        my %nameFrequency;
        foreach my $outfile (@outNames) {
            $nameFrequency{$outfile}++;
        }

        foreach my $outfile ( keys %nameFrequency ) {
            my $freq = $nameFrequency{$outfile};
            if ( $freq > 1 ) {
                warn "File with name '$outfile' would be generated $freq times\n";
                $outfilesOK = 0;
            }
        }

        unless ($outfilesOK) {
            warn "HiCUP terminated owing to the production of files with same names\n";
            warn "This problem was caused by input filenames being too similar\n";
            warn "HiCUP attempts to intelligently re-name files throughout the pipeline\n";
            warn "Try to avoid input files with identical names prior to the filename extension\n";
            warn "For example, the files 'sample.fa' and 'sample.fastq' would cause this problem\n";
            warn "This could be overcome by renaming one the files to 'sample2.fa'\n";
            die "Please try something similar with the input files you specified.\n";
        }
    }

    #Decide whether to return an array or a string
    if ( !$passedArrayRef and !$summaryOutfile and !$graphicOutfiles and !$tempOutfiles and !$otherOutfiles ) {
        return $outNames[0];
    } else {
        return @outNames;
    }

}


######################
#Subroutine: calc_perc
#Receives a number and a total and returns the perentage value
#Optional argument: decimal places of the output
#Subroutine rounds following the sprintf rounding protocol 
sub calc_perc {
    my ( $n, $total, $dp ) = @_;
    
    if(defined $dp){
        $dp = abs( int($dp) );
    }else{
        $dp = 2;
    }
    
    return 'NA' unless(defined $n and defined $total);   #Avoid initialisation error
    return 'NA' if($total == 0);    #Avoid division by zero error
    
    my $pc = 100 * $n / $total;
    my $pc_string = '%.' . $dp . 'f';

    $pc = sprintf("$pc_string", $pc);

    
    return $pc;
}


####################
#Subroutine 'cutsite_deduce':
#processes the $seq variable, creating 4 new sequences by replacing Ns by A, C, T and G
#also handles multiple Ns cases with a recursive call
sub cutsite_deduce {
    my %arg = @_;
    my $seq = $arg{-seq};

    my $rA_deducted_seq = [];

    
    foreach my $nuc ('A', 'C', 'T', 'G') {
        #Replace N by $nuc
        (my $newseq = $seq) =~ s/N/$nuc/i;

        #Check for remaining Ns within $newseq
        if ( $newseq =~ m/N/ ) {
            my $rA_new_deducted_seq = cutsite_deduce( -seq => $newseq );
            #   $rA_deducted_seq = [ map { push @{$rA_deducted_seq}, $_ } @{$rA_new_deducted_seq} ];
            do { push @{$rA_deducted_seq}, $_ } foreach(@{$rA_new_deducted_seq});
        } else {
            push @{$rA_deducted_seq}, $newseq;
        }
    }

    return $rA_deducted_seq;
}



####################
#Create a random letter string
#Takes a number for the length of
#the string and returns the string
sub generateRandomString{
	my $length = $_[0];
	
	my @chars = ("A".."Z", "a".."z");
	my $string;
	$string .= $chars[rand @chars] for 1..$length;
	
	return $string;
}



####################
#Subroutine get_csome_position
#Takes a SAM read and returns the chromosome,the sonication 
#point of the ditag and the strand
sub get_csome_position{
        my $read = $_[0];
        
        my $csome = (split(/\t/, $read))[2];
        my $pos = (split(/\t/, $read))[3];
        my $cigar = (split(/\t/, $read))[5];
        my $strand = (split(/\t/, $read))[1];

        unless($strand & 0x10){    #Positive strand
               return ($csome, $pos, '+') 
        }
        
        #Negative strand - process CIGAR string
        my $three_prime = $pos - 1; # need to adjust this only once

        # for InDel free matches we can simply use the M number in the CIGAR string
        if ($cigar =~ /^(\d+)M$/){ # linear match
               $three_prime  += $1;
               return ($csome, $three_prime, "-");
        }

        # parsing CIGAR string
        my @len = split (/\D+/,$cigar); # storing the length per operation
        my @ops = split (/\d+/,$cigar); # storing the operation
        shift @ops; # remove the empty first element
        die "CIGAR string contained a non-matching number of lengths and operations ($cigar)\n" unless (scalar @len == scalar @ops);

        # warn "CIGAR string; $cigar\n";
        ### determining end position of the read
        foreach my $index(0..$#len){
               if ($ops[$index] eq 'M'){  # standard matching bases
                       $three_prime += $len[$index];
                       # warn "Operation is 'M', adding $len[$index] bp\n";
               }
               elsif($ops[$index] eq 'I'){ # insertions do not affect the end position
                       # warn "Operation is 'I', next\n";
               }
               elsif($ops[$index] eq 'D'){ # deletions do affect the end position
                       # warn "Operation is 'D',adding $len[$index] bp\n";
                       $three_prime += $len[$index];
               }
               else{
                       die "Found CIGAR operations other than M, I or D: '$ops[$index]'. Not allowed at the moment\n";
               }
        }
        
        return ($csome, $three_prime, "-");
}


1