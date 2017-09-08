#!/usr/bin/perl -w


use strict;
use lib $ARGV[$#ARGV];
use lib $ARGV[$#ARGV] . '/QC';
use Getopt::Long;
use postmap_runjobs;

my $SCRIPTLOC = $ARGV[$#ARGV];
if(! -d $SCRIPTLOC){
	die "Last argument to postmap_quickstart must be the path to the QC scripts!\n";
}

my $jobs = 10;
# --bam		BAM-file
# --img		Image directory
# --sum		Summary directory
# --pdf		Pdf directory
# --id		Projects
# --ref		Either Design BED or Genome size
# --gap		An optional BED file describing the gaps in a reference genome (only works when no bed file is given)
# --flank	Set the flank size for BED-file regions. This means the script will also check the preceding and trailing N bases of regions for coverage. This option is only in effect if a BED-file is 		alsogiven, it defaults to 0
# --rpath	path to R (optional, default is /usr/bin/R)
# --samtools	path to samtools
# --clean	Clean intermediate .post files 
# --jobs	Nr simultaneous running jobs

#Get option values and check if all neccessary values are present
GetOptions ('bam=s' =>\my $bam, 'id=s' => \my $id, 'ref=s' => \my $ref, 'gap=s' => \my $gap, 'flank=i' => \my $flank,'rpath=s' => \my $rpath, 'clean' => \my $clean, 'img=s' => \my $img, 'sum=s'=>\my $sum, 'pdf=s' => \my $pdf, 'samtools=s' => \my $st, 'jobs=s'=> \$jobs);

$bam 	? my $bamFile = $bam 	: die "No bam-file specified! (--bam)\n";
$id 	? my $outName = $id 	: die "No id specified (project name)) (--id)\n";
$ref 	? my $reference = $ref 	: die "No reference specified (BED or Genome-size)(--ref)\n";
$img 	? my $imgDir = $img 	: die "No image directory specified(--img)\n";
$sum 	? my $sumDir = $sum 	: die "No summary directory specified(--sum)\n";
$pdf 	? my $pdfDir = $pdf 	: die "No pdf directory specified(--pdf)\n";

my $gaps = $gap 	? "-g $gap" 	: '';
my $flanksize = $flank 	? "-f $flank" 	: '';
my $RLocation = $rpath 	? "-R $rpath" 	: '';
my $cleanup = $clean 	? 1 		: 0;

my $samtools = $st 	? "--samtools $st" : '--samtools /usr/local/bin/samtools';

#Get all chromosomes + max coordinates from the BAM-file
my $regions = {};
open(REGIONS, "/usr/local/bin/samtools view -H $bamFile |");
while(<REGIONS>){
	chomp;
	my ($chr,$max) = (split(/\t/))[1,2];
	$chr =~ s/SN://;
	$max =~ s/LN://;
	$regions->{$chr} = $max;
}
close REGIONS;

#Create a postmap_basic job for every chromosome
my @jobs = ();
while (my ($chr, $max) = each(%{$regions})){
	my $reg = "$chr:1-$max";	
	push(@jobs, "perl $SCRIPTLOC/postmap_basic.pm -i $bamFile -o $id".'_'."$chr -d $pdfDir -r $reference -l $reg $gaps $flanksize $samtools $SCRIPTLOC");
}

#Run all postmap_basic jobs 
my $jobrunner = new postmap_runjobs();
$jobrunner->init(\@jobs, $jobs);
$jobrunner->run();

#Run the postmap_clonality script
my $clonalitycommand = "perl $SCRIPTLOC/postmap_clonality.pl -d $pdfDir -i $bamFile -o $id $samtools";
`$clonalitycommand`;

#Merge results 
my $mergecommand = "perl $SCRIPTLOC/postmap_merge.pm -d $pdfDir -p $pdfDir -s $sumDir -i $imgDir --id $id -b $bamFile $RLocation $samtools $SCRIPTLOC";
print $mergecommand . "\n\n";
`$mergecommand`;


if($cleanup){
	#Cleanup .post files
	while(<$pdfDir/*.post>){
		my $postfile = $_;
		print 'removing '.$postfile."\n";
		unlink $postfile;
	}
	print "removing $pdfDir/$id\.postclon\n";
	unlink($pdfDir.'/'.$id.'.postclon');
}

