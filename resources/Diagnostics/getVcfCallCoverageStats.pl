#!/usr/bin/perl -w
use strict;
use File::Basename;
use Data::Dumper;
use Getopt::Long;
use Cwd;
use List::Util 'max';
#use lib "/data/common_scripts/vcftools/perl/"; # for Vcf.pm
use Vcf; # vcf tools for parsing vcf input

## --------------------------
## This script determines the percentage of called positions in genes
## by searching region-positions in provided VCF file(s)
## and outputs to output dir:
## - the % called per sample 
## - the % called per gene (overlap is used for multiple transcripts)
## - the uncalled regions
## - the input files for ExonCallCov (if requested)
## --------------------------
my $SCRIPT = fileparse($0);
my $CWD = cwd();
my $CMD_LINE = join(" ", @ARGV );
my $CODE_DIR = dirname(__FILE__);
my $HELP     = undef;
my $DEBUG    = undef;
my $KEEP_TMP = undef;

my @VCF_FILES = ();
my $REG_FILE = undef;
my $OUT_NAME = undef;
my $OUT_DIR  = undef;

my $VCF_FILTER_REGEX = '^PASS$';
my $MIN_NOCALL_REGION_SIZE = 1;
my $FLANK = 0;
my $SEP = '|';
my $ZIP_INSTALLED = 0;
my $VCFTOOLS_BIN = '';
my $GET_EXONCOV = undef;
my $OVERWRITE = undef;
my $OLD_INPUT_FORMAT = undef; # only for allowing old diagnostiek design
my $KEEP_SNP_SAMPLES = undef; # by default some sample-names are removed from analysis
my @SNP_SAMPLES = qw( man1 man2 vrouw1 vrouw2 );
my @LIMITS = qw( 1 5 10 15 20 25 50 100 200 500 1000 );
my @exclude = (); # can hold samples to skip (all other are analysed)
my @include = (); # can hold samples to analyse (only these analysed)

## parse command line options
## --------------------------
die usage() if @ARGV == 0;
GetOptions ( 
	'help|h|?'       => \$HELP, 
	'vcf|v=s@'       => \@VCF_FILES,
	'design|d=s'     => \$REG_FILE,
	'outdir=s'       => \$OUT_DIR,
	'outname=s'      => \$OUT_NAME,
	'flank=i'        => \$FLANK,
	'exclude=s@'     => \@exclude,
	'include=s@'     => \@include,
	'vcftools_bin=s' => \$VCFTOOLS_BIN,
	'vcf_filter=s'   => \$VCF_FILTER_REGEX,
	'exoncov'        => \$GET_EXONCOV,
	'overwrite'      => \$OVERWRITE,
	'keep_tmp'       => \$KEEP_TMP,
	'old_format'     => \$OLD_INPUT_FORMAT,
	'kss'            => \$KEEP_SNP_SAMPLES,
	'rrs=i'          => \$MIN_NOCALL_REGION_SIZE,
	'debug'          => \$DEBUG,
) || die "[ERROR] Illegal arguments or parameters: @ARGV\n";
die usage() if $HELP;

## check input and output settings
## --------------------------
die "[ERROR] No vcf-file(s) given\n" unless (scalar(@VCF_FILES) > 0);
@VCF_FILES = @{checkInputForWildcard( \@VCF_FILES )};

foreach ( @VCF_FILES ){
    die "[ERROR] Vcf-file not found/readable? ($_)\n" unless (-f $_);
    die "[ERROR] Vcf-file must be bgzip (.gz) + tabix indexed (.tbi file) for vcftools ($_)\n" unless ($_ =~ /\.gz$/ and -f $_.'.tbi');
}
die "[ERROR] No regions-file given or file not found\n" unless (defined $REG_FILE and -f $REG_FILE);
die "[ERROR] No output directory given (-outdir)\n" unless (defined $OUT_DIR);
die "[ERROR] No output name given (-outname)\n" unless (defined $OUT_NAME);
die "[ERROR] Either include OR exclude samples pls..\n" if (scalar(@include) and scalar(@exclude));
print "[INFO] Current working dir: ".cwd()."\n";

## get svn version of file
my $SVN_VERSION = 'NA';
my $svn_version_code = "svn info $CODE_DIR/$SCRIPT | grep \"Last Changed Rev:\"";
print "[INFO] Checking svn version for $CODE_DIR/$SCRIPT\n";
my $result = `$svn_version_code`;
if ( $result =~ /Last Changed Rev\:\s*(\d+)/ ){
    $SVN_VERSION = $1;
}

## check if gzip is installed
if (`which zip`){
    $ZIP_INSTALLED = 1;
}else{
    print "[---WARNING---] zip seems not installed...\n";
}

## check/create output dir
## --------------------------
if ( -d $OUT_DIR ){
    print "[INFO] Will use existing dir ($OUT_DIR) as output directory\n";
    if( not -W $OUT_DIR ){
	die "[--ERROR--] outdir is not writable [$OUT_DIR]\n";
    }
}
else{
    print "[INFO] Creating outputdir [$OUT_DIR]\n";
    mkdir( $OUT_DIR ) or die "[--ERROR--] ...unable to create dir ($OUT_DIR): $!\n";
}

## setup main variables
## --------------------------
my %perGene = (); # keys will be genes -> 
my %perTran = (); # keys will be genes -> transcripts -> array with exon-hashes
my %sample_info = ();
my %outputFiles = ();
my $total_in_reg = 0; # this will be set by non-comment linecount vcf
my $DESIGN_NAME = undef; # this will be read from regions file

