#!/usr/bin/perl -w

# 	This scripts is meant to merge raw data files (.pre) from premap_clus_basic into a grapical and textual summary. 

# -d directory to search for raw data files to merge
# -p location to write pdf to
# -s location of summary file
# -i location of graphs
# -R path to R (optional, default is /usr/bin/R)
# --id runname_samplename_libraryname_optionallibtag
# -h print options

package premap_merge;

use lib $ARGV[$#ARGV];
use lib $ARGV[$#ARGV] . '/QC';

#use lib '/data/common_modules';
use strict;
use Getopt::Long;
use premap_plotter;
use Number::Format;

sub new{
    my ($class) = @_;
    my $self = {};
    
    $self -> {'INDIR'} = '';
    $self -> {'PDFDIR'} = '';
    $self -> {'SUMDIR'} = '';
    $self -> {'IMGDIR'} = '';
    $self -> {'RPATH'} = '/usr/bin/R';
    $self -> {'ID'} = '';
    

    my @timeData = localtime(time);
    my $currentYear = 1900 + $timeData[5];
    my $month = $timeData[4]+1;
    my $day = $timeData[3];
    my $hours = $timeData[2];
    my $minutes = $timeData[1];
	
    $self->{_timeStamp} = "_".$currentYear."_".$month."_".$day."_".$hours."_".$minutes;

    bless($self, $class);
    return $self;
}




sub init{
	my $self = shift;

	GetOptions ("d=s" =>\my $d,"s=s" => \my $s,"p=s" => \my $p, "R=s" => \my $r, "i=s"=>\my $i, "id=s" => \my $id, "h=s" => \my $h);
	
	if($h){
		die $self -> help();
	
    	}


	if($d and -d $d){
		$self -> {'INDIR'} = $d;
	}else{
		print $self -> error('Please specify a valid directory containing .pre files. (Option -d)');
		die $self -> help();
	}

	if($s and -d $s){
		$self->{'SUMDIR'} = $s;
	}else{
		print $self -> error('Error: Please specify a valid directory to write the summary file to. (Option -s <dir>)');
		die $self -> help();
	}

	if($p and -d $p){
		$self->{'PDFDIR'} = $p;
	}else{
		print $self -> error('Error: Please specify a valid directory to write the PDF to. (Option -p <dir>)');
		die $self -> help();
	}

	if($r and -d $r){
		$self->{'RPATH'} = $r;
	}

	if($i and -d $i){
		$self->{'IMGDIR'} = $i;
	}else{
		print $self -> error('Error: Please specify a valid directory to write the graph to. (Option -i <dir>)');
		die $self -> help();
	}

	if($id){
		$self->{'ID'} = $id;
		
	}else{
		print $self -> error('Error: No ID specified. (Option --id <name>');
		die $self -> help();
	}
}

sub go{
	my $self = shift;


	my $in = $self->{'INDIR'};

	while(<$in/*.pre>){
		chomp;
		
		my $file = $_;

	        open (PRE, "<".$file) or die "Failed to open $file \n";
	        
	        while(<PRE>){
			chomp;
	    		my $line = $_;
	    		if($line =~ m/#tot_reads\s(\d+)/){$self->{'totalReads'}+=$1}
			elsif($line =~ m/#dot\s(\d+)\s(\d+)/){$self->{'dotCount'}->{$1} += $2}
			elsif($line =~ m/#qmean\s(\d+)\s(\d+)/){$self->{'qualityMeans'}->{$1} += $2}
			elsif($line =~ m/#pos\s(\d+)\s(\d+)\s(\d+)/){$self->{'positionQualities'}->{$1}->{$2} += $3}
	    	}
	    	close PRE;
	}
	if(exists($self->{'positionQualities'})){
		$self-> preProcessPQ();
	}

}

sub output{
	my $self = shift;

	$self -> write_pdf();
	$self -> write_sum();
}


sub write_sum{
	my $self = shift;

	my $id = $self -> {'ID'};
	$id =~ s/\^/_/g;
	my $sumname = $self -> {'SUMDIR'}.'/Pre_'.$id.$self->{_timeStamp}.'.summ';

	my $fn = Number::Format->new (
		-thousands_sep 	=> ',',
		-decimal_digits	=> 0,
		-decimal_fill	=> 'true',
	);

	my $fp = Number::Format->new (
		-thousands_sep 	=> ',',
		-decimal_digits	=> 2,
		-decimal_fill	=> 'true',
	);

	my $total_reads = $self -> {'totalReads'};
	
	open(SUMMARY, ">$sumname") or die "Failed to create summary file: $sumname !\n";

 	print SUMMARY "Total reads:\t".$fn->format_number($total_reads)."\n";
	
	print SUMMARY "\nDot overview:\n";
	foreach my $nrdots (sort{$a <=> $b} keys %{$self->{'dotCount'}}){
		my $count = $self->{'dotCount'}->{$nrdots};
		my $count_nr = $fn->format_number($count);
		my $count_pc = $fp->format_number(($count / $total_reads) * 100);

		if($nrdots == 2){
			print SUMMARY "Nr reads with >1 dots:\t$count_nr\t$count_pc"."% of total\n";
		}else{
			print SUMMARY "Nr reads with $nrdots dots:\t$count_nr\t$count_pc"."% of total\n";
		}
	}
	
	print SUMMARY "\nMean quality overview (reads):\n";
	foreach my $qmean (sort{$a <=> $b} keys %{$self->{'qualityMeans'}}){
		my $count = $self->{'qualityMeans'}->{$qmean};
		my $count_nr = $fn->format_number($count);
		my $count_pc = $fp->format_number(($count / $total_reads) * 100);

		#if($qmean == 30){
			#print SUMMARY "Nr Reads with mean quality: >=".$qmean."\t".$count_nr."\t(".$count_pc."% of total)\n";
		#}else{
			print SUMMARY "Nr Reads with mean quality: ".$qmean."-<".($qmean+5)."\t".$count_nr."\t(".$count_pc."% of total)\n";
		#}
	}

	print SUMMARY "\nMean quality overview (positions):\n";

	foreach my $pos (sort{$a <=> $b} keys %{$self->{_proc_pqocc}}){
		my $mean = $fp->format_number($self->{_proc_pqocc}->{$pos}[0]);
		my $stdev = $fp->format_number($self->{_proc_pqocc}->{$pos}[1]);
		
		print SUMMARY "Position: $pos\tMean:\t".$mean."\tStddev:\t".$stdev."\n";
	}

	close SUMMARY;


}

sub write_pdf{
	my $self = shift;

	my %toPlot = ();
	$toPlot{'imgpath'} = $self ->{'IMGDIR'};
	$toPlot{'pdfpath'} = $self ->{'PDFDIR'};
	$toPlot{'name'} = $self ->{'ID'};
	$toPlot{'name'} =~ s/\^/_/g;

	$toPlot{'totalreads'} = $self -> {'totalReads'};
	$toPlot{'rpath'} = $self->{'RPATH'};
	
	if(exists($self->{'dotCount'})){
		my $data ={};	

		$data->{"0"}=$self->{'dotCount'}->{"0"} ? $self->{'dotCount'}->{"0"} : 0;
		$data->{"1"}=$self->{'dotCount'}->{"1"} ? $self->{'dotCount'}->{"1"} : 0;
		$data->{"2"}=$self->{'dotCount'}->{"2"} ? $self->{'dotCount'}->{"2"} : 0;

		$toPlot{'dotCount'} = $data;
	}

	if(exists($self->{'qualityMeans'})){

		my $data = {};
		$data->{"0-5"} = exists($self->{'qualityMeans'}->{0}) ? $self->{'qualityMeans'}->{0} : 0;
		$data->{"5-10"} = exists($self->{'qualityMeans'}->{5}) ? $self->{'qualityMeans'}->{5} : 0;
		$data->{"10-15"} = exists($self->{'qualityMeans'}->{10}) ? $self->{'qualityMeans'}->{10} : 0;
		$data->{"15-20"} = exists($self->{'qualityMeans'}->{15}) ? $self->{'qualityMeans'}->{15} : 0;
		$data->{"20-25"} = exists($self->{'qualityMeans'}->{20}) ? $self->{'qualityMeans'}->{20} : 0;
		$data->{"25-30"} = exists($self->{'qualityMeans'}->{25}) ? $self->{'qualityMeans'}->{25} : 0;
		$data->{"30-35"} = exists($self->{'qualityMeans'}->{30}) ? $self->{'qualityMeans'}->{30} : 0;
		$data->{"35-40"} = exists($self->{'qualityMeans'}->{35}) ? $self->{'qualityMeans'}->{35} : 0;		
		$toPlot{'qualityMeans'} = $data;
	}

	if(exists($self->{'positionQualities'})){
		$toPlot{'positionQualities'} = $self->{'positionQualities'};
	}

	
	my $plotter = new premap_plotter(\%toPlot);
	$plotter->start();	
	
}


sub preProcessPQ{
	my $self = shift;

	my %pocc = %{$self->{'positionQualities'}};

	foreach my $pos(sort{$a <=> $b} keys %pocc){
		
		my @ms;
		my %poss = %{$self->{'positionQualities'}->{$pos}};
		my $totqual = 0;
		foreach my $qual(keys %poss){
			$totqual+=($poss{$qual}*$qual);
 			
		}
		my $mean = $totqual/$self->{'totalReads'};
		my $st = 0;
		foreach my $qual(keys %poss){
			$st += $poss{$qual}*(($qual-$mean)**2);
 			
		}
		
 		my $std = sqrt($st/$self->{'totalReads'});

		$self->{_proc_pqocc}->{$pos} = [$mean,$std];
 		
	}
}

sub help{
    my $self = $_;
    
    return "
	Options:\n
	\t-h Print help\n
	\t-d Directory to search for raw .pre files to merge\n
	\t-p Location to write pdf to\n
	\t-s Location to write summary file to\n
	\t-i Location to write graphs to\n
	\t-R Optional path to R (default is /usr/bin/R)\n
	\t--id runname^samplename^libraryname^optionallibtag\n
	Usage:\n
	\t perl premap_merge.pm -d /data/project -p /home/data -s /home/data -i /home/data --id run^sam^lib^libtag\n
    ";
}


sub error{
    my ($self, $message) = @_;
    
    return "Error: ".$message." exiting application!\n";
}


sub main{
	my $merger = new premap_merge();
	$merger->init();
	$merger->go();
	$merger->output();
}


main();
