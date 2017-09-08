#!/usr/bin/perl -w

# -i	Input BAM-file.
# -o	output filename
# -h	print options
# -d	output directory
# -r	Either a design BED file or Reference genome size in bases
# -g	An optional BED file describing the gaps in a reference genome (only works when no bed file is given)
# -f	Set the flank size for BED-file regions. This means the script will also check the preceding and trailing N bases of regions for coverage. This option is only in effect if a BED-file is also 		given, it defaults to 0
# -l	Chromosome + region as : 2:1,000,000-2,000,000 (optional)

package postmap_basic;


use lib $ARGV[$#ARGV];
use lib $ARGV[$#ARGV] . '/QC';
use strict;
use Getopt::Long;
use POSIX;
use postmap_stats;

my $samtools;

sub new {
	my ($class) = @_;
	my $self = {};

 	$self -> {'BAM'} = ''; 
	$self -> {'OUTDIR'} = '';
	$self -> {'OUTNAME'} = '';
	$self -> {'DESIGN'} = '';
	$self -> {'REFSIZE'} = '';
	$self -> {'GAPS'} = '';
	$self -> {'FLANKS'} = 0;
 	$self -> {'REGION'} = '';
	bless $self, $class;
	return $self;
}


sub init{
	my $self = shift;
	#print "init\n";
	#Get all legal option values
	GetOptions ('i=s' =>\my $i, 'd=s' => \my $d, 'o=s' => \my $o, 'h' => \my $h, 'r=s' => \my $r, 'g=s' => \my $g, 'f=i' => \my $f, "l=s" => \my $l, "samtools=s" => \$samtools);

	#Check if all neccesary options are available, if not print help and die.
    	if($h){
		die $self -> help();
    	}
	
	if($l){
		$self -> {'REGION'} = $l;
	}


	if(!$i){
		print $self -> error('No BAM specified');
		die $self -> help();
    	}else{
		$self -> {'BAM'} = $i;
    	}

	if(!$d){
		print $self -> error('No output directory specified');
		die $self -> help();
    	}else{
		$self -> {'OUTDIR'} = $d;
    	}
    
    	if(!$o){
		print $self -> error('No output filename specified');
		die $self -> help();
    	}else{
		$self -> {'OUTNAME'} = $o;
    	}

	if(!$r){
		print $self -> error('No Genome size or BED file given');
		die $self -> help();

	}else{
		if($r =~ m/\.bed/i){
			$self -> {'DESIGN'} = $r;
		}elsif($r !~ m/\D/){
			$self -> {'REFSIZE'} = $r;
		}else{
			print $self -> error('No valid Genome size or BED file given');
			die $self -> help();
		}
    	}

	if($g){
		if($self -> {'DESIGN'}){
			print $self -> warning('BED design file already present, this option will be ignored');
		}elsif($g =~ m/\.bed/i){
			$self -> {'GAPS'} = $g;
		}else{
			print $self -> error('Not a valid BED file');
			die $self -> help();
		}
	}

	if($f){
		if(! $self -> {'DESIGN'}){
			print $self -> warning('No BED design file present, option -f will be ignored');
		}elsif($f =~ m/\D/){
			print $self -> error('Not a valid flank value');
			die $self -> help();
		}else{
			$self -> {'FLANKS'} = $f;
		}
	}
}

sub go{
	my $self = shift;
	my $stats = new postmap_stats();
	my $progress = 0;
	
	open (BAM, "$samtools view ".$self -> {'BAM'}." ".$self->{'REGION'}." |") or die $self -> error("Couldn't open BAM file using samtools");
	while(<BAM>){
		chomp;
		
		my @fields = split(/\t/);
		$stats -> analyze_basic(\@fields);
		$progress++;
		if($progress % 100000 == 0){
			print "Processed $progress reads for basic statistics\n";
		}
		
	}
	close BAM;


	if($self->{'DESIGN'}){
		$stats -> analyze_coverage('enrichment',$self -> {'BAM'},$self->{'DESIGN'}, $self->{'FLANKS'},$self->{'REGION'});
	}elsif($self->{'REFSIZE'}){
		if($self -> {'GAPS'}){
			$stats -> analyze_coverage('gaps',$self -> {'BAM'},$self->{'GAPS'}, $self -> {'BAM'},$self->{'REFSIZE'},$self->{'REGION'});
		}else{
			$stats -> analyze_coverage('whole',$self -> {'BAM'},$self->{'REFSIZE'},$self->{'REGION'}); 
		}
	}

	$stats -> output($self -> {'OUTDIR'}, $self -> {'OUTNAME'});

}





sub help{
	my $self = $_;
	
	return "
		Options:\n
		\t-i Input BAM-file.\n
		\t-o Output filename\n
		\t-h Print options\n
		\t-d Output directory\n
		\t-r Either a BED file or Reference genome size in bases\n
		\t-g An optional BED file describing the gaps in a reference genome (only works when no bed file is given)\n
		\t-f Set the flank size for BED-file regions. This means the script will also check the preceding and trailing N bases of regions for coverage. This option is only in effect if a BED-file is also given, it defaults to 0\n
		Usage:\n
		\t perl postmap_basic.pm -i reads.bam -d /home/data -o output -r <nr bases | design.bed> -f 50\n
		\t-l Chromosome + region as : 2:1,000,000-2,000,000 (optional)\n
	";
}

sub error{
	my ($self, $message) = @_;
	
	return "Error: ".$message." exiting application!\n";
}

sub warning{
	my ($self, $message) = @_;
	
	return "Warning: ".$message." \n";
}

sub main{
	my $self = new postmap_basic();
	$self -> init();
	$self -> go();


}
main();
