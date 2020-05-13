#!/usr/bin/perl

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

use strict;
use warnings;
use Getopt::Long;
use POSIX;
use FindBin '$Bin';
use lib $Bin;

#use Data::Dumper;

#Option variables
my $digest_file;
my $filelist;
my $version;
my $config_result = GetOptions(
					"digest=s" => \$digest_file,
			      );

die "Could not parse options.\n" unless ($config_result);


my @files = deduplicate_array(@ARGV);
die "Please specify files to process.\n" unless (@files);

die "Please specify a HiCUP --digest file.\n" unless defined $digest_file;



print "Determining relevant fragment for each BAM/SAM read using '$digest_file'\n";

#Read in digest file
my %digest_fragments;

open(DIGEST, '<', $digest_file) or die "Could not open '$digest_file' : $!";

scalar <DIGEST>;    #Ignore header rows
scalar <DIGEST>;    #Ignore header rows

while(<DIGEST>){
	chomp;

      my $chromosome_name = (split/\t/)[0];
      my $first_base = (split/\t/)[1];
      my $last_base = (split/\t/)[2];
      my $ten_kb_region =  ceil($first_base/10_000);
      my $fragment_end_ten_kb_region = ceil($last_base/10_000);
      
	do{
		$digest_fragments{"$chromosome_name\t$ten_kb_region"}{$first_base} = $last_base;
		$ten_kb_region++;
	}while($ten_kb_region <= $fragment_end_ten_kb_region);
}
close DIGEST;
#print Dumper \%digest_fragments;

foreach my $file (@files){
	print "Processing '$file'\n";

	if($file =~ /\.bam$/){
		open (IN, "samtools view -h $file |") or die "Could not read '$file' : $!";
	}else{
		open(IN, '<', $file) or die "Could not open '$file' : $!";
	}
	
	
	my %frag_pair_counter;
	
	while(<IN>){
		my $read1 = $_;

		if( (substr($read1, 0, 1) eq '@') ){
			next;
		}
		
		my $read2 = scalar <IN>;
		
		#Convert to fragment/chromosome 
		my ($csome1, $position1) = get_csome_position($read1);
		my ($csome2, $position2) = get_csome_position($read2);
		my @fragment1 = get_rest_frag($csome1 ,$position1 ,\%digest_fragments);
		my @fragment2 = get_rest_frag($csome2 ,$position2 ,\%digest_fragments);
		
		#Convert to BED format
		$fragment1[0] = csome_formatter($fragment1[0]);
		$fragment2[0] = csome_formatter($fragment2[0]);
		
		#Get fragment pair ID
		my $fragment_pair_id = create_frag_pair_id(\@fragment1, \@fragment2);
		
		$frag_pair_counter{$fragment_pair_id}++;
		
	}	
	close IN or die "Could not close filehandle on '$file' : $!";
	
	#Report results
	my $outfile = "$file.fragment_interaction_matix.txt.gz";
	open(OUT, "| gzip -c - > $outfile") or die "Could not write to '$file.rest.frags.txt' : $!";
	print OUT "Chromosome1\tStart1\tEnd1\tChromosome2\tStart2\tEnd2\tCount\n";
	foreach my $interaction (sort keys %frag_pair_counter){
		my $count = $frag_pair_counter{$interaction};
		print OUT "$interaction\t$count\n";
	}
		
	close OUT or die "Could not write to '$outfile' : $!";;
}

print "Reads positioned on appropriate fragments\n";



exit (0); 


###############################################
#Subroutines
###############################################

#create_frag_pair_id
#Takes ref to 2 arrays of: chromosome, start, end.  For each fragment and returns a string id.
#The id will be the same irrespective of the ORDER of fragement1, fragment to
sub create_frag_pair_id{
	my $frag1 = join("\t", @{ $_[0] });
	my $frag2 = join("\t", @{ $_[1] });

	if ( ( $frag1 cmp $frag2 ) == 1 ) {    #Check for order
        return "$frag2\t$frag1";
    } else {
        return "$frag1\t$frag2";
    }
}



#get_csome_position
#Takes a SAM read and returns the chromosome and the sonication point of the ditag
sub get_csome_position{
	my $read = $_[0];
	
	my $csome = (split(/\t/, $read))[2];
	my $pos = (split(/\t/, $read))[3];
	my $cigar = (split(/\t/, $read))[5];
	my $strand = (split(/\t/, $read))[1];

	unless($strand & 0x10){    #Positive strand
		return ($csome, $pos) 	
	}
	
	#Negative strand - process CIGAR string
	my $three_prime = $pos - 1; # need to adjust this only once

	# for InDel free matches we can simply use the M number in the CIGAR string
	if ($cigar =~ /^(\d+)M$/){ # linear match
		$three_prime  += $1;
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
	
	return ($csome, $pos);
}




#get_rest_frag
#Identifies the restriction fragment where a read is positioned, returns as an array
sub get_rest_frag{

	my ($lookup_csome, $lookup_pos) = @_;
	my $region_10kb = ceil($lookup_pos / 10_000);
		
	foreach my $frag_start (keys %{$digest_fragments{"$lookup_csome\t$region_10kb"}}){  	#%digest_fragments declared outside of subroutine  

		my $frag_end = $digest_fragments{"$lookup_csome\t$region_10kb"}->{$frag_start};
 
		#Check whether read is on this fragment	
		if(($frag_start <= $lookup_pos) and ($frag_end >= $lookup_pos)){
			return ($lookup_csome, $frag_start, $frag_end);
			last;
		}
      }
	  die "Could not locate position in digest:\n$lookup_csome\t$lookup_pos";
}



#Sub csome_formatter
#Makes sure output only in BED format, so:
#* -> chr*, c
#chr* -> chr*
sub csome_formatter{
	my $csome = $_[0];
	
	if(length $csome <= 3){
		return 'chr' . $csome;
	}elsif( substr($csome, 0, 3) eq 'chr' ){
		return $csome;
	}else{
		return 'chr' . $csome;
	}
}



#Sub: deduplicate_array
#Takes and array and returns the array with duplicates removed
#(keeping 1 copy of each unique entry).
sub deduplicate_array{
	my @array = @_;
	my %uniques;

	foreach (@array){
		$uniques{$_} = '';	
	}
	my @uniques_array = keys %uniques;
	return @uniques_array;
}
