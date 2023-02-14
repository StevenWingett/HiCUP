#!/usr/bin/perl

#############################################
#Perl script to be used on SCRiBL datasets
#to determine capture efficiencies by scribl region  Receives
#SCRIBL coordinates and a HiCUP BAM file as
#input.  Counts the number of READS that fall
#within each capture region.
#############################################

use strict;
use warnings;
use Getopt::Long;

use Data::Dumper;

#Option variables
my $baits_file;    #Stores bait position

my $config_result = GetOptions(
    "baits=s" => \$baits_file
    );

die "Could not parse options" unless ($config_result);

unless(@ARGV and $baits_file){
    die "Please specify a SCRIBL capture positions file (--baits) and at least 1 HiCUP output file\n";
}

#Input bait positions
my %baits;   #Hash of arrays %baits{csome}->@(start_end)
open(BAITS, '<', $baits_file) or die "Could not open '$baits_file' : $!";
while(<BAITS>){
    my $line = $_;
    $line =~ s/\r\n//;
    my ($csome, $start, $end) = split(/\t/);
    push( @{ $baits{$csome} }, $start.'_'.$end);
}

close BAITS;

#Assign regions to the counter
my %counter;
foreach my $csome (keys %baits){
    foreach my $start_end ( @{ $baits{$csome} } ){
	$counter{$csome.'_'.$start_end} = 0;
    }
}


#Create summary file with headers
open(SUMMARY, '>', 'capture_summary_scribl_regions.txt') or die "Could not write to 'capture_summary.txt' : $!";
print SUMMARY "File\tTotal_Reads_processed\t";
foreach my $bait (sort (keys %counter) ){
       print SUMMARY "$bait\t";
   }
print SUMMARY "\n";	

close IN;

#Process file
foreach my $file (@ARGV){

    warn "Processing $file\n";
    
    if ($file =~ /\.bam$/){
	open (IN,"samtools view -h $file |") or die "Could not read '$file' : $!";
    }else{
	open(IN, '<', $file) or die "Could not open '$file' : $!";
    }
   
    #Zero the counter
    foreach my $key (keys %counter){
	$counter{$key} = 0;
    }

  #  print Dumper \%counter;

    my $reads_processed = 0;
    
    while(<IN>){
	if(substr($_, 0, 1) eq '@'){    #Header line
	    next;
	}
	
	my $read = $_;
	
	chomp $read;
	
	$reads_processed++;
	
	my $chromosome = (split(/\t/, $read))[2];
	my $position = (split(/\t/, $read))[3];
	my $seq = (split(/\t/, $read))[9];
	my $strand;
		
	if(((split(/\t/,$read))[1]) & 0x10){    #Analyse the SAM bitwise flag to determine strand
	    $strand = '-';    #Negative strand   
	    $position = $position + length($seq) - 1;
	}else{
	    $strand = '+';    #Positive strand
	}
	
	my $captured;
	$captured = &which_capture_region($chromosome, $position);
	
	if($captured ne '0'){
	    $counter{$captured}++;	    
	}			
    }

#    print Dumper \%counter;

    #Print the summary results
    print SUMMARY "$file\t$reads_processed\t";
    foreach my $bait (sort (keys %counter) ){
	print SUMMARY "$counter{$bait}\t";
    }
    print SUMMARY "\n";	
}

close SUMMARY;

print "Processing complete.\n";

exit;



################################################
#Subroutines
################################################
sub which_capture_region{    #Subroutine determines whether a read is in a capture region and returns the capture region
    my $lookup_csome = $_[0];
    my $lookup_pos = $_[1];
    foreach my $bait ( @{ $baits{$lookup_csome} } ){	#%baits not passed to subroutine
	my ($bait_start, $bait_end) = split(/_/, $bait);
	if( ($bait_start <= $lookup_pos) and ($bait_end >= $lookup_pos) ){
	    return "$lookup_csome".'_'.$bait_start.'_'.$bait_end;
	}
    }	
    return 0;
}




