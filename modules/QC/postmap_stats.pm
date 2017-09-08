#!/usr/bin/perl -w

package postmap_stats;

use strict;
use POSIX;

sub new{
	my ($class) = @_;
	my $self = {};

	$self->{'TOTAL_READS'} = 0;
	$self->{'MAPPED_READS'} = 0;
	$self->{'UNIQUE_MAPPED'} = 0;
	$self->{'MAPPING'} = {'FORWARD' => 0, 'REVERSE' => 0, 'UNMAPPED' => 0};
	$self->{'AMBIGUITY'} = {};
	$self->{'READMISMATCHES'} = {};
	$self->{'POSMISMATCHES'} = {};
	$self->{'QSCORES'} = {};
	$self->{'MAXTARGETSIZE'} = 0;
	$self->{'TARGETS'} = {};
	$self->{'TARGET_BASES'} = 0;
	$self->{'INPUT_BASES'} = 0;
	$self->{'UNCOVERED_BASES'} = 0;
	$self->{'INTARGET_BASES'} = 0;
	$self->{'INFLANK_BASES'} = 0;
	$self->{'COVERAGE'} = {};
	$self->{'CLONALITY'} = {};
	$self->{'COMPLEXITY'} = {};
	$self->{'ALLMATCH'} = qr/\^.([acgtACGT]+?)/;
	$self->{'UCMATCH'} = qr/[ACGT]+?/;
	$self->{'LCMATCH'} = qr/[acgt]+?/;


	bless $self, $class;
	return $self;
}





sub output{
	my ($self, $outDir, $outFile) = @_;
	
	open(OUT, ">".$outDir."/".$outFile.".post") or die "Error: Could not create .post stats file!\n";
	
	print OUT $self->outputAnalysis();
	close OUT;
}


sub outputAnalysis{
	my $self = shift;

	my $out = "\n";

	$out .= "#reference\t".$self->{'REF'}."\n";
	
	$out.= $self->{'MAPPED_READS'} ? "\n#nr_mapped\t".$self->{'MAPPED_READS'}."\n" : "\n#nr_mapped\t0";

	$out.= $self->{'MAPPING'}->{'FORWARD'} ? "#mapping\tFORWARD\t".$self->{'MAPPING'}->{'FORWARD'}."\n" : "#mapping\tFORWARD\t0\n";
	$out.= $self->{'MAPPING'}->{'REVERSE'} ? "#mapping\tREVERSE\t".$self->{'MAPPING'}->{'REVERSE'}."\n" : "#mapping\tREVERSE\t0\n";

	$out.= "\n#unambiguously_mapped\t".$self->{'UNIQUE_MAPPED'}."\n";
	foreach my $key (sort {$a <=> $b} keys %{$self->{'AMBIGUITY'}}){
		$out.= "#ambiguously mapped\t$key\t".$self->{'AMBIGUITY'}->{$key}."\n";
	}
	
	foreach my $key(keys %{$self->{'READMISMATCHES'}}){
		$out.= "#mismatch\t".$key."\t".$self->{'READMISMATCHES'}->{$key}."\n";
	}

	foreach my $key(keys %{$self->{'POSMISMATCHES'}}){
		$out.= "#pos_mismatch\t".$key."\t".$self->{'POSMISMATCHES'}->{$key}."\n";
	}

	foreach my $key(keys %{$self->{'QSCORES'}}){
		$out.= "#mapqual\t".$key."\t".$self->{'QSCORES'}->{$key}."\n";
	}

	$out.= "#footprint\t".$self->{'TARGET_BASES'}."\n";
	
	my $sum = {};

	foreach my $nr (keys %{$self->{'COVERAGE'}}){
# 		
		$sum->{$nr} += $self->{'COVERAGE'}->{$nr};
			
	}
# 	}

	$out.= "#nr_readbases\t".$self->{'INPUT_BASES'}."\n";

	if($self->{'INTARGET_BASES'} != 0){
		$out.= "#nr_basesintarget\t".$self->{'INTARGET_BASES'}."\n";
		$out.= "#nr_basesinflanks\t".$self->{'INFLANK_BASES'}."\n";
	}
	
# 	$out .= "#coverage\t0\t".$self->{'UNCOVERED_BASES'}."\n";
	foreach my $key(keys %{$sum}){
		$out.= "#coverage\t".$key."\t".$sum->{$key}."\n";
	}
# 

	foreach my $key(keys %{$self->{'COMPLEXITY'}->{'fw'}}){
		$out.= "#complexity\tfw\t$key\t".$self->{'COMPLEXITY'}->{'fw'}->{$key}."\n";
	}

	
	foreach my $key(keys %{$self->{'COMPLEXITY'}->{'rv'}}){
		$out.= "#complexity\trv\t$key\t".$self->{'COMPLEXITY'}->{'rv'}->{$key}."\n";
	}

	return $out;

}


