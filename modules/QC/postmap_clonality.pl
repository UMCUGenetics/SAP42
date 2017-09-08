#!/usr/bin/perl -w

# -d	output directory
# -i	Input BAM-file.
# -o	output filename
# --samtools	path to samtools 
use strict;
use Getopt::Long;

my $bam = "";
my $outdir = "";
my $file = "";
my $samtools;
my $current = "";
my $previous = "";
my $count = 1;
my $clonals = {};


GetOptions ("i=s" =>\my $i,"o=s" =>\my $o, "d=s" => \my $d, "samtools=s" => \$samtools);

$i and -e $i ? $bam = $i : die "Error: Please specify a valid BAM-file. (Option -i <bam>)\n";
$d ? $outdir = $d : die "Error:  No output dir given. (Option -d <dir>)";
$o ? $file = $o : die "Error:  No output filename given. (Option -o <name>)";


open (BAM, "$samtools view $bam |") or die "Error: Could not open BAM file $bam\n";

while(<BAM>){
	chomp;
	my $line = $_;
	
	if ($line =~ m/X0:i:1/ and $line =~ m/([ACGT]{10,300})/ ){

		my $current = $1;

		if($previous eq ""){
			$previous = $current;
			next;
		}

		if($current eq $previous){
			$count ++;

		}else{
			$clonals->{$count}++;
			$count = 1;
		}
		$previous = $current;
	}
}
close BAM;


open(CLON, ">$outdir/$file.postclon") or die "Error: Failed to create $outdir/$file.postclon\n";
	foreach my $key (sort{$a <=> $b} keys %{$clonals}){
	
		print CLON $key."\t".$clonals->{$key}."\n";
	
	}
close CLON;