## get regions info
## --------------------------
print "[INFO] Parsing the regions file ($REG_FILE)\n";
parseRegionsFile( $REG_FILE, \%perGene, \%perTran, $FLANK, \$total_in_reg, \$DESIGN_NAME );
print "[INFO] ...total nr of bases in regions file: $total_in_reg\n";

## setup sample list from vcfs and remove/include samples given with in- and exclude
## --------------------------
my @SAMPLES = ();
my %SELECTED_SAMPLES = ();
my %SAMPLES_INFO = ();
my $sample_count_total = 0;
foreach my $vcf_file ( @VCF_FILES ){
    my ($last_sample_index, $samples) = getRequestedSamplesFromVcf( $vcf_file, \@include, \@exclude, \@SNP_SAMPLES );
    my $count = scalar( @$samples );
    next unless $count; ## if no samples left to analyse -> do not store vcf file
    $SAMPLES_INFO{ $vcf_file }{ samples } = $samples;
    $SAMPLES_INFO{ $vcf_file }{ last_index } = $last_sample_index;
    foreach my $s ( @$samples ){
	## important to check for double samples as they would be mixed up!
        die "[---ERROR---] sample ($s) already seen...could it be present in more than one file?\n" if defined( $SELECTED_SAMPLES{ $s } );
        #$SELECTED_SAMPLES{ $s } = 1;
        $SELECTED_SAMPLES{ $s }{ vcf_file } = $vcf_file;
        push( @SAMPLES, $s );
    }
    $sample_count_total += $count;
    print "[INFO] ...number of samples in vcf for analysis: ".$count."\n";
}
die "[--ERROR--] Discrepancy in nr of samples, debug..\n" if ( $sample_count_total != scalar(@SAMPLES) );
print "[INFO] Final Number of samples for analysis: ".$sample_count_total."\n";
die "[--ERROR--] No samples left for analysis!\n" if ( $sample_count_total == 0 );

## setup output filenames and check their existance
## --------------------------
$outputFiles{ gene_stats } = $OUT_DIR . '/' . $OUT_NAME . '.vcfCallGeneStats';
$outputFiles{ sample_stats } = $OUT_DIR . '/' . $OUT_NAME . '.vcfCallSampleStats';

if ( $GET_EXONCOV ){ ## if optional exoncov output requested
    $outputFiles{ $_.'.exonCov' } = $OUT_DIR.'/'.$_.'.exonCov' foreach @SAMPLES;
}

my %tmp_files = ();
foreach ( @SAMPLES ){
    my $tmp_file = $OUT_DIR.'/'.$_.'_NoCallPos.vcfCalltmp';
    open $tmp_files{ $_ }{ fh }, ">", $tmp_file or die "Unable to open outfile ($tmp_file): $!\n"; 
    $tmp_files{ $_ }{ filepath } = $tmp_file;
}

unless( $OVERWRITE ){
    while( my($name, $file) = each %outputFiles ){
	die "[--ERROR--] outfile exists -> use -overwrite or change outname [$file(.gz)]\n" if ( -f $file or -f $file.'.gz' );
    }
}

## get total vcf positions
#$total_in_vcf = `zcat $VCF_FILE | awk '!/^#/' | wc -l` unless $DEBUG; # awk skips comments+header
#chomp($total_in_vcf);

## continue with actual analysis: getting the calling stats
## --------------------------
my %sample_stats = ();
my %gene_stats = ();
my %low_call_regions = ();
my $index = 1;

