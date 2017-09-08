#!/usr/bin/perl -w
use strict;

my $design = shift;

open DES, $design or die" cannot open design file\n"; #bed format

#my @f2do = @ARGV; # snp lists


my $flank = 20;
my (%designed);
print "reading design...\n";
while (<DES>) {
    next if $_ =~ /^#/;
    next if $_ =~ /^track/;
    my ($chr, $start, $end) = (split("\t"))[0,1,2];
    $chr =~ s/chr//;
    $designed{$chr}{$_}++ foreach ( ($start-$flank) .. ($end+$flank));
}

my $des_bp;
foreach my $chr (keys %designed) {
    $des_bp += keys %{$designed{$chr}};
}
print $des_bp, " positions considered\n";


foreach my $dir (<*>) {
	next unless -d $dir;
	#next unless $dir eq 'lists';
	print "Analyzing $dir...\n";
	chdir $dir;
	system "rm *_targets";
	my @f2do;
	push @f2do, <*snps>;
	push @f2do, <*indels>;
	push @f2do, <*snv*>;
	foreach my $file ( @f2do ) {
	    open IN, $file or die" cannot open list file $file\n";
	    print "\treading positions file $file\n";
	    my ($total, $passed)=(0,0);
	    my %store;
	    open OUT, '>'.$file.'.in_targets';
	    open OUT2, '>'.$file.'.outside_targets';
	    print OUT "#design: $design\n";
	    while ( <IN> ) {
		next if $_ =~ /^#/;
		$total++;
		my ($chr, $pos) = (split("\t"))[0,1];
		$chr =~ s/chr//;
		next if $chr eq 'chr';
		if (defined $designed{$chr}{$pos}) {
		    $store{$chr}{$pos} = $_;
		    $passed++;
		}
		else {
		    print OUT2 $_;
		}
	    }
	    foreach my $chr (keys %store) {
		foreach my $pos (sort {$a<=>$b} keys %{$store{$chr}}) {
		    print OUT $store{$chr}{$pos};
		}
	    }    
	    print "\t",$file ," done\t$passed passed from $total\n";
	}
	chdir '../';
}