#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;

#######################################################################################
#Perl script takes interaction matrix file pairs and report the interactions common/not common
#to both files
#######################################################################################


#Check input ok
die "Please specify files to process.\n" unless (@ARGV);   #Don't de-duplicate since working with file pairs
die "Please sepcifiy an even number of files.\n" if @ARGV % 2;


#Create summary file
my $summary_file = 'common_fragment_interactions_summary.txt';
open(SUMMARY, '>', $summary_file) or die "Could not open filehandle on '$summary_file' : $!";
print SUMMARY "File1\tFile2\tFile1_Unique_Fragment_Fragment_Interactions\tFile2_Unique_Fragment_Fragment_Interactions\tCommon_Interactions\tNot_Common_Interactions\n";

#Process files
for(my $i = 0; $i < scalar(@ARGV); $i+=2){
	my $file1 = $ARGV[$i];
	my $file2 = $ARGV[$i + 1];

	print "Comparing '$file1' to '$file2'\n";

	my %interaction_counter;
	my %duplicate_in_file_check;    #Ensure interaction not observed more than once in the same file.
	my $file1_total_interactions = 0;
	my $file2_total_interactions = 0;


	#Process file1
	print "\t\t$file1\n";
	my $fh_in = cleverOpen($file1); 
	scalar <$fh_in>;   #Ignore header
	while(<$fh_in>){
		my $line = $_;
		chomp $line;
		$interaction_counter{$line}++;
		$file1_total_interactions++;
		
		if(exists $duplicate_in_file_check{$line}){
			die "'$line' duplicated in $file1\n";
		} else {
			$duplicate_in_file_check{$line} = '';
		}
		
		
	}
	close $fh_in or die "Could not close '$file1' filehandle : $!";

	
	#Process file2
	print "\t\t$file2\n";
	%duplicate_in_file_check = ();    #Clear hash
	$fh_in = cleverOpen($file2); 
	scalar <$fh_in>;   #Ignore header
	while(<$fh_in>){
		my $line = $_;
		chomp $line;
		$interaction_counter{$line}--;  #Take away here
		$file2_total_interactions++;
		
		if(exists $duplicate_in_file_check{$line}){
			die "'$line' duplicated in $file1\n";
		} else {
			$duplicate_in_file_check{$line} = '';
		}
		
	}
	close $fh_in or die "Could not close '$file2' filehandle : $!";
	
	
	#Write out results
	my $common = 0;
	my $not_common = 0;
	
	my $file1_and_file2_outfile = "$file1.AND.$file2.gz";
	my $file1_not_file2_outfile = "$file1.NOT.$file2.gz";
	my $file2_not_file1_outfile = "$file2.NOT.$file1.gz";
	open(F1_AND_F2, "| gzip -c - > $file1_and_file2_outfile") or die "Could not write to '$file1_and_file2_outfile' : $!";
	open(F1_NOT_F2, "| gzip -c - > $file1_not_file2_outfile") or die "Could not write to '$file1_not_file2_outfile' : $!";
	open(F2_NOT_F1, "| gzip -c - > $file2_not_file1_outfile") or die "Could not write to '$file2_not_file1_outfile' : $!";
	
	
	foreach my $interaction (keys %interaction_counter){
		if($interaction_counter{$interaction} == 1){
			print F1_NOT_F2 "$interaction\n";
			$not_common++;
		} elsif($interaction_counter{$interaction} == -1){
			print F2_NOT_F1 "$interaction\n";
			$not_common++;		
		} elsif($interaction_counter{$interaction} == 0){
			print F1_AND_F2 "$interaction\n";
			$common++;
		} else {
			die "$interaction repeated $interaction_counter{$interaction} times.\n";    #Should not happen
		}
	}
	
	print SUMMARY"$file1\t$file2\t$file1_total_interactions\t$file2_total_interactions\t$common\t$not_common\n";
	close F1_AND_F2 or die "Could not close filehandle on '$file1_and_file2_outfile' : $!";
	close F1_NOT_F2 or die "Could not close filehandle on '$file1_not_file2_outfile' : $!";
	close F2_NOT_F1 or die "Could not close filehandle on '$file2_not_file1_outfile' : $!";
}


close SUMMARY or die "Could not close filehandle on '$summary_file' : $!";

print "Processing complete.\n";

exit (0);


#####################################################################
#Subroutines
#####################################################################

#######################
##Subroutine "cleverOpen":
##Opens a file with a filhandle suitable for the file extension
sub cleverOpen{
my $file  = shift;
my $fh;

if( $file =~ /\.bam$/){
	open( $fh, "samtools view -h $file |" ) or die "Couldn't read '$file' : $!";  
}elsif ($file =~ /\.gz$/){
	open ($fh,"zcat $file |") or die "Couldn't read $file : $!";
} else {
	open ($fh, $file) or die "Could not read $file: $!";
}
return $fh;
}