my $nr_of_genes = scalar keys %perGene;
my $gene_index = 1;
print "[INFO] -----------------------------\n";
print "[INFO] Starting analysis per gene\n";
print "[INFO] -----------------------------\n";
foreach my $gene_id ( sort keys %perGene ){
    print "[INFO] Sample/Gene stats: gene ".$gene_index++."/$nr_of_genes [$gene_id]\n";
    my $total_in_gene = 0;
    my $gene_c;
    my $gene_s;
    my $gene_name;
    
    foreach my $region ( @{$perGene{ $gene_id }} ){
	#my ($c,$s,$e,$id) = split("_", $region );
	my ($c,$s,$e,$gene) = split("_", $region );
	
	$gene_c = $c if ( not defined $gene_c );
	$gene_s = $s if ( not defined $gene_s or ($s < $gene_s) );
	$gene_name = $gene;
	my %call_counts = ();
	
	my $query_region = $c.':'.$s.'-'.$e;
	my $size = ($e-$s)+1;
	$total_in_gene += $size;
	
	next if $DEBUG; ## for testing speed up
	
	foreach my $vcf_file ( keys %SAMPLES_INFO ){
	
	    my $vcf_last_index = $SAMPLES_INFO{ $vcf_file }{ last_index };
	    my @vcf_samples = @{$SAMPLES_INFO{ $vcf_file }{ samples }};

	    my $code = $VCFTOOLS_BIN.' vcf-query '.$vcf_file.' '.$query_region.' -f \'%CHROM\t%POS\t%FILTER[\t%SAMPLE=%DP]\n\'';
	    my ($prev_chr, $prev_pos);
	    open(IN, $code.'|') or die $!;
	    
	    while (<IN>) {
		chomp;
		my ($chr, $pos, $filter, @dpts) = split( "\t", $_ ); # the fields are requested at code above
		$chr =~ s/chr//;
		next if ( $pos < $s );
		next if ( $pos > $e );
		
		## check if a gap has emerged between the previous stretch and now
		if ( defined( $prev_pos ) and ($pos > $prev_pos+1) ){
		    foreach my $sample ( @vcf_samples ){
			## and print whole "missing" region to each noCall file
			print {$tmp_files{ $sample }{ fh }} join("\t", $chr, ($prev_pos+1), ($pos-1), $gene_name, $gene_id)."\n";
		    }
		}
		$prev_pos = $pos; ## reset pos to start new region
	    
		for (my $i=0; $i<=$vcf_last_index; $i++){
		
		    my ($sample, $depth) = split( "=", $dpts[$i] );
		    next unless exists( $tmp_files{ $sample }{ fh } );
		    die "Tmp filehandle for low regions not set: $sample\n" unless defined( $tmp_files{ $sample }{ fh } );
		    
		    if ( $filter !~ /$VCF_FILTER_REGEX/ ){
			$sample_stats{ $sample }{ nocall }++;
			print {$tmp_files{ $sample }{ fh }} join("\t", $chr, $pos, $pos, $gene_name, $gene_id)."\n";
		    }
		    elsif ( $depth eq '.' ){
			$sample_stats{ $sample }{ nocall }++;
			print {$tmp_files{ $sample }{ fh }} join("\t", $chr, $pos, $pos, $gene_name, $gene_id)."\n";
		    }
		    elsif ( $depth > 0 ){
			$sample_stats{ $sample }{ call }++;
			$gene_stats{ $gene_id }{ $sample }++;
			$call_counts{ $sample }++;
		    }
		    else{
			$sample_stats{ $sample }{ nocall }++;
			print {$tmp_files{ $sample }{ fh }} join("\t", $gene_name, $region, $chr, $pos)."\n";
		    }
		}
	    }
	}
    }
    $gene_stats{ $gene_id }{ size }  = $total_in_gene;
    $gene_stats{ $gene_id }{ chr }   = $gene_c;
    $gene_stats{ $gene_id }{ start } = $gene_s;
    $gene_stats{ $gene_id }{ name }  = $gene_name;
    #$gene_stats{ $gene }{ size }  = $total_in_gene;
    #$gene_stats{ $gene }{ chr }   = $gene_c;
    #$gene_stats{ $gene }{ start } = $gene_s;
    #$gene_stats{ $gene }{ id }    = $gene_id;
}

## ---------------
## OUTPUT
## ---------------
my $gene_stats_file = $outputFiles{ gene_stats };
open my $fh_perGene, ">", $gene_stats_file or die "Unable to open gene outfile: $!\n";

my $sample_stats_file = $outputFiles{ sample_stats };
open my $fh_perSample, ">", $sample_stats_file or die "Unable to open sample outfile: $!\n";

my $comments = <<EOF;
## paramsLine: \"$CMD_LINE\"
## currentDir: $CWD
## svnVersion: $SVN_VERSION
EOF

my $file_idx = 1;
$comments .= $_ foreach( map( "## inputFile".($file_idx++).": ".$_."\n", keys( %SAMPLES_INFO ) ) );
$comments .= <<EOF;
## designFile: $REG_FILE
## designName: $DESIGN_NAME
## designSize: $total_in_reg
## outputDir: $OUT_DIR
## flankSize: $FLANK
## minNoCall: $MIN_NOCALL_REGION_SIZE
## sampCount: $sample_count_total
## geneCount: $nr_of_genes
EOF


foreach my $fh ( ($fh_perGene, $fh_perSample) ){
    print $fh $comments;
}
getPerSampleOutput( $fh_perSample, \%sample_stats, $total_in_reg );
getPerGeneOutput( $fh_perGene, \%gene_stats );

close $fh_perSample;
close $fh_perGene;

foreach my $sample ( @SAMPLES ){ ## close all temporary files
    close $tmp_files{ $sample }{ fh };
}

foreach my $sample ( @SAMPLES ){ ## print low covered regions output per sample
    my $infile = $tmp_files{ $sample }{ filepath };
    my $outfile = $OUT_DIR.'/'.$sample.'.vcfCallNoCallRegions.bed';
    condenseLowCallRegionsOutput( $sample, $infile, $outfile, $comments ); 
    
}
print "[INFO] Gzipping NoCallRegion files\n";
if ( $ZIP_INSTALLED ){
    my $output_path = $OUT_DIR.'/'.$OUT_NAME.'.vcfCallNoCallRegions.zip';
    my $input_files = $OUT_DIR.'/'.'*.vcfCallNoCallRegions.bed';
    #system( 'tar -cvzf '.$output_path.' '.$input_files.' &> /dev/null ' );
    system( 'zip -qj '.$output_path.' '.$input_files );
    if ( -e $output_path ){
	print "[INFO] ...done: now deleting original files\n";
	system( 'rm '.$input_files );
    }
}

my $delete_count = 0;
unless ( $KEEP_TMP ){
    foreach my $sample ( @SAMPLES ){ ## delete tmp files
	my $file = $tmp_files{ $sample }{ filepath };
	unlink( $file );
	$delete_count++;    
    }
}
print "[INFO] Deleted $delete_count tmp files..\n";


## also output exonCov file if requested
if ( $GET_EXONCOV ){
    print "[INFO] -----------------------------\n";
    print "[INFO] Starting analysis per exon\n";
    print "[INFO] -----------------------------\n";
    getExonCovOutput( \%perTran, $comments );    
}
print "[INFO] Final output in dir: ".$OUT_DIR."\n";
print "[INFO] DONE\n";

