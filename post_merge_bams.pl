#!/usr/bin/perl -w
use strict;

my @files = <results/*_sorted.bam>;
my $outfile = $ARGV[0];
chomp($outfile);

#$outfile .= '.bam';
print 'Output will be written to: ' . $outfile . ".bam\n";
my $cmd;

$cmd = "java -Xms4G -Xmx7G -jar /hpc/cog_bioinf/common_scripts/picard-tools-1.62/MergeSamFiles.jar O=$outfile.bam VALIDATION_STRINGENCY=LENIENT CREATE_INDEX=TRUE ASSUME_SORTED=TRUE USE_THREADING=FALSE ";
foreach ( @files ) { 
    die "infile = outfile" if $_ eq "$outfile.bam";
    $cmd .= "I=$_ ";
}

system $cmd;
system "mv $outfile.bai $outfile.bam.bai";