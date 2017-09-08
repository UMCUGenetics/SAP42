#!/usr/bin/perl -w

# -b BAM file
# -d directory to search for raw data files to merge
# -p location to write pdf to
# -s location of summary file
# -i location of graphs
# -R path to R (optional, default is /usr/bin/R)
# --id runname_samplename_libraryname_libtag
# -h print options

package postmap_merge;

use lib $ARGV[$#ARGV];
use lib $ARGV[$#ARGV] . '/QC';

#use lib '/data/common_modules';
use strict;
use Getopt::Long;
use postmap_plotter;
use Number::Format;

my $samtools;

sub new{
    my ($class) = @_;
    my $self = {};
    $self -> {'BAM'} = '';
    $self -> {'INDIR'} = '';
    $self -> {'PDFDIR'} = '';
    $self -> {'SUMDIR'} = '';
    $self -> {'IMGDIR'} = '';
    $self -> {'RPATH'} = '/usr/bin/R';
    $self -> {'ID'} = '';
    $self -> {'CLONALITY_FILE'} = '';
 
    my @timeData = localtime(time);
    my $currentYear = 1900 + $timeData[5];
    my $month = $timeData[4]+1;
    my $day = $timeData[3];
    my $hours = $timeData[2];
    my $minutes = $timeData[1];
	
    $self->{_timeStamp} = "_".$currentYear."_".$month."_".$day."_".$hours."_".$minutes;
    $self->{_timeStamp_month} = "_".$currentYear."_".$month;

    bless($self, $class);
    return $self;
}

sub parseID{
    my $self = shift;
    
#     my @idParts = split("_", $self->{'ID'});
#     $self -> {'RUN'} = join('_', @idParts[0..scalar(@idParts)-4]);
#     $self->{'SAMPLE'} = $idParts[4];
#     $self -> {'LIBRARY'} = $idParts[5];
#     $self -> {'TAG'} = $idParts[6];

    ($self -> {'RUN'},$self->{'SAMPLE'}, $self -> {'LIBRARY'}, $self -> {'TAG'}) = split(/\^/, $self->{'ID'})

}



sub init{
	my $self = shift;

	GetOptions ("d=s" =>\my $d,"s=s" => \my $s,"p=s" => \my $p, "R=s" => \my $r, "i=s"=>\my $i, "id=s" => \my $id, "h=s" => \my $h, 'b=s' => \my $b, "samtools=s" => \$samtools);
	
	if($h){
		die $self -> help();
    	}

	if($b and -e $b){
		$self->{'BAM'} = $b;
	}else{
		print $self -> error('Please specify a valid .bam file. (Option -b <bam>)\n');
		die $self -> help();
	}


	if($d and -d $d){
		$self -> {'INDIR'} = $d;
	}else{
		print $self -> error('Please specify a valid directory containing .post files. (Option -d)');
		die $self -> help();
	}

	if($s and -d $s){
		$self->{'SUMDIR'} = $s;
	}else{
		print $self -> error('Please specify a valid directory to write the summary file to. (Option -s <dir>)');
		die $self -> help();
	}

	if($p and -d $p){
		$self->{'PDFDIR'} = $p;
	}else{
		print $self -> error('Please specify a valid directory to write the PDF to. (Option -p <dir>)');
		die $self -> help();
	}

	if($r and -d $r){
		$self->{'RPATH'} = $r;
	}

	if($i and -d $i){
		$self->{'IMGDIR'} = $i;
	}else{
		print $self -> error('Please specify a valid directory to write the graph to. (Option -i <dir>)');
		die $self -> help();
	}

	if($id){
		$self->{'ID'} = $id;
		$self->parseID();
	}else{
		print $self -> error('No ID specified. (Option --id <name>');
		die $self -> help();
	}

	
	open(CL,"find ". $self -> {'INDIR'} ." -name \"*postclon\" |");
	while(<CL>){chomp; $self -> {'CLONALITY_FILE'} = $_; last}
	close CL;

	if(! $self -> {'CLONALITY_FILE'}){
		print $self -> warning("No .postclon file found in ".$self -> {'INDIR'}.", clonality could not be calculated");
	}

}

sub go{
	my $self = shift;


	my $in = $self->{'INDIR'};

	while(<$in/*.post>){
		chomp;
		
		my $file = $_;

	        open (POST, "<".$file) or die "Failed to open $file \n";
	        
	        while(<POST>){
			chomp;
	    		my $line = $_;

			if($line =~ m/#reference\s(.*)/){$self->{'REFERENCE'}=$1}
			elsif($line =~ m/#nr_mapped\s(\d+)/){$self->{'NR_MAPPED'}+=$1} 
			elsif($line =~ m/#mapping\s(.+?)\s(\d+)/){$self->{'MAPPING'}->{$1} += $2}
			elsif($line =~ m/#unambiguously_mapped\s(\d+)/){$self->{'UNAMBIGUOUS'}+=$1}
			elsif($line =~ m/#ambiguously mapped\s(\d+)\s(\d+)/){$self->{'AMBIGUITY'}->{$1} += $2}
			elsif($line =~ m/#footprint\s(\d+)/){$self->{'FOOTPRINT'}=$1}
			elsif($line =~ m/#mismatch\s(\d+)\s(\d+)/){$self->{'READ_MISMATCHES'}->{$1} += $2}
			elsif($line =~ m/#mapqual\s(\d+)\s(\d+)/){$self->{'MAPPING_QUALITIES'}->{$1} += $2}
			elsif($line =~ m/#pos_mismatch\s(\d+)\s(\d+)/){$self->{'POS_MISMATCHES'}->{$1+1} += $2}
			elsif($line =~ m/#nr_readbases\s(\d+)/){$self->{'NR_READBASES'}+=$1}
			elsif($line =~ m/#nr_basesintarget\s(\d+)/){$self->{'NR_INTARGETBASES'}+=$1}
			elsif($line =~ m/#nr_basesinflanks\s(\d+)/){$self->{'NR_INFLANKBASES'}+=$1}
			elsif($line =~ m/#coverage\s(.*)\s(\d+)/){$self->{'COVERAGE'}->{$1} += $2}
			elsif($line =~ m/#complexity\s(.*)\s(\d+)\s(\d+)/){$self->{'COMPLEXITY'}->{$1}->{$2} += $3}

# "#complexity\trv\t$key\t".$self->{'COMPLEXITY'}->{'rv'}->{$key}."\n";

	    	}
	    	close POST;
	}
	
	open (CLON, "<" . $self -> {'CLONALITY_FILE'});
	while(<CLON>){
		chomp;
		my $line = $_;
		next if ! $line;
		my ($clo, $occ) = split("\t", $line);

		if($clo == 1){$self->{'CLONALITY'}->{'1'} += $occ}
		elsif($clo < 10){$self->{'CLONALITY'}->{'2-<10'}+= $occ}
		elsif($clo < 100){$self->{'CLONALITY'}->{'10-<100'}+= $occ}
		elsif($clo < 1000 ){$self->{'CLONALITY'}->{'100-<1000'}+= $occ}
		elsif($clo < 10000){$self->{'CLONALITY'}->{'1000-<10000'}+= $occ}
		else{$self->{'CLONALITY'}->{'10000+'}+= $occ}



	}

# 	foreach my $key (keys %{$self->{'CLONALITY'}}){
# 		print "key \t".$key."\t". $self->{'CLONALITY'}->{$key}. "\n";
# 	}
	close CLON;

	my $flagName = substr((split('/', $self->{'BAM'}))[-1], 0,-4);
	#my $flagstat_command = "$samtools flagstat " . $self->{'BAM'} . " > ".$self->{'PDFDIR'} . "/".$flagName . ".flagstat";
	# Take care: flagstat layout has changed in samtools 0.1.18 Switched it temp to older samtools
	
	my $flagstat_command = "$samtools flagstat " . $self->{'BAM'} . " > ".$self->{'PDFDIR'} . "/".$flagName . ".flagstat";
 	
 	#print $flagstat_command. "\n\n";

	`$flagstat_command`;

	open (QS, "<" . $self->{'PDFDIR'} . "/".$flagName . ".flagstat") or die "Couldn't open flagstat file";

	my $line1 = <QS>;
	<QS>;
	my $line3 = <QS>;
	my $line4 = <QS>;
	close QS;

	if($line1 =~ m/^(\d+) \+ \d+ in total/){
		$self->{'TOTAL_READS'} = $1;

	}elsif($line1 =~ m/^(\d*) in total/){

		$self->{'TOTAL_READS'} = $1;
		
	}
	
	#check whether mapped reads in flagstat corresponds with mapped reads from post chunks
	my $nrmapped = 0;
	if($line3 =~ m/^(\d+) \+ \d+ mapped/){
		$nrmapped = $1;	
	
	}if($line4 =~ m/^(\d+) mapped/){
		$nrmapped = $1;
	}	

	if($nrmapped != $self->{'NR_MAPPED'}){
		die "Error: nr of mapped reads from .post chunks (".$self->{'NR_MAPPED'}.") does not correspond with nr of mapped reads from flagstat ($nrmapped)\n";
	}

 	$self->{'MAPPING'}->{'UNMAPPED'}= ($self->{'TOTAL_READS'}-$self->{'MAPPING'}->{'FORWARD'})-$self->{'MAPPING'}->{'REVERSE'};

	


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

	my $sumname = $self -> {'SUMDIR'}.'/Post_'.$id.$self->{_timeStamp}.'.summ';
	my @path_parts = split("/",$self -> {'INDIR'});

	my $runsummary = join('/',@path_parts[0..$#path_parts-4]).'/'.$self -> {'RUN'}.$self->{_timeStamp_month}.".stats_overview";
	my $runsum_line = '';
	if(! -s $runsummary){
		$runsum_line .= "LIBRARY\tTOTALREADS\tTOTAL_MAPPED\t%_mapped\tFW_MAPPED\t%_FW_MAPPED\tRV_MAPPED\t%_RV_MAPPED\tUNIQUE_MAPPED\t%_UNIQUE_MAPPED\tINTARGET_BASES\t%_INTARGET\tAVG_COVERAGE\tMED_COVERAGE\tPC_UNCOV\tPC_COV>=1\tPC_COV>=20\tEVENNESS\tCOMPLEXITY_FW\tCOMPLEXITY_RV\n";
	}
	$runsum_line .= $self->{'SAMPLE'}.'_'.$self->{'LIBRARY'}.'_'.$self->{'TAG'}."\t";
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

	my $nr_reads = $self->{'TOTAL_READS'};
	my $nr_reads_fm = $fn->format_number($nr_reads);
	my $nr_mapped = $fn->format_number($self -> {'NR_MAPPED'});
	my $pc_mapped = $fp->format_number(($self -> {'NR_MAPPED'}/$nr_reads)*100);
	my $nr_unique = $fn->format_number($self->{'UNAMBIGUOUS'});
	my $pc_unique = $fp->format_number(($self->{'UNAMBIGUOUS'}/$nr_reads)*100);
	$runsum_line .= "$nr_reads_fm\t$nr_mapped\t($pc_mapped)\t";

	open(SUMMARY, ">$sumname") or die "Failed to create summary file: $sumname !\n";
	

	print SUMMARY "#########Mapping#########\n";
	print SUMMARY "\tReads processed:\t$nr_reads_fm\n";
	print SUMMARY "\tReads mapped:\t\t$nr_mapped ($pc_mapped %)\n";
 	

	my $nr = $fn->format_number($self->{'MAPPING'}->{'FORWARD'});
	my $pc = $fp->format_number(($self->{'MAPPING'}->{'FORWARD'}/$nr_reads)*100);
	print SUMMARY "\t\tFORWARD:\t$nr ($pc %)\n";
	$runsum_line .= "$nr\t($pc)\t";

	$nr = $fn->format_number($self->{'MAPPING'}->{'REVERSE'});
	$pc = $fp->format_number(($self->{'MAPPING'}->{'REVERSE'}/$nr_reads)*100);
	print SUMMARY "\t\tREVERSE:\t$nr ($pc %)\n";
	$runsum_line .= "$nr\t($pc)\t";

	$nr = $fn->format_number($self->{'MAPPING'}->{'UNMAPPED'});
	$pc = $fp->format_number(($self->{'MAPPING'}->{'UNMAPPED'}/$nr_reads)*100);
	print SUMMARY "\t\tUNMAPPED:\t$nr ($pc%)\n";

	print SUMMARY "\tReads unambiguously mapped:\t$nr_unique ($pc_unique %)\n";
	$runsum_line .= "$nr_unique\t($pc_unique)\t";
	print SUMMARY "\tReads ambiguously mapped (n) times:\n";

	for(my $i = 2; $i <= 10; $i++){
		my $nr = $fn->format_number($self->{'AMBIGUITY'}->{$i});
		my $pc = $fp->format_number(($self->{'AMBIGUITY'}->{$i}/$nr_reads)*100);
		if($i == 10){
			print SUMMARY "\t\t>=10\t".$nr." ($pc %)\n";
		}else{
			print SUMMARY "\t\t$i\t".$nr." ($pc %)\n";
		}
	}

	print SUMMARY "\n#########Mismatches (in uniquely mapped reads)#########\n";
	foreach my $key(sort{$a<=>$b} keys %{$self->{'READ_MISMATCHES'}}){
		my $nr = $fn->format_number($self->{'READ_MISMATCHES'}->{$key});
		my $pc = $fp->format_number(($self->{'READ_MISMATCHES'}->{$key}/$self->{'UNAMBIGUOUS'})*100);

		print SUMMARY "\tReads with $key mismatch(es):\t$nr ($pc %)\n";
	}


	print SUMMARY "\n#########Mapping quality (in uniquely mapped reads)#########\n";
	foreach my $key(sort{$a<=>$b} keys %{$self->{'MAPPING_QUALITIES'}}){
		my $nr = $fn->format_number($self->{'MAPPING_QUALITIES'}->{$key});
		my $pc = $fp->format_number(($self->{'MAPPING_QUALITIES'}->{$key}/$self->{'UNAMBIGUOUS'})*100);

		print SUMMARY "\tReads with mapping quality $key:\t$nr ($pc %)\n";
	}

	print SUMMARY "\n#########Number of mismatches per position (in uniquely mapped reads)#########\n";
	foreach my $key(sort{$a<=>$b} keys %{$self->{'POS_MISMATCHES'}}){
		my $nr = $fn->format_number($self->{'POS_MISMATCHES'}->{$key});
		my $pc = $fp->format_number(($self->{'POS_MISMATCHES'}->{$key}/$self->{'UNAMBIGUOUS'})*100);

		print SUMMARY "\tMismatches at position $key:\t$nr ($pc %)\n";
	}


	if(exists($self->{'NR_INTARGETBASES'})){
		print SUMMARY "\n#########Enrichment overview of:" .$self->{'REFERENCE'}."#########\n";

		my $read_bases = $fn->format_number($self->{'NR_READBASES'});
		my $target_bases = $fn->format_number($self->{'FOOTPRINT'});
		my $bases_it_nr = $fn->format_number($self->{'NR_INTARGETBASES'});
		my $bases_it_pc = $fp->format_number(($self->{'NR_INTARGETBASES'} / $self->{'NR_READBASES'}) * 100);
		my $bases_if = $fn->format_number($self->{'NR_INFLANKBASES'});

		$runsum_line .= "$bases_it_nr\t($bases_it_pc)\t";

		print SUMMARY "\tTarget bases:\t$target_bases\n";
		print SUMMARY "\tRead bases:\t$read_bases\n";
		print SUMMARY "\tRead bases on target:\t$bases_it_nr\n";
		print SUMMARY "\tRead bases in flanks:\t$bases_if\n";
	}else{
		$runsum_line .= "\t\t";
	}

	print SUMMARY "\n#########Coverage overview of:" .$self->{'REFERENCE'}."#########\n";
	print SUMMARY "Coverage\tPercentage of target\tPercentenage of total target covered\n";
	
	my $total_covered = 0;
	my $total_covered_20 = 0;
	my $avg_coverage = 0;
	my $med_coverage = 0;
	my $processed_pos = 0;
	my $coverage_evenness = 0;
	my $med_set = 0;
	my $iter = 0;
	my $uncovered = $self->{'FOOTPRINT'};

        foreach my $coverage(sort{$a <=> $b} keys %{$self->{'COVERAGE'}}){
		last if $uncovered <= 0;
        	
		if($self->{'COVERAGE'}->{$coverage} >= $uncovered){
			$uncovered = 0;
		}else{
			$uncovered -= $self->{'COVERAGE'}->{$coverage} if $coverage != 0;
		}

        #
	}
# 	print "Nr uncovered positions : $uncovered \n";
	
        $processed_pos = $uncovered;
	
	foreach my $coverage(sort{$a <=> $b} keys %{$self->{'COVERAGE'}}){
		if($iter == 0 and $processed_pos >= ($self->{'FOOTPRINT'} / 2)){
				$med_coverage = 0;
				$med_set = 1;
	
		}
		$iter = 1;


		$total_covered += $self->{'COVERAGE'}->{$coverage} if $coverage != 0;
		$total_covered_20 += $self->{'COVERAGE'}->{$coverage} if $coverage >= 20;
		my $pc_of_totalbases = ($self->{'COVERAGE'}->{$coverage} / $self->{'FOOTPRINT'}) * 100;
		my $pc_of_target_covered = ($total_covered / $self->{'FOOTPRINT'}) * 100;

		$avg_coverage += $coverage * $self->{'COVERAGE'}->{$coverage};
		$processed_pos += $self->{'COVERAGE'}->{$coverage};
		
		my $tot_base_pc = $fp->format_number($pc_of_totalbases);
		my $tot_target_pc = $fp->format_number($pc_of_target_covered); 

		print SUMMARY "$coverage\t$tot_base_pc\t$tot_target_pc\n";

		if($processed_pos >= ($self->{'FOOTPRINT'} / 2) and $med_set == 0){
			$med_set = 1;
			$med_coverage = $coverage;	

		}
	}
	
	$avg_coverage = $avg_coverage / $self->{'FOOTPRINT'};

	foreach my $coverage(sort{$b <=> $a} keys %{$self->{'COVERAGE'}}){
		if($coverage >= $avg_coverage){
			$coverage_evenness += (($coverage / ($avg_coverage * $self->{'FOOTPRINT'})) * $self->{'COVERAGE'}->{$coverage});
		}
	}

	$coverage_evenness = $fp->format_number($coverage_evenness * 100);
	
	$avg_coverage = $fp->format_number($avg_coverage);
	$med_coverage = $fp->format_number($med_coverage);

	my $pc_of_target_covered = $fp->format_number(($total_covered / $self->{'FOOTPRINT'}) * 100);
	my $pc_of_target_uncovered = $fp->format_number(100 - $pc_of_target_covered);
	my $pc_of_target_covered_20 = $fp->format_number(($total_covered_20 / $self->{'FOOTPRINT'}) * 100);

	$runsum_line .= "$avg_coverage\t$med_coverage\t$pc_of_target_uncovered\t$pc_of_target_covered\t$pc_of_target_covered_20\t$coverage_evenness\t";
	
	print SUMMARY "\nClonality overview\n";
	
	while(my ($clonality, $occurrence) = each(%{$self->{'CLONALITY'}})){
		print SUMMARY "Clonality\t$clonality\t".$fn->format_number($occurrence)."\n";
	}

	my $nr_starts_fw = 0;
	my $nr_starts_rv = 0;
	my $nr_ref_covered = 0;

	while(my ($nr_starts, $occurrence) = each(%{$self->{'COMPLEXITY'}->{'fw'}})){
		$nr_starts_fw += $occurrence if $nr_starts != 0;
		$nr_ref_covered += $occurrence;
	}
	
	while(my ($nr_starts, $occurrence) = each(%{$self->{'COMPLEXITY'}->{'rv'}})){
		$nr_starts_rv += $occurrence if $nr_starts != 0;
	}

	my $complexity_fw = ($nr_starts_fw / $nr_ref_covered) * 100;
	my $complexity_rv = ($nr_starts_rv / $nr_ref_covered) * 100;
	$runsum_line .=  ($fp->format_number($complexity_fw))."\t";
	$runsum_line .=  ($fp->format_number($complexity_rv))."\n";

	close SUMMARY;

	open(RUNSUM, ">>$runsummary") or die "Failed to append to runsummary file: $runsummary !\n";
	print RUNSUM $runsum_line;
	close RUNSUM;


}

sub write_pdf{
	my $self = shift;

	my %toPlot = ();
	$toPlot{'imgpath'} = $self ->{'IMGDIR'};
	$toPlot{'pdfpath'} = $self ->{'PDFDIR'};
	$toPlot{'name'} = $self ->{'ID'};

# 	$toPlot{'name'}  =~ s/\^/_/;

	$toPlot{'totalreads'} = $self->{'TOTAL_READS'};
	$toPlot{'rpath'} = $self->{'RPATH'};
	$toPlot{'reference'} = $self->{'REFERENCE'};

	if(exists($self->{'MAPPING'})){
		my $data ={};
		$data->{'FORWARD'} = $self->{'MAPPING'}->{'FORWARD'} ? $self->{'MAPPING'}->{'FORWARD'} : 0;
		$data->{'REVERSE'} = $self->{'MAPPING'}->{'REVERSE'} ? $self->{'MAPPING'}->{'REVERSE'} : 0;
		$data->{'UNMAPPED'} = $self->{'MAPPING'}->{'UNMAPPED'} ? $self->{'MAPPING'}->{'UNMAPPED'} : 0;
		
		$toPlot{'mapping'} = $data;
	}

	if(exists($self->{'UNAMBIGUOUS'}) and exists($self->{'AMBIGUITY'})){
		my $data = {};

		$data->{1} = $self->{'UNAMBIGUOUS'} ? $self->{'UNAMBIGUOUS'} : 0;
		for(my $i = 2; $i <= 10; $i++){
			$data->{$i} = $self->{'AMBIGUITY'}->{$i} ? $self->{'AMBIGUITY'}->{$i} : 0;
		}
		
		$toPlot{'ambiguity'} = $data;
	}

	if(exists($self->{'MAPPING_QUALITIES'})){
		my $data = {};

		for(my $i = 0; $i <= 37 ; $i++){
			$data->{$i} = $self->{'MAPPING_QUALITIES'}->{$i} ? ($self->{'MAPPING_QUALITIES'}->{$i} / $self->{'UNAMBIGUOUS'}) * 100 : 0;
		}

		$toPlot{'mapping_qualities'}= $data;				
	}

	if(exists($self->{'READ_MISMATCHES'})){
		my $data = {};

		for(my $i = 0; $i <= 10 ; $i++){
			$data->{$i} = $self->{'READ_MISMATCHES'}->{$i} ? $self->{'READ_MISMATCHES'}->{$i} :0;
		}	

		$toPlot{'read_mismatches'} = $data;
	}

	if(exists($self->{'POS_MISMATCHES'})){
		my $data = {};

		while( my ($pos, $nr) = each(%{$self->{'POS_MISMATCHES'}})){

			$data -> {$pos} = ($nr / $self -> {'UNAMBIGUOUS'}) * 100;
		}

		$toPlot{'pos_mismatches'} = $data;
	}

	if(exists($self->{'NR_INTARGETBASES'}) and exists($self->{'NR_INFLANKBASES'})){
		my $data = {};

		$data->{'Bases in flanks'} = $self->{'NR_INFLANKBASES'};
		$data->{'Bases in targets'} = $self->{'NR_INTARGETBASES'};
		$data->{'Bases outside flanks/targets'} = $self->{'NR_READBASES'}-$self->{'NR_INFLANKBASES'}-$self->{'NR_INTARGETBASES'};

		$toPlot{'on_target/flanks'} = $data;
	
	}

	if(exists($self->{'COVERAGE'})){
		my $data = {};
		my $total_covered = 0;
		
		my $avg_coverage = 0;
		my $med_coverage = 0;
		my $med_set = 0;
		my $iter = 0;
		my $processed_pos = 0;
		my $coverage_evenness = 0;
		
		my $tmp_data = $self -> {'PDFDIR'}."/cov_stats.txt";
		
		open(COV, ">$tmp_data") or die "Couldn't write to temporary coverage data dump $tmp_data\n";

		
		my $toPrint = "";
    		my $uncovered = $self->{'FOOTPRINT'};
    		
		foreach my $coverage(sort{$a <=> $b} keys %{$self->{'COVERAGE'}}){
			last if $uncovered <= 0;
			if($self->{'COVERAGE'}->{$coverage} >= $uncovered){
				$uncovered = 0;
			}else{
				$uncovered -= $self->{'COVERAGE'}->{$coverage} if $coverage != 0;
			}
    			
	
    	#
    		}

    		$processed_pos = $uncovered;

    		
		foreach my $coverage(sort{$a <=> $b} keys %{$self->{'COVERAGE'}}){
			if($iter == 0 and $processed_pos >= ($self->{'FOOTPRINT'} / 2)){
				$med_coverage = 0;
				$med_set = 1;
	
			}
			$iter = 1;
			

 			$total_covered += $self->{'COVERAGE'}->{$coverage} if $coverage != 0;

			my $pc_of_totalbases = ($self->{'COVERAGE'}->{$coverage} / $self->{'FOOTPRINT'}) * 100;
 			my $pc_of_target_covered = ($total_covered / $self->{'FOOTPRINT'}) * 100;

 			$avg_coverage += $coverage * $self->{'COVERAGE'}->{$coverage};
 			
 			$processed_pos += $self->{'COVERAGE'}->{$coverage};


			$toPrint .= "$coverage\t$pc_of_totalbases\t$pc_of_target_covered\n";
			

			if($processed_pos >= ($self->{'FOOTPRINT'} / 2) and $med_set == 0){
				$med_set = 1;
				$med_coverage = $coverage;
				

			}
			

		}
		$uncovered = ($uncovered / $self->{'FOOTPRINT'}) * 100;
		print COV "COVERAGE\tPC\tPC_TOT\n";
		print COV "0\t".$uncovered."\t0\n".$toPrint;

		close COV;
		
		$avg_coverage = $avg_coverage / $self->{'FOOTPRINT'};

		foreach my $coverage(sort{$b <=> $a} keys %{$self->{'COVERAGE'}}){
			if($coverage >= $avg_coverage){
				$coverage_evenness += (($coverage / ($avg_coverage * $self->{'FOOTPRINT'})) * $self->{'COVERAGE'}->{$coverage});
			}
		}

		$coverage_evenness = $coverage_evenness * 100;
# 		print $med_coverage . "\n";
		$self->{'TOT_COVERED'} = $total_covered;
		$toPlot{'coverage'} = [$tmp_data, $avg_coverage, $med_coverage, $coverage_evenness, $uncovered];
	}

	if(exists($self->{'CLONALITY'})){
		my $data = {};
		
		$data->{'1'} = 0;
		$data->{'2-<10'} = 0;
		$data->{'10-<100'} = 0;
		$data->{'100-<1000'} = 0;
		$data->{'1000-<10000'} = 0;
		$data->{'10000+'} = 0;

		while(my ($clonality, $occurrence) = each(%{$self->{'CLONALITY'}})){

			$data->{$clonality} = $occurrence;


		}

		$toPlot{'clonality'} = $data;

	}

	if(exists($self->{'COMPLEXITY'})){


 		my $nr_starts_fw = 0;
	 	my $nr_starts_rv = 0;
	 	my $nr_ref_covered = 0;
# 		my $read_length = scalar(keys %{$self->{'POS_MISMATCHES'}});

		my $compl_fw = $self -> {'PDFDIR'}."/compl_fw.txt";
		my $compl_rv = $self -> {'PDFDIR'}."/compl_rv.txt";
		
		open(FW, ">$compl_fw") or die "Couldn't write to temporary data dump $compl_fw\n";
		open(RV, ">$compl_rv") or die "Couldn't write to temporary data dump $compl_rv\n";

		foreach my $nr_starts (sort{$a <=> $b} keys %{$self->{'COMPLEXITY'}->{'fw'}}){
			my $occurrence = $self->{'COMPLEXITY'}->{'fw'}->{$nr_starts};
			$nr_starts_fw += $occurrence if $nr_starts != 0;
	 		$nr_ref_covered += $occurrence;
			
# 			my $ref_covered = ((($read_length * $occurrence) / $self->{'FOOTPRINT'}) * 100);

# 			print FW $nr_starts."\t".(($occurrence / $self->{'TOT_COVERED'})*100)."\n";
			print FW $nr_starts."\t".($occurrence / $self->{'NR_MAPPED'})."\n";
# 			$self->{'NR_MAPPED'}
		}

		foreach my $nr_starts (sort{$a <=> $b} keys %{$self->{'COMPLEXITY'}->{'rv'}}){
			my $occurrence = $self->{'COMPLEXITY'}->{'rv'}->{$nr_starts};
			$nr_starts_rv += $occurrence if $nr_starts != 0;

# 			print RV $nr_starts."\t".(($occurrence / $self->{'TOT_COVERED'})*100)."\n";
# 			my $ref_covered = ((($read_length * $occurrence) / $self->{'FOOTPRINT'}) * 100);
			print RV $nr_starts."\t".($occurrence / $self->{'NR_MAPPED'})."\n";
	 		
		}

 		my $complexity_fw = ($nr_starts_fw / $nr_ref_covered) * 100;
 		my $complexity_rv = ($nr_starts_rv / $nr_ref_covered) * 100;

		$toPlot{'complexity'} = [$compl_fw, $compl_rv, $complexity_fw,$complexity_rv];

# 		print $self->{'TOT_COVERED'} . "\t" . $nr_ref_covered . "\n";
	

	}






	my $plotter = new postmap_plotter(\%toPlot);
	$plotter->start();

	#unlink($self -> {'PDFDIR'}."/cov_stats.txt");
}

sub help{
    my $self = $_;
    
    return "
	Options:\n
	\t-h Print help\n
	\t-b BAM file\n
	\t-d Directory to search for raw .post files to merge\n
	\t-p Location to write pdf to\n
	\t-s Location to write summary file to\n
	\t-i Location to write graphs to\n
	\t-R Optional path to R (default is /usr/bin/R)\n
	\t--id runname_samplename_libraryname_optionallibtag\n
	Usage:\n
	\t perl postmap_merge.pm -d /data/project -p /home/data -s /home/data -i /home/data --id run_sam_lib_libtag\n
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
	my $merger = new postmap_merge();
	$merger->init();
	$merger->go();
	$merger->output();
}


main();