## ====================================================
## SUBROUTINES
## ====================================================
sub condenseLowCallRegionsOutput{
    my ($sample, $infile, $outfile, $comments) = @_;
    my @header = qw( chr start end gene gene_id size );
    
    open IN, '<', $infile or die "Unable to open infile ($infile): $!\n";
    open OUT, '>', $outfile or die "Unable to open outfile ($outfile): $!\n";
    print OUT $comments;
    print OUT "## sampleName: $sample\n";
    print OUT '#'.join( "\t", @header )."\n";
    
    my ($prev_chr, $prev_start, $prev_end, $prev_gene, $prev_gene_id);
    while (<IN>){
	
	next if $_ eq '';
	next if $_ =~ /^#/;
	next if length($_) == 0;
	chomp;
	my ($chr, $start, $end, $gene, $gene_id) = split( "\t", $_ );
	die "Start bigger than end ($start > $end)\n" if ($start > $end);
	die "[---ERROR---] end not defined\n" unless defined($end);
	
	if( not defined( $prev_chr ) ){
	    ($prev_chr, $prev_start, $prev_end, $prev_gene, $prev_gene_id) = ($chr, $start, $end, $gene, $gene_id);
	    next;
	}
	elsif( $prev_chr ne $chr ){
	    my $size = ($prev_end - $prev_start)+1;
	    print OUT join("\t", $prev_chr, $prev_start, $prev_end, $prev_gene, $prev_gene_id, $size)."\n" if ($size >= $MIN_NOCALL_REGION_SIZE);
	    ($prev_chr, $prev_start, $prev_end, $prev_gene, $prev_gene_id) = ($chr, $start, $end, $gene, $gene_id);
	}
	elsif( $prev_gene ne $gene ){
	    my $size = ($prev_end - $prev_start)+1;
	    print OUT join("\t", $prev_chr, $prev_start, $prev_end, $prev_gene, $prev_gene_id, $size)."\n" if ($size >= $MIN_NOCALL_REGION_SIZE);
	    ($prev_chr, $prev_start, $prev_end, $prev_gene, $prev_gene_id) = ($chr, $start, $end, $gene, $gene_id);
	}
	elsif( $start > ($prev_end+1) ){
	    my $size = ($prev_end - $prev_start)+1;
	    print OUT join("\t", $prev_chr, $prev_start, $prev_end, $prev_gene, $prev_gene_id, $size)."\n" if ($size >= $MIN_NOCALL_REGION_SIZE);
	    ($prev_chr, $prev_start, $prev_end, $prev_gene, $prev_gene_id) = ($chr, $start, $end, $gene, $gene_id);
	}
	elsif( $start == ($prev_end+1) ){
	    $prev_end = $end;
	}
    }
    if ( defined( $prev_chr ) ){ # when tmp file has 0 lines prev vars not set and nothing to print
	my $size = ($prev_end - $prev_start)+1;
	print OUT join("\t", $prev_chr, $prev_start, $prev_end, $prev_gene, $prev_gene_id, $size)."\n" if ($size >= $MIN_NOCALL_REGION_SIZE);
    }
    
    close IN;
    close OUT;
}

sub getPerSampleOutput{
    my ($fh_perSample, $sample_stats, $design_size) = @_;
    my @sample_header = qw( called call_p sample vcf_file );
    
    print $fh_perSample '#'.join( "\t", @sample_header )."\n";
    
    foreach my $sample ( sort @SAMPLES ){
	my $vcf_file = fileparse( $SELECTED_SAMPLES{ $sample }{ 'vcf_file' } ) || 'NA';
	my @out = ( 'NA', 'NA', $sample, $vcf_file );
	if( exists $sample_stats->{$sample} ){
	    ## first set the call and nocall to 0 if they are somehow not set at all
	    $sample_stats->{ $sample }{ call } = 0 unless exists($sample_stats->{ $sample }{ call });
	    $sample_stats->{ $sample }{ nocall } = 0 unless exists($sample_stats->{ $sample }{ nocall });
	    ## then get total / percentages 
	    my $call   = $sample_stats->{ $sample }{ call };
	    my $call_p   = ( $call / $design_size )*100;
	    ## piece of mind check on %	    
	    print "[---WARNING---] PerSampleCall percentage for sample \"$sample\" out of range (0-100): $call/$design_size = $call_p !!\n" unless ( $call_p >= 0 and $call_p <= 100 );
	    ## and output
	    @out = ( $call, sprintf("%.2f", $call_p), $sample, $vcf_file );
	}
	print $fh_perSample join("\t", @out )."\n"
    }    
}

