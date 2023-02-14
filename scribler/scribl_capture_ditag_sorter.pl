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
#to determine capture efficiencies by scribl region  Receives
#SCRIBL coordinates and a HiCUP BAM file as
#input.  Counts the number of READS that fall
#within each capture region and separates
#di-tags into captured output files - one
#output file per bait.
#############################################

use strict;
use warnings;
use Getopt::Long;

use Data::Dumper;

#Option variables
my $baits_file;    #Stores bait position

my $config_result = GetOptions( "baits=s" => \$baits_file );

die "Could not parse options" unless ($config_result);

unless ( @ARGV and $baits_file ) {
    die "Please specify a SCRIBL capture positions file (--baits) and at least 1 HiCUP output file\n";
}

#Input bait positions
my %baits;                      #Hash of arrays %baits{csome}->@(start_end)
my %bait_pos_id_lookup_hash;    #Hash of {bait co-ordinates} = bait id

open( BAITS, '<', $baits_file ) or die "Could not open '$baits_file' : $!";
scalar <BAITS>;                 #Ignore header
while (<BAITS>) {
    chomp;
    my ( $bait_id, $csome, $start, $end ) = split(/\t/);
    push( @{ $baits{$csome} }, $start . '_' . $end );

    $bait_pos_id_lookup_hash{"$csome\t$start\t$end"} = $bait_id;
}

close BAITS;

#Assign regions to the counter
my %counter;
foreach my $csome ( keys %baits ) {
    foreach my $start_end ( @{ $baits{$csome} } ) {
        $counter{ $csome . '_' . $start_end } = 0;
    }
}

#Create summary file with headers
open( SUMMARY, '>', 'capture_summary_scribl_regions.txt' ) or die "Could not write to 'capture_summary.txt' : $!";
print SUMMARY "File\tTotal_Reads_processed\t";
foreach my $bait ( sort ( keys %counter ) ) {
    print SUMMARY "$bait\t";
}
print SUMMARY "\n";

close IN;

#Process file
foreach my $file (@ARGV) {

    #Create the output files
    my %filehandler;
    foreach my $bait_coordinates ( keys %bait_pos_id_lookup_hash ) {
        my $bait_id = $bait_pos_id_lookup_hash{$bait_coordinates};
        $filehandler{$bait_id} = newopen( $file . '_' . $bait_id . '_captured.txt' );
    }

    warn "Processing $file\n";

    if ( $file =~ /\.bam$/ ) {
        open( IN, "samtools view -h $file |" ) or die "Could not read '$file' : $!";
    } else {
        open( IN, '<', $file ) or die "Could not open '$file' : $!";
    }

    #Zero the counter
    foreach my $key ( keys %counter ) {
        $counter{$key} = 0;
    }

    #  print Dumper \%counter;

    my $reads_processed = 0;

    while (<IN>) {
        if ( substr( $_, 0, 1 ) eq '@' ) {    #Header line
            next;
        }

        my $read1 = $_;
        chomp $read1;
        my $read2 = scalar <IN>;
        chomp $read2;
        my %captured_regions;                 #Hash to remove duplicates i.e. if both reads map to the same capture region then don't write to outputfile twice

        foreach my $read ( $read1, $read2 ) {



            $reads_processed++;

            my $chromosome = ( split( /\t/, $read ) )[2];
            my $position   = ( split( /\t/, $read ) )[3];
            my $seq        = ( split( /\t/, $read ) )[9];
            my $strand;

            if ( ( ( split( /\t/, $read ) )[1] ) & 0x10 ) {    #Analyse the SAM bitwise flag to determine strand
                $strand   = '-';                               #Negative strand
                $position = $position + length($seq) - 1;
            } else {
                $strand = '+';                                 #Positive strand
            }

            my $captured;
            $captured = &which_capture_region( $chromosome, $position );

            if ( $captured ne '0' ) {
                $counter{$captured}++;
                $captured_regions{$captured} = '';
            }
        }


        #Write the captured reads to the relevant output file
        foreach my $captured ( keys %captured_regions ) {
            my $bait_id = $bait_pos_id_lookup_hash{$captured};
            my $fh      = $filehandler{$bait_id};
            print $fh "$read1\n$read2\n";
        }
    }


    #Print the summary results
    print SUMMARY "$file\t$reads_processed\t";
    foreach my $bait ( sort ( keys %counter ) ) {
        print SUMMARY "$counter{$bait}\t";
    }
    print SUMMARY "\n";


    #Close the filehandles
    foreach my $bait_id ( keys %filehandler ) {
        my $fh = $filehandler{$bait_id};
        close $fh or die "Could not close filehandle $fh\n";
    }
}

close SUMMARY;

print "Processing complete.\n";

exit;

################################################
#Subroutines
################################################
sub which_capture_region {    #Subroutine determines whether a read is in a capture region and returns the capture region
    my $lookup_csome = $_[0];
    my $lookup_pos   = $_[1];
    foreach my $bait ( @{ $baits{$lookup_csome} } ) {    #%baits not passed to subroutine
        my ( $bait_start, $bait_end ) = split( /_/, $bait );
        if ( ( $bait_start <= $lookup_pos ) and ( $bait_end >= $lookup_pos ) ) {
            return "$lookup_csome\t$bait_start\t$bait_end";
        }
    }
    return 0;
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
