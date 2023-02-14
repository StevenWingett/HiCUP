#!/usr/bin/perl

###################################################################################
###################################################################################
##This file is Copyright (C) 2023, Steven Wingett                                ##
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


#############################################
#Perl script to be used on SCRiBL datasets
#to determine capture efficiencies.  Receives
#SCRIBL coordinates and a HiCUP BAM file as
#input.
#############################################

use strict;
use warnings;
use Getopt::Long;

use Data::Dumper;

#Option variables
my $baits_file;    #Stores baits postions
my $zip;

my $config_result = GetOptions(
			       "baits=s" => \$baits_file,
					"zip" => \$zip
			      );

die "Could not parse options" unless ($config_result);

unless(@ARGV and $baits_file){
	die "Please specify a SCRIBL capture positions file (--baits) and at least 1 HiCUP output file\n";
}

$zip = 1;
print "Zip by default";

#Input bait positions
my %baits;   #Hash of arrays %baits{csome}->@(start_end)
open(BAITS, '<', $baits_file) or die "Could not open '$baits_file' : $!";
while(<BAITS>){
	chomp;
	my ($csome, $start, $end) = split(/\t/);
	push( @{ $baits{$csome} }, $start.'_'.$end);
}

close BAITS;

#print Dumper \%baits;

open(SUMMARY, '>', 'capture_summary.txt') or die "Could not write to 'capture_summary.txt' : $!";
print SUMMARY "File\tDitags_processed\tBoth_captured\tForward_captured\tReverse_capture\tNeither_captured\n";

close IN;

#Process file
foreach my $file (@ARGV){

	print "Processing $file\n";

	if ($file =~ /\.bam$/){
		open (IN,"samtools view -h $file |") or die "Could not read '$file' : $!";
	}else{
		open(IN, '<', $file) or die "Could not open '$file' : $!";
	}
	
	my $write_command;
	if($zip){
		open(CAPTURED, "| samtools view -bSh 2>/dev/null - > $file"."_captured.bam") or die "Could not not write to $file"."_captured.bam : $!";
		open(UNCAPTURED, "| samtools view -bSh 2>/dev/null - > $file"."_uncaptured.bam") or die "Could not not write to $file"."_uncaptured.bam : $!";
	}else{
		open(CAPTURED, '>', "$file.captured.sam") or die "Could not open '$file.captured.sam' : $!";
		open(UNCAPTURED, '>', "$file.uncaptured.sam") or die "Could not open '$file.uncaptured.sam' : $!";	
	}
	
	my %counter = ('Total' => 0, 'Forward_captured' => 0, 'Reverse_captured' => 0, 'Both_captured' => 0, 'Neither_captured' => 0);
	
	while(<IN>){
		if(substr($_, 0, 1) eq '@'){    #Header line
			print CAPTURED $_;
			print UNCAPTURED $_;
			next;
		}
		
		my $readF = $_;
		my $readR = scalar <IN>;
		chomp $readF;
		chomp $readR;
		
		$counter{Total}++;
    
		my $chromosomeF = (split(/\t/, $readF))[2];
		my $chromosomeR = (split(/\t/, $readR))[2];
		my $positionF = (split(/\t/, $readF))[3];
		my $positionR = (split(/\t/, $readR))[3];
		my $seqF = (split(/\t/, $readF))[9];
		my $seqR = (split(/\t/, $readR))[9];

		my $strandF;
		my $strandR;

		if(((split(/\t/,$readF))[1]) & 0x10){    #Analyse the SAM bitwise flag to determine strand
			$strandF = '-';    #Negative strand   
			$positionF = $positionF + length($seqF) - 1;
		}else{
			$strandF = '+';    #Positive strand
		}

		if(((split(/\t/,$readR))[1]) & 0x10){    #Analyse the SAM bitwise flag to determine strand
			$strandR = '-';    #Negative strand
			$positionR = $positionR + length($seqR) - 1;
		}else{
			$strandR = '+';    #Positive strand
		}
	
		#Are either of the strands captured?
		my $forward_captured = 0;
		my $reverse_captured = 0;
		
		if( &is_captured($chromosomeF, $positionF)){
			$forward_captured = 1;
		}	
		
		if( &is_captured($chromosomeR, $positionR)){
			$reverse_captured = 1;
		}	

		if($forward_captured and $reverse_captured){
			print CAPTURED "$readF\n$readR\n";
			$counter{Both_captured}++;
		}elsif($forward_captured){
			print CAPTURED "$readF\n$readR\n";
			$counter{Forward_captured}++;
		}elsif($reverse_captured){
			print CAPTURED "$readF\n$readR\n";
			$counter{Reverse_captured}++;
		}else{
			print UNCAPTURED "$readF\n$readR\n";
			$counter{Neither_captured}++;
		}			
	}
	print SUMMARY "$file\t$counter{Total}\t$counter{Both_captured}\t$counter{Forward_captured}\t$counter{Reverse_captured}\t$counter{Neither_captured}\n";	
}

close SUMMARY;

print "Processing complete.\n";

exit;



################################################
#Subroutines
################################################
sub is_captured{    #Subroutine determines whether a read is in a capture region
	my $lookup_csome = $_[0];
	my $lookup_pos = $_[1];
	foreach my $bait ( @{ $baits{$lookup_csome} } ){	#%baits not passed to subroutine
		my ($bait_start, $bait_end) = split(/_/, $bait);
		if( ($bait_start <= $lookup_pos) and ($bait_end >= $lookup_pos) ){
			return 1;
		}
	}	
	return 0;
}