sub getPerGeneOutput{
    my ($fh_perGene, $gene_stats) = @_;
    my @gene_header = qw( gene gene_id chrom position size_in_bp AVERAGE MIN MAX );
    print $fh_perGene '#'.join( "\t", @gene_header, @SAMPLES )."\n";
    #foreach my $gene ( sort keys %$gene_stats ){
    foreach my $gene_id ( sort keys %$gene_stats ){
    
	my $gene_total = $gene_stats->{ $gene_id }{ size };
	my $gene_chr   = $gene_stats->{ $gene_id }{ chr };
        my $gene_start = $gene_stats->{ $gene_id }{ start };
        #my $gene_id    = $gene_stats->{ $gene }{ id };
        my $gene       = $gene_stats->{ $gene_id }{ name };
        
	my @out = ();
	my @percs = ();
        foreach my $sample ( @SAMPLES ){
	    if ( not defined $gene_stats->{ $gene_id }{ $sample } ){
		push( @out, 0 );
		push( @percs, 0 );
	    }else{
		my $sample_total = $gene_stats->{ $gene_id }{ $sample };
		my $perc = ($sample_total / $gene_total )*100;
		push( @percs, $perc );
		## piece of mind check on %
		print "[---WARNING---] PerGeneCall percentage for sample \"$sample\" out of % range (0-100): $sample_total/$gene_total = $perc % !!\n" unless ( $perc >= 0 and $perc <= 100 );
		push( @out, sprintf("%.2f", $perc) );
	    }
	}
	my ($perc_av, $perc_min, $perc_max) = getArrayAvMinMax( \@percs );
	@out = ( $gene, $gene_id, $gene_chr, $gene_start, $gene_total, sprintf("%.2f", $perc_av), sprintf("%.2f", $perc_min), sprintf("%.2f", $perc_max), @out );
	print $fh_perGene join("\t", @out )."\n";
    }    
}

