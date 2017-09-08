#!/usr/bin/perl -w

#This script is meant to be operated by the premap_basic script. It performs the actual analyses.

package premap_stats;

use strict;
use POSIX;

sub new{
	my ($class) = @_;
	my $self = {};
	$self -> {'TOTALREADS'} = 0;
	$self -> {'DOTS'} = {};
	$self -> {'READQMEANS'} = {};
	$self -> {'POSQMEANS'} = {};
	bless $self, $class;
	return $self;
}



sub output{
    my ($self, $outDir, $outFile) = @_;

    open(OUT, ">".$outDir."/".$outFile.".pre") or die "Error: Could not create .pre stats file!\n";
    
    print OUT $self->outputAnalysis();
    close OUT;
}


#Check and store the occurence of quality scores as well as the dots
sub analyze{
	my ($self,$read) = @_;
	my $mean = 0;
	my @r = @$read;
	my $dotCount = 0;
	
	$self-> {'TOTALREADS'} ++;
	
	for(my $i=0; $i<@r;$i++){
		
		my $pos= $i+1;
		my $val= $r[$i];

		$mean += $val;
		
		if($val == 1 ){$dotCount++}; #Keep track of dots
		 
		$self->{'POSQMEANS'}->{$pos}->{$val}+=1;
	}
	
	#Calculate and assign mean to bin in READQMEANS
	$mean = $mean / scalar(@r);
	my $cat = (floor($mean / 5)) * 5;
	
	#if($cat > 30){
	#    $self->{'READQMEANS'} -> {'30'}++;
	#}
	#else{
	$self->{'READQMEANS'} -> {$cat}++;
	#}
	
	
	#Increment appropriate dotcount
	if($dotCount == 0){$self -> {'DOTS'}-> {'0'}++}
	elsif($dotCount == 1){$self -> {'DOTS'}-> {'1'}++}
	elsif($dotCount	>1){$self -> {'DOTS'}-> {'2'}++}	
}


#Output the analysis results
sub outputAnalysis{
	my $self = shift;
	my $out = "\n";
	
	$out.= "#tot_reads\t".$self -> {'TOTALREADS'}."\n\n";
	
	foreach my $key(keys %{$self->{'DOTS'}}){
		$out.= "#dot\t".$key."\t".$self->{'DOTS'}->{$key}."\n";
	}
	
	$out.= "\n";
	foreach my $key(keys %{$self->{'READQMEANS'}}){
		$out.= "#qmean\t".$key."\t".$self->{'READQMEANS'}->{$key}."\n";
	}
	$out.= "\n";
	
	foreach my $entry(sort{$a <=> $b} keys %{$self->{'POSQMEANS'}}){
		foreach my $s_entry(sort{$a <=> $b} keys %{$self->{'POSQMEANS'}->{$entry}}){
			$out.= "#pos\t".$entry."\t".$s_entry."\t".$self->{'POSQMEANS'}->{$entry}->{$s_entry}."\n";
		}
	}
	return $out;
}


1;