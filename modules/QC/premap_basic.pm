#!/usr/bin/perl -w


# 	-i 	fastQ file
#	-o	output filename
#	-h	print options
#	-d	output directory


package premap_basic;

use lib $ARGV[$#ARGV];
use lib $ARGV[$#ARGV] . '/QC';
use strict;
use Getopt::Long;
use premap_stats;

sub new{
    my ($class) = @_;
    my $self = {};
    
    $self -> {'FASTQ'} = '';
    $self -> {'OUTDIR'} = '';
    $self -> {'OUTNAME'} = '';

    bless($self, $class);
    return $self;
}


sub init{
    my $self = shift;
    
    #Get all legal option values
    GetOptions ('i=s' =>\my $i, 'd=s' => \my $d, 'o=s' => \my $o, 'h' => \my $h);

    #Check if all neccesary options are available, if not print help and die.
    if($h){
	die $self -> help() . "\n";
	
    }
    
    if(!$i){
	print $self -> error('No FastQ specified');
	die $self -> help();
	
    }else{
	$self -> {'FASTQ'} = $i;
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
}

sub go{
    my $self = $_[0];
    my $stats = new premap_stats();
    
    #Process FastQ file using premap_stats
    open (FASTQ, "<".$self->{'FASTQ'}) or die $self -> error('Could not open FastQ-file');

    while(my $line = <FASTQ>){
	chomp($line);
	if($. % 4 == 0){#Use only every fourth line (this is a read)
		my @splitline= ();

		#Convert every line back to an array of quality scores
		for(my $i=0; $i<length($line);$i++){
			push(@splitline, ord(substr($line, $i, 1))-33);
		}
		$stats -> analyze(\@splitline); 
	}
        
    }
    
    close FASTQ;
    
    $stats -> output($self -> {'OUTDIR'}, $self -> {'OUTNAME'});
    
}

sub help{
    my $self = $_;
    
    return "
	Options:\n
	\t-h Print help\n
	\t-i FastQ file\n
	\t-d Output directory\n
	\t-o Output filename\n
	Usage:\n
	\t perl premap_basic.pm -i reads.fastq -d /home/data -o output\n
    ";
}

sub error{
    my ($self, $message) = @_;
    
    return "Error: ".$message." exiting application!\n";
}

sub main{
    my $self = new premap_basic();
    $self -> init();
    $self -> go();


}

main();