sub analyze_basic{
	my ($self, $fields) = @_;
	

	
	$self->{'TOTAL_READS'}++;

	#CHECK READ MAPPING
	if($fields->[1] & 4){
		$self->{'MAPPING'}->{'UNMAPPED'}++;
		return;
	}
 	elsif($fields->[1] & 16){
		$self->{'MAPPING'}->{'REVERSE'}++;
		$self->{'MAPPED_READS'}++;
	}else{
		$self->{'MAPPING'}->{'FORWARD'}++; 
		$self->{'MAPPED_READS'}++;
	}


	my $ambiguity ='';
	my $strand = $fields->[1];	
	my $cigar = $fields->[5];
	my $seq = $fields->[9];
	my $edit;
	my $mismatches;
	

	for(my $i = 0 ; $i<scalar(@{$fields}); $i++){
		if($fields->[$i] =~  m/X0:i:(\d+)/){
			$ambiguity = $1;
		}elsif($fields->[$i] =~ m/MD:Z:[0-9]+(([A-Z]|\^[A-Z]+)[0-9]+)*/){
			$edit = $fields->[$i];
		}elsif($fields->[$i] =~ m/XM:i:(\d{1,2})/){
			$mismatches = $1;
		}
	}


	#CHECK IF READ MAPS UNAMBIGUOUSLY
	die $self->error('No ambiguity field X0 found') if $ambiguity eq '';
	
	
# 	print $ambiguity . "\t" . $fields->[1] . "\n";
	if($ambiguity == 1){
		$self -> {'UNIQUE_MAPPED'}++;
	}elsif($ambiguity <=9){
		$self -> {'AMBIGUITY'}->{$ambiguity}++;
		return;
	}elsif($ambiguity > 9){
		$self -> {'AMBIGUITY'}->{10}++;
		return;
	}else{
		print $self->warning('No ambiguity field found');
		return;
	}

# 	print $ambiguity . "\t" . $fields->[1] . "\t". $seq . "\n";

	#CHECK IF READ CONTAINS MISMATCHES
	if(defined($mismatches)){
		$self -> {'READMISMATCHES'}-> {$mismatches}++;
	}else{
		print $self->warning('No mismatch field found');

	}

	#CHECK READ MEAN QUALITY SCORE
	$self -> {'QSCORES'} -> {$fields->[4]}++;

	#CHECK MISMATCHES PER POSITION
	if(!defined($edit)){
		print $self->warning('No edit string found');
	}
	if(!defined($cigar)){
		print $self->warning('No cigar string found');
	}

	$edit =~ s/MD:Z://;
	my $bin_seq = $self->_parse_edit($edit, $seq);
	my $se = $self->_parse_cigar($cigar, $bin_seq);

 	$se = reverse($se) if $strand & 16; # if $strand == 16
 	
 	my @splitSeq = split(//,$se);

	for(0..@splitSeq-1){
		if($splitSeq[$_] =~ m/[1-3]/){$self->{'POSMISMATCHES'}->{$_} += 1}
		else{$self->{'POSMISMATCHES'}->{$_} += 0}
	}


}

sub analyze_coverage{
	my @opts = @_;
	my $self=$opts[0];
	my $design = '';
	my $gaps = '';
	my $refsize = '';
	my $bam = $_[2];
	my $flanks = 0;
	my $region = $opts[$#opts];

	my $mode = $opts[1];
	if($mode eq 'enrichment'){
		$design = $opts[3];
		$self->{'REF'}=$design;
		$flanks = $opts[4];
		$self -> _add_targets($design);
		$self -> _collapse_targets();
		my $fp = $self -> _get_targetfootprint();
		$self-> {'TARGET_BASES'} = $fp;
		$self-> {'UNCOVERED_BASES'} = $fp;
		$self -> _index_targets();
		
	}elsif($mode eq 'gaps'){
		$gaps = $opts[3];
		$self->{'REF'}=$gaps;
		$refsize = $opts[4];
		$self -> _add_targets($gaps);
		$self -> _collapse_targets();
		my $fp = $self -> _get_targetfootprint();
		$self->{'TARGET_BASES'} = $refsize-$fp;
		$self->{'UNCOVERED_BASES'} = $refsize-$fp;
		$self -> _index_targets();

	}else{
		$refsize = $opts[3];
		$self->{'REF'} = $refsize;
		$self->{'TARGET_BASES'} = $refsize;
		$self->{'UNCOVERED_BASES'} = $refsize;
	}
	
	open (PU, "/hpc/cog_bioinf/common_scripts/samtools/samtools view -u $bam $region | /hpc/cog_bioinf/common_scripts/samtools/samtools mpileup - |");
	my $progress = 0;
	while(<PU>){
		chomp;
		my $line = $_;
		$self -> _intarget_analysis(\$line, $flanks, $mode);

		$progress++;
		if($progress % 100000 == 0){
			print "Analyzed $progress reference bases for coverage\n";

		}
	}
	print "Analyzed $progress reference bases for coverage\n";

	close PU;

}

#ADD TARGETS
sub _add_targets{
	my ($self, $bed) = @_;

	open (BED, "<$bed") or die $self->error("Couldn't open .bed file $bed");

	while(<BED>){
		chomp;
		my $line = $_;
		next if $line =~ m/^#/;
		next if $line =~ m/^track/;
		my ($chrom, $start, $stop) = split(/\t/, $line);

		if($stop-$start > $self->{'MAXTARGETSIZE'}){$self -> {'MAXTARGETSIZE'} = $stop-$start}
	
		$chrom =~ s/chr//;
		$self -> {'TARGETS'} -> {$chrom} -> {$start} -> {$stop} = 0;
	}
	close BED;

}

#COLLAPSE TARGETS, E.G. MERGE OVERLAPPING TARGETS
sub _collapse_targets{
	my $self = shift;

	my $targets = {};

	my $lib = $self->{'TARGETS'};
	foreach my $chrom (keys %$lib){
		my $start = 0;
		my $stop = 0;
		foreach my $s (sort{$a <=> $b} keys %{$lib->{$chrom}}){
			foreach my $st (keys %{$lib->{$chrom}->{$s}}){
				if ($start == 0 && $stop == 0){
					$start = $s;
					$stop = $st;
 					$targets->{$chrom}->{$start}=$stop;
					next;
				}
				if($s >= $start && $s <= $stop+1 && $st > $stop){
					$stop = $st;
 					$targets->{$chrom}->{$start}=$stop;
				}elsif($s > $stop+1){
					$targets->{$chrom}->{$start}=$stop;
					$start = $s;
					$stop = $st;
		
				}
			}
 			$targets->{$chrom}->{$start}=$stop;
		}
 		$targets->{$chrom}->{$start}=$stop;
	}
	$self-> {'TARGETS'} = $targets;
}
#INDEX TARGETS
sub _index_targets{
	my $self = shift;
	my $targets ={};

	my $lib = $self-> {'TARGETS'};

	if($self->{'MAXTARGETSIZE'} < 10000){$self->{'MAXTARGETSIZE'} =  20000}

	foreach my $chrom (keys %$lib){
		foreach my $start (sort{$a <=> $b} keys %{$lib->{$chrom}}){
# 			$self->{_nr_targets}++;
			my $index1 = floor($start/$self->{'MAXTARGETSIZE'});
    			my $index2 = floor($lib->{$chrom}->{$start}/$self->{'MAXTARGETSIZE'});
 			my $range = "$start:".$lib->{$chrom}->{$start};

			$targets->{$chrom}->{$index1} -> {$range} =0;
			$targets->{$chrom}->{$index2} -> {$range} =0;
		}
	}
	$self-> {'TARGETS'} = $targets;
}


sub _get_targetfootprint{
	my $self = shift;	
	my $fp = 0;

	foreach my $chrom (keys %{$self->{'TARGETS'}}){
 		foreach my $s (keys %{$self->{'TARGETS'}->{$chrom}}){
			my $add = ($self->{'TARGETS'}->{$chrom}->{$s} - $s);
			$fp+=$add;
 		}
	}

	return $fp;
 	

}

sub _checkStartPositions{
	my ($self, $bases) = @_;

	my $nr_fw = 0;
	my $nr_rv = 0;
	$bases = $$bases;
	my $allMatch = $self->{'ALLMATCH'};
	my $ucMatch = $self->{'UCMATCH'};
	my $lcMatch = $self->{'LCMATCH'};

	while($bases =~ m/$allMatch/g){
		my $match = $1;

		if($match =~ m/$lcMatch/){
	    		$nr_rv++;
	  	}elsif($match =~ m/$ucMatch/){
	    		$nr_fw++;
	  	}
	}
	$self->{'COMPLEXITY'}->{'fw'}->{$nr_fw}++;
	$self->{'COMPLEXITY'}->{'rv'}->{$nr_rv}++;

}



sub _intarget_analysis{
	my ($self, $read, $flank, $mode) = @_;

	my @line = split(/\t/,$$read);
	
	my $chrom = $line[0];
	my $start = $line[1];
	my $cov = $line[3];
	my $bases = $line[4];
# 	
# 	print $mode."\n";


	$self->{'INPUT_BASES'}+=$cov;
	
	if($mode eq 'whole'){
		$self-> {'UNCOVERED_BASES'}-- if $self-> {'UNCOVERED_BASES'} != 0;
		$self->{'COVERAGE'}->{$cov}++;

		$self->_checkStartPositions(\$bases);


	}elsif($mode eq 'enrichment'){
		my $index = floor($start/$self->{'MAXTARGETSIZE'});
		if(exists($self->{'TARGETS'} ->{$chrom} -> {$index})){
			foreach my $key(keys %{$self->{'TARGETS'} -> {$chrom} -> {$index}}){
				my @range = split(/:/, $key);

				if($start >= $range[0] and $start <= $range[1]){

					$self->{'INTARGET_BASES'}+=$cov;
					$self->{'COVERAGE'}->{$cov}++;
					$self->{'UNCOVERED_BASES'}-- if $self-> {'UNCOVERED_BASES'} != 0;
					$self->_checkStartPositions(\$bases);
					last;
		
				}elsif($start>=$range[0]-$flank and $start<= $range[1]+$flank){
					$self->{'INFLANK_BASES'}+=$cov;
					last;
				}
			}
		}
	}elsif($mode eq 'gaps'){
		my $index = floor($start/$self->{'MAXTARGETSIZE'});
		if(exists($self->{'TARGETS'} ->{$chrom} -> {$index})){
			my $ingap = 0;
			foreach my $key(keys %{$self->{'TARGETS'} -> {$chrom} -> {$index}}){
				my @range = split(/:/, $key);

				if($start >= $range[0] and $start <= $range[1]){
					$ingap = 1;
					last;
				}				
			}
			if ($ingap == 0){
				$self->{'COVERAGE'}->{$cov}++;
				$self->{'UNCOVERED_BASES'}-- if $self-> {'UNCOVERED_BASES'} != 0;
				$self->_checkStartPositions(\$bases);
			}
		}
	}
}




sub _parse_edit{
	my ($self, $edit, $seq) =@_;
	my $ret = "";
	my $index = 0;
	
	while ($edit =~ m/(\d+|[\^ACGTN]+)/g){

		my $s = $1;

		if($s =~ m/(\d{1,2})/){
			my $len = $1;
			next if $len == 0;
			if($len > length($seq) or $index > length($seq)){
				print "Skipping: $seq\n Edit: $edit\n Length: $len";
				next;
			}
# 			
			my $sub = substr($seq, $index, $len);
			$sub =~ s/[ACGTN]/0/g;
			$ret.= $sub;
			$index += $len;
		}

		elsif($s =~ m/(^[ACGTN]+)/){
			my $len = $1;
			if($index > length($seq)){
				print "Skipping: $seq\n Edit: $edit\n Length: $len\n";
				next;
			}
			
			my $sub = substr($seq, $index, length($len));
			$sub =~ s/[ACGTN]/1/g;
			$ret.= $sub;
			$index += length($len);
		}
	}
	return $ret;
}

sub _parse_cigar{
	my ($self, $cigar, $seq) = @_;

	my $index = 0;
	my $ret = "";

	while($cigar =~ m/([0-9]+[MIDS]{1})/g){
		my $mod = $1;

		my $mod_t = chop($mod);
		
		if($mod_t eq 'M'){
			$index+=$mod;
		}
		elsif($mod_t eq 'I'){
			#print "$index ", length($seq),"\n";
			my $sub1 = substr($seq, 0, $index);
			my $sub2 = substr($seq, $index, length($seq));
			
 			for(1..$mod){$sub1.=2}
			$seq = $sub1.$sub2;	
		}
		elsif($mod_t eq 'S'){
			my $sub1="";
			for(1..$mod){$sub1.=3}
			$seq = $sub1.$seq;
		}
	}
	return $seq;
}

sub warning{
	my ($self, $message) = @_;
	
	return "Warning: ".$message." \n";
}



sub error{
    my ($self, $message) = @_;
    
    return "Error: ".$message." exiting application!\n";
}

1;

