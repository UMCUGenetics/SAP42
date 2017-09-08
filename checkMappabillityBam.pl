#!/usr/bin/perl -w
use strict;



my $bam = shift(@ARGV) or die "supply a BAM file\n";

my $cfn = shift(@ARGV) or die "Supply a core file name\n";

open(BAM, "/hpc/cob_bioinf/common_scripts/samtools/samtools view $bam |");

my $count = 0;

my $unmapped = 0;

my %chr;
my @mis = ();

my $misbin;
my $mispos;

while (<BAM>)
{
	chomp;
	$count++;
	my @line = split("\t", $_);

	if ($line[1] == 4){
		$unmapped++;
		next;
	}

	my $strand = 1;

	my ($mismatches, $editString);

	my ($flag, $chrom, $cord, $cigar, $seq, $qual, @options) = ($line[1] ,$line[2],$line[3],$line[5],$line[9],$line[10], @line[11 .. $#line]); 
	# check where the editstring field is
	foreach my $opt ( @options) {
		if ($opt =~ /XM\:i/) {
			$opt =~ s/XM\:i://;
			$mismatches = $opt;
	    	}
		if ($opt =~ /MD\:Z/) {
			$editString = $opt;
		}
	}

	$chr{$chrom}++;
	$mis[$mismatches]++;

	if ($flag == 16) {$strand = 0;}

	checkMismatches($strand, $chrom, $cord, $cigar, $seq, $qual, $editString);

}

open (STATS, ">$cfn.stats");
print STATS "Total reads:\t",$count,"\n";
print STATS "Total mapped:\t",($count - $unmapped),"\n";
print STATS "\n";
print STATS "Mappability:\t",((($count - $unmapped) / $count) * 100),"%\n";
close(STATS);

open (STATS, ">$cfn.mismatches.stats");
foreach my $nr (0..$#mis){
	print STATS $nr, "\t", $mis[$nr], "\n";
}
close(STATS);

open (STATS, ">$cfn.chr.stats");
foreach my $nr (keys(%chr)){
	print STATS $nr, "\t", $chr{$nr}, "\n";
}
close(STATS);


sub checkMismatches {

	my ($strand, $chrom, $cord, $cigar, $seq, $qual, $editString) = @_;
	my @splitQual = split("",$qual);
	my @splitSeq = $strand ? split("",uc($seq)) : split("",lc($seq));
	my ($length, $c, $delCorrection) = (0,0,0);
	my @read = ();
	my @edit = ();
	my @insertions = ();
	my @deletions = ();

	# go through editstring
	while($editString =~ m/(\d+|[\^ACGTN]+)/g){
		my $change = $1;
#		warn "$chrom\t$cord\t$change\n";
		if ($change =~ m/(^\d+$)/){
			foreach (1..$change){
				push(@edit, 0);
				$c ++;
			}
		}else{
			if ($change =~ m/\^/){
				$change =~ s/\^//;
				$change = $strand ? uc($change) : lc($change);
				push(@deletions, '-' . length($change) . $change);
			}else{
				push(@edit, 1) foreach (1..length($change));
			}
			$c += length($change);
		}
	}
	$c = 0;
	# process CIGAR string
	while( $cigar =~ m/(\d+)([MIDS])/g){
		$length += $1 unless ($2 eq 'I');
		$length += $1 if ($2 eq 'D');
		$delCorrection -= $1 if ($2 eq 'D');
		if ($2 eq 'I'){
			my $insert;
			my @blank;
			foreach my $i (0..$1-1){
				push(@blank, 1);
				$insert .= $splitSeq[$c + $i + $delCorrection];
				$edit[$c + $i + $delCorrection]++;
			}
			splice(@edit,$delCorrection+$c-1,1,($edit[$delCorrection+$c-1], @blank));
			$insert = $strand ? uc($insert) : lc($insert);
			push(@insertions,  '+' . $1 . $insert);
		}
		if ($2 eq 'S'){
			if ($c < 1){
				unshift(@edit, '1') foreach (0..$1-1);
			}else{
				push(@edit, '1') foreach (0..$1-1);
			}
		}
		push(@read, $2) foreach (1..$1);
		$c+=$1;
	}

# 	if (scalar(@insertions) || scalar(@deletions)){
# 		print join("\n", $cigar,$editString ) . "\n";
# 		print "INSERT:\t" . join("\t", @insertions ) . "\n";
# 		print "DELETIES:\t" . join("\t", @deletions ) . "\n";
# 		print join("",@edit) . "\n\n";
# 
# 	}

	foreach my $p (0..$#edit){

		$misbin->[$p]->[$edit[$p]]++;
		$mispos->[$strand]->[$p]+= $edit[$p];
	}

}

open (STATS, ">$cfn.binmismatch.stats");
	foreach my $p ( @$misbin ) {
		foreach my $e (@$p){
			if (defined($e)){
				print STATS $e;
			}else{
				print STATS 0;
			}
			print STATS "\t";
		}
		print STATS "\n"; 
	}
close(STATS);

open (STATS, ">$cfn.strandmismatch.stats");
	foreach my $p ( @$mispos ) {
		foreach my $e (@$p){
			if (defined($e)){
				print STATS $e;
			}else{
				print STATS 0;
			}
			print STATS "\t";
		}
		print STATS "\n"; 
	}
close(STATS);