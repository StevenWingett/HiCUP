#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use FindBin '$Bin';
use lib $Bin;
use hicup_module;

use Data::Dumper;

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

#Option variables
my %config = (
    expected        => undef,
    help            => undef,
    new             => undef,
    threshold       => 0,
    version         => undef
);

my $config_result = GetOptions(
    "expected=s"       => \$config{expected},
    "help"           => \$config{help},
    "new=s"           =>  \$config{new},
    "threshold=i"    => \$config{threshold},
    "version"        => \$config{version},
);

die "Could not parse options.\n" unless ($config_result);

if ( $config{help} ) {
    print while (<DATA>);
    exit(0);
}

#Print version and exit
if ( $config{version} ) {
    print "HiCUP Checker v$hicup_module::VERSION\n";
    exit(0);
}

#Check input
unless(defined $config{expected} and defined $config{new}){
    die "Please specify --expected and --new HiCUP summary results files to process.\n";
}

if( ($config{threshold} < 0) or ($config{threshold} > 100) ){
    die "Option --threshold needs to be between 0 and 100.\n";
}

#Open files
open(EXPECTED, '<', $config{expected}) or die "Could not open '$config{expected}' : $!";
open(NEW, '<', $config{new}) or die "Could not open '$config{new}' : $!";

#Check headers identical
die "Headers in '$config{expected}' and '$config{new}' do not match.\n" unless ( (scalar <EXPECTED>) eq (scalar <NEW>) );

#Loop through files and evaluate each datapoint
my $problem_flag = 0;
while(<EXPECTED>){
    my $line_expected = $_;
    my $line_new = scalar <NEW>;
    my @elements_expected = split(/\t/, $line_expected);
    my @elements_new = split(/\t/, $line_new);
    my $filename_expected = shift @elements_expected;
    my $filename_new = shift @elements_new;

    unless ($filename_expected eq $filename_new){
        die "Filenames in '$filename_expected' and '$filename_new' do not match.\n" 
    }
    
    foreach my $data_expected (@elements_expected){
        my $data_new = shift @elements_new;
        my $pc_error = 100 * ($data_new - $data_expected) / $data_expected;
        if($pc_error > $config{threshold}){
            warn "Data too different: expected: $data_expected\tnew: $data_new\n";
            $problem_flag = 1;
        }
    }
}

close EXPECTED or die "Could not close filehandle on '$config{expected}' : $!";
close NEW or die "Could not close filehandle on '$config{new}' : $!";


#Return appropriate exit status
if($problem_flag){
    die "New file failed check!\n";
} else {
    print "New file passed check\n";
}

print "Processing complete\n";

exit (0);



__DATA__

HiCUP homepage: www.bioinformatics.babraham.ac.uk/projects/hicup

The hicup_checker script confirms that two different HiCUP summary results 
files correspond exactly (or match approximately)

SYNOPSIS
hicup_checker [OPTIONS]... [HiCUP Results File1] [HiCUP Results File2]

FUNCTION
The hicup_checker script confirms that two different HiCUP summary results 
files correspond exactly (or match approximately).  This is for use in
unit testing to check that updated versions of HiCUP do not generate
substantially different results.  The script also confirms that header
lines match exactly

COMMAND LINE OPTIONS

--help         Print help message and exit
--threshold    Maximum percentage by which results may differ [default: 0]
--version      Print the program version and exit

Full instructions on running the pipeline can be found at:
www.bioinformatics.babraham.ac.uk/projects/hicup

Steven Wingett, Babraham Institute, Cambridge, UK (steven.wingett@babraham.ac.uk)