sub getRequestedSamplesFromVcf{
    ## sets up the array with vcf-samples to analyse based
    my ($vcf_file, $inc, $exc, $snp) = @_;
    my @selection = ();
    
    warn "[INFO] Retrieving sample names from VCF file ($vcf_file)\n";
    my $vcf = Vcf->new( file => $vcf_file );
    $vcf->parse_header();
    my (@samples) = $vcf->get_samples();	
    my $last_index = $#samples;
    $vcf->close();
    warn "[INFO] ...number of samples found in VCF: ".scalar(@samples)."\n";
    
    ## exclude potential SNP samples
    print "[INFO] ...trying to find/exclude SNP samples: ".join("|", @$snp)."\n";
    foreach my $search ( @$snp ){
	my @idx = reverse(grep { $samples[$_] eq $search } 0..$#samples);
	foreach my $idx ( @idx ){
	    splice(@samples, $idx, 1); # remove sample to exclude from samples
	}
    }
    
    ## allow only includes or excludes
    if( scalar(@$exc) and scalar(@$inc) ){
	die "[--ERROR--] either include OR exclude sample pls...\n";
    }
    ## exclude 
    elsif( scalar(@$exc) ){
	foreach my $search ( @$exc ){
    	    print "[INFO] ...trying to find+exclude sample \"$search\"\n";
	    my @idx = reverse(grep { $samples[$_] eq $search } 0..$#samples);
	    die "[--ERROR--] Unable to find sample \"$search\" in vcf-samples...\n" unless scalar(@idx);
	    foreach my $idx ( @idx ){
		splice(@samples, $idx, 1); # remove sample to exclude from samples
	    }
	    print "[INFO] ...sample \"$search\" removed from analysis\n";
	}
	@selection = @samples;
    }
    ## include
    elsif ( scalar(@$inc) ){
	my @included_samples = ();
	foreach my $search ( @$inc ){
	    print "[INFO] Trying to search and include sample \"$search\"\n";
	    my @idx = (grep { $samples[$_] eq $search } 0..$#samples);
	    die "[--ERROR--] Unable to find sample \"$search\" in vcf-samples...\n" unless scalar(@idx);
	    push( @included_samples, $search );
	    print "[INFO] ...sample \"$search\" included in analysis\n";
	}
	push( @selection, @included_samples); # replace original samples with those to analyse
    }else{
	@selection = @samples;
    }
    return( $last_index, \@selection );
}

sub getExonCovOutput{
    ## regionPerTran is hashref with gene->tran->exon-array
    my ( $regionsPerTran, $general_comments ) = @_;
    
    ## setup all filehandles for output *exonCov files (one per sample in vcf)
    ## --------------------------
    my @per_exon_header = qw( GENE TRANSCRIPT EXON GENOMIC_REGION LENGTH STRAND );
    push( @per_exon_header, map( ''.$_ , @LIMITS) );
    
    my %FILEHANDLES = ();
    
    ## check files existance
    ## --------------------------
    unless ( $OVERWRITE ){
	my $exists = 0;
	foreach my $sample ( @SAMPLES ){
	    my $outfile = $OUT_DIR.'/'.$sample.'.exonCov';
	    if ( -f $outfile or -f $outfile.'.gz' ){
		warn "[--WARNING--] outfile exists, nothing printed -> use -overwrite [$outfile(.gz)]\n";
		$exists = 1;
	    }
	}
	print "[--WARNING--] One or more exonCov files already exist, skipping ExonCov analysis -> you might want to use -overwrite\n" and return if $exists;
    }
    
    ## print info fields to each file
    ## --------------------------    
    foreach my $vcf_file ( keys %SAMPLES_INFO ){

	my $samples = $SAMPLES_INFO{ $vcf_file }{ samples };
	
	foreach my $sample ( @$samples ){
	    my $id = $sample;
	    my $outfile = $OUT_DIR.'/'.$sample.'.exonCov';
	    open my $fh, ">", $outfile or die "Unable to open outfile [$outfile]\n";
	    $FILEHANDLES{ $sample } = *$fh;
	    #print $fh '##DESCRIPTION: This file contains coverage information for regions (usually exons), retrieved from a multi) vcf file'."\n";
	    print $fh '##VCF_FILE='.fileparse($vcf_file)."\n";
	    print $fh '##OUT_NAME='.fileparse($OUT_NAME)."\n";
	    print $fh '##ORIGINAL_ID='.fileparse($sample)."\n";
	    print $fh '##CLEANED_ID='.$id."\n";
	    print $fh '##DESIGN_FILE='.fileparse($REG_FILE)."\n";
	    print $fh '##DESIGN_NAME='.$DESIGN_NAME."\n";
	    print $fh '##FLANK_SIZE='.$FLANK."\n";
	    print $fh '#'.join( "\t", @per_exon_header )."\n";
	}
    }
    
    ## continue
    ## --------------------------
    my $index = 1;
    my $transcript_count = 0;
    $transcript_count += scalar keys %{$regionsPerTran->{$_}} foreach keys %$regionsPerTran;
    	
    foreach my $gene ( sort keys %$regionsPerTran ){
	
	foreach my $tran ( sort keys %{$regionsPerTran->{$gene}} ){
		
		print "[INFO] ExonCov stats: region ".$index++." of $transcript_count [$gene -> $tran]\n";
		my $strd = $regionsPerTran->{$gene}{$tran}{ strand };
		
		## some exons contain letter in name, use regex to remove for sorting numerically
		foreach my $r ( @{$regionsPerTran->{$gene}{$tran}{exons}} ){

			my $size = $r->{ size };
			my $name = $r->{ name };
			my $regi = $r->{ region };
			my ($c,$s,$e) = split( /[:-]/, $regi );
			
			## quick check whether the regions values are found
			die "Unable to get chr/start/end from region string [$regi]\n" unless ( defined($c) and defined($s) and defined($e) );	
			
			## reset region to include flank
			my $check_region = $c.':'.($s - $FLANK).'-'.($e + $FLANK);

			## retrieve values using vcf-tools
			## --------------------------
			my %info = ();
			foreach my $vcf_file ( keys %SAMPLES_INFO ){
				
				next if $DEBUG; ## for testing speed up
				
				my $code = $VCFTOOLS_BIN.' vcf-query '.$vcf_file.' '.$regi.' -f \'%CHROM\t%POS\t%REF[\t%SAMPLE=%DP]\n\'';
				open(IN, $code.'|') or die $!;
				while (<IN>) {
					chomp;
					my ($chr, $pos, $ref, @dpts) = split( "\t", $_ );
					foreach my $id_dp ( @dpts ){
						my ($id, $dp) = split('=', $id_dp);
						#next unless defined( $SAMPLES_INFO{ $id } );
						$dp = 0 if $dp eq '.';
						$info{ $id }{ $pos } = $dp;
					}
				}
				close IN;
			}
			
			## print the exon info foreach sample
			## --------------------------
			my %stats = ();
			foreach my $pos ($s..$e){
				foreach my $id (@SAMPLES){
					if ( $info{ $id }{ $pos } ){
						foreach my $lim ( @LIMITS ){
							if ( $info{$id}{$pos} > $lim ){
								$stats{$id}{$lim} ++;
							}
						}
					}
				}
			}
			
			## print the exon exonCov info foreach sample
			## --------------------------
			foreach my $id (@SAMPLES){
				my @out = ( $gene, $tran, $name, $regi, $size, $strd );
				
				my $fh = $FILEHANDLES{ $id };
				unless ( defined( $fh )  ){
				    next();
				}
				foreach my $lim (@LIMITS){
					my $val = 0;
					$val = $stats{ $id }{ $lim } if $stats{ $id }{ $lim };
					my $perc = int( ($val*100 / $size)+0.5 );
					push( @out, $perc );					
				}
				print $fh join( "\t", @out )."\n";
			}
		}
	}
    }

    ## now close all opened filehandles
    ## --------------------------
    print "[INFO] Closing open filehandles\n";
    foreach my $id ( keys %FILEHANDLES ){
	close $FILEHANDLES{ $id } or die "Unable to close filehandle for ($id): $!\n";;
    }
    print "[INFO] Gzipping exonCov files\n";
    if ( $ZIP_INSTALLED ){
	my $output_path = $OUT_DIR.'/'.$OUT_NAME.'.vcfCallExonCov.zip';
	my $input_files = join( " ", map( $OUT_DIR.'/'.$_.'.exonCov', @SAMPLES) );
	#system( 'tar -cvzf '.$output_path.' '.$input_files.' &> /dev/null ' );
	system( 'zip -qj '.$output_path.' '.$input_files );
	if ( -e $output_path ){
	    print "[INFO] ...done: now deleting original files\n";
	    system( 'rm '.$input_files );
	}
    }
}


sub getArrayAvMinMax{
    my ($array) = @_;
    die "[--ERROR--] No data in array in getArrayAvMinMax....\n" unless (scalar(@$array) > 0);
    my $counter = 0;
    my $sum = 0;
    my $min;
    my $max;
    foreach my $val ( @$array ){
	if ( not defined($min) or ($val < $min) ){
	    $min = $val;
	}
	if ( not defined($max) or ($val > $max) ){
	    $max = $val;
	} 
	$sum += $val;
	$counter++;
    }
    my $av = $sum / $counter;
    return( $av, $min, $max );
}

sub parseRegionsFile{
	my ($file, $perGene_store, $perTran_store, $flank, $count, $design_name) = @_;
	
	my @header = ();
	my %tmp_regions = ();
	my $non_coding_exon_count = 0;
	
	## open regions file to get design-name and header
	open IN, $file or die "Unable to open infile [$file]\n";
	while (<IN>){
	    next if ($_ =~ /^\s*$/); # skip empty lines
	    if ($_ =~ /^##\s*DESIGN_NAME=(.*)/ ){ 
		$$design_name = $1;
	    }
	    if ( $_ =~ /^#((gene|chr).*)/ ){ # header found
		chomp;
		@header = split( "\t", $1 );
		last;
	    }
	}
	close IN;
	my $header_count = scalar( @header );
	die "[--ERROR--] Regions file has no header line (starting with #gene)?\n" unless $header_count;
	
	## open regions file again to get data
	open IN, $file or die "Unable to open infile [$file]\n";
	while (<IN>){
		chomp;
		next if ($_ =~ /^\s*$/); # skip empty lines
		next if ($_ =~ /^#/); # skip header lines
		my @vals = split( "\t", $_ );
		die "[ERROR] different amount of columns for line and header...\n" unless (scalar(@vals) == $header_count);
		
		## store each column value in hash by header name
		my %line_info = ();
		foreach my $idx ( 0..$#header ){
		    $line_info{ $header[$idx] } = $vals[$idx];
		}
		
		## retrieve required values
		my $gene = $line_info{ gene };
		my $tran = $line_info{ transcript };
		my $gid  = $line_info{ ens_gene_id };
		my $tid  = $line_info{ ens_tran_id };
		my $str  = $line_info{ strand };
		my $chr  = $line_info{ chr };
		my $e_count = $line_info{ exon_count };
		
		if ( $OLD_INPUT_FORMAT ){ # fields = chr gene transcript strand ensembl_gene ensembl_transcript ccds refseq cdna_start cdna_end cds_start cds_end exon_count exon_starts exon_ends exon_names
		    $tid = $line_info{ ensembl_transcript };
		    $gid  = $line_info{ ensembl_gene };
		}
		
		$chr =~ s/chr//;
		$tid =~ s/\.\d+$//;
		my @e_starts = split( ',', $line_info{ exon_starts });
		my @e_ends   = split( ',', $line_info{ exon_ends });
		my @e_names  = split( ',', $line_info{ exon_names });
		
		## do some sanity checks
		die "[ERROR] Exon-starts, -ends and -names are not all equal length for ($tid)\n" unless (scalar(@e_starts) == scalar(@e_ends) and scalar(@e_ends) == scalar(@e_names) );
		die "[ERROR] strange exon count [$e_count]\n" unless ($e_count =~ /^\d+$/);
		die "[ERROR] exon count ($e_count) somehow not equal to # starts in line ($_)\n" unless ($e_count == scalar(@e_starts) );
		die "[ERROR] strange gene? [$gene]\n" unless (defined ($gene) and length($gene) > 0 );
		die "[ERROR] strange gene? [$gene]\n" unless ($gene !~ /^\d+$/);
		die "[ERROR] strange strand? [$str]\n" unless ($str =~ /^(FW|RV)$/);
		die "[ERROR] strange ensembl gene id? [$gid] line $.\n" unless (defined ($gid) and $gid =~ /^ENSG/ or $OLD_INPUT_FORMAT );
		die "[ERROR] strange ensembl transcript id? [$tid] line $.\n" unless (defined ($tid) and $tid =~ /^ENST/ or $OLD_INPUT_FORMAT );
		
		foreach my $idx ( 0..$#e_starts ){
			my $sta = $e_starts[ $idx ];
			my $end = $e_ends[ $idx ];
			my $nam = $e_names[ $idx ];
			
			## do some sanity checks
			die "[ERROR] Start bigger than end? [$sta>$end in \"$_\"]\n" if ($sta > $end);
			
			## check if coding
			if ( $line_info{ cds_start } =~ /^\d+$/ ){ ## not all transcripts are coding (and thus might not have cds)
			    $sta = $line_info{ cds_start } if ($line_info{ cds_start } > $sta);
			    $end = $line_info{ cds_end } if $line_info{ cds_end } < $end;
			}
			if ($sta > $end){
				warn "[INFO] Skipping EXON of $gene -> $tid -> $nam : because not coding [start >= end after cds check [START:$sta END:$end]\n";
				$non_coding_exon_count++;
				next;
			}
			
			## add flanks (default: 0)
			$sta -= $flank;
			$end += $flank;
			my $region = join( "_", $chr, $sta, $end, $gene );
			#my $gene_string = join( "_", $gene, $gid );
		        
		        $tmp_regions{ $gid }{ $sta } = $region; ## CHECK THIS !!!!
		        
		        $perTran_store->{ $gid }{ $tran }{ strand } = $str;
		        $perTran_store->{ $gid }{ $tran }{ gene_name } = $gene;
		        #$perTran_store->{ $gene }{ $tid }{ strand } = $str;
		        my %exon = (
		    	    'name' => $nam,
		    	    'region' => $chr.':'.$sta.'-'.$end,
		    	    #'igv_region' => $chr.':'.($sta-3).'-'.($end+3),
		    	    'size' => ($end - $sta)+1,
		    	    'start' => $sta,
		    	    'end' => $end,
		        );
		        push( @{$perTran_store->{ $gid }{ $tran }{ exons }}, \%exon );
		        #push( @{$perTran_store->{ $gene }{ $tid }{ exons }}, \%exon );
		}
	}
	close IN;
	print "[INFO] ...will SKIP $non_coding_exon_count exons/regions for reason \"not coding (start >= end after cds check)\"\n" if $non_coding_exon_count;
	
	## --------------------------
	## now condense regions per gene (some regions may overlap due to multiple transcripts/exons tc)
	#foreach my $g ( keys %tmp_regions ){
	foreach my $gid ( keys %tmp_regions ){
	    my $gene_regions = $tmp_regions{ $gid };
	    my $prev_s = 0;
	    my $prev_e = 0;
	    my $chr;
	    my $curr_gene;
	    
	    foreach my $start ( sort {$a <=> $b} keys %{$gene_regions} ){ # keys are integers (start position or region)
	    
		#my $end = $gene_regions{ $start };
		my $region = $gene_regions->{ $start };
		#my ($c,$s,$e,$id) = split("_", $region );
		my ($c,$s,$e,$gene_name) = split("_", $region );
		if (defined($chr) and ($chr ne $c)){
		    die "[ERROR] different chromosome within same gene... ($gid $gene_name -> \"$chr\" vs \"$c\") region was \"$region\"\n";
		}
		$chr = $c;
		$curr_gene = $gene_name;
		
		if ( $s > $e ){
		    die "[ERROR] Start must be lower than end ($region)\n";
		}
		
		## init first region
		if ( ($prev_s == 0) and ($prev_e == 0) ){
		    $prev_s = $s;
		    $prev_e = $e;
		}
		## cannot work if not sorted
		elsif ( ($s < $prev_s) or ($e < $prev_s) ){
		    die "[ERROR] Regions should be sorted by now ($region)\n";
		}
		## if region overlaps with previous -> adjust to one bigger region
		elsif ( ($s <= $prev_e) and ($e > $prev_e) ){
		    $prev_e = $e;
		    next;
		}
		## if region is fully in previous -> skip
		elsif ( ($s <= $prev_e) and ($e <= $prev_e) ){
		    next;
		}
		## if new non-overlapping region -> save previous and start new one
		elsif ( $s > $prev_e ){
		    #my $region = join("_", $chr, $prev_s, $prev_e, $gene_id);
		    my $region = join("_", $chr, $prev_s, $prev_e, $gene_name);
		    $$count += ($prev_e - $prev_s)+1;
		    push( @{$perGene_store->{ $gid }}, $region);
		    $prev_s = $s;
		    $prev_e = $e;
		    next;
		}
		else{
		    die "[ERROR] dont know what to do with this region ($region)\n";
		}
	    }
	    #my $region = join("_", $chr, $prev_s, $prev_e, $gene_id);
	    my $region = join("_", $chr, $prev_s, $prev_e, $curr_gene);
	    $$count += ($prev_e - $prev_s)+1;
	    push( @{$perGene_store->{ $gid }}, $region);
	}
}


## --------------------------
## for 1000 returns 1,000
## --------------------------
sub commify {
	my $text = reverse $_[0];
	$text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
	return scalar reverse $text;
}

sub cleanupVcfName{
	my ($in) = @_;
	my $out = $in;
	$out =~ s/_merged_variants$//;
	$out =~ s/_merged.txt$//;
	$out =~ s/^merged_//;
	$out =~ s/_F3_/_/;
	return($out);
}

## Allows to use getopt while retain wildcard functionality
sub checkInputForWildcard{
    my ($input_array) = @_;
    my $sub = 'checkInputForWildcard';
    my @out = ();
    
    foreach my $input ( @$input_array ){ # foreach allows for more than one wildcard string
	if ( $input =~ /(.*\*.*)/ ){ # if any * present
	    print "[INFO] getting files from wildcard ($1)\n";
	    my $ls_output = `ls $1`;
	    die "[EXIT $sub] $input generates no files\n" unless $ls_output;
	    my @files = split( "\n", $ls_output );
	    push @out, @files;
	}else{
	    push @out, $input;
	}
    }
    return( \@out );
}

sub usage{
    
    my $msg = <<EOF;

 DESCRIPTION:
 -----------------
   Reads a vcf file to determine coverage stats per sample
   - Supports multi sample vcf
   - Vcf sample names are used in/as output names
   - Uses (and thus requires) vcftools-query to read vcf
   - By default excludes \"SNP\" samples: man1|man2|vrouw1|vrouw2!!
   - auto zips the noCallRegions and exonCov files

 USAGE / REQUIRED:
 -----------------
   -v|vcf         <s>  [multiple] bgzipped vcf file (tabix index required)
                       NOTE: you can use a wildcard in this way: -v "<PATH>/*.vcf.gz"
   -d|design      <s>  regions file (*exoncovTranscripts - created with getTranscripts.pl)
   -outname       <s>  output base name
   -outdir        <s>  output directory (will be created or asked confirmation when exists)

 OPTIONAL:
 -----------------
   -vcftools_bin  <s>  path to vcftools bin (use this if not in ENV)
   -flank         <i>  add flank size to regions [$FLANK]
   -rrs           <i>  report region size: minimal report \"no call\" region size
   -include       <s>  [multiple] sample to include (rest ignored)
   -exclude       <s>  [multiple] sample to exclude (rest analysed)
                       (include/exclude names exactly as in VCF)
   -exoncov            also output ExonCallCov file per vcf-sample
                       (slower, beacause every exon is retrieved one by one)
   -vcf_filter    <s>  a perl regex to which the FILTER field should apply [$VCF_FILTER_REGEX]
   -overwrite          overwrite files if already in place
   -kss                keep snp samples: by default man1 man2 vrouw1 vrouw2 are excluded
   -debug              switches off vcf-tools query to speed up testing (but output is not correct!)
   
EOF

    die( $msg );
}
