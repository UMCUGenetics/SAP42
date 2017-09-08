#!/usr/bin/perl -w
use strict;
use Getopt::Long;
use Data::Dumper;
use Cwd;
use File::Basename;

## =========================
## DESCR: A tool to convert a pipeline variant-list(s) (eg .refiltered_snps) to vcf format (without any form of merging variants)
## AUTHR: S. van Lieshout
## USAGE: see -h
## INFO:  http://www.1000genomes.org/wiki/Analysis/Variant%20Call%20Format/vcf-variant-call-format-version-41
## =========================
my $SCRIPT_VERSION = 5;
my $NA_CHAR = '.';

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my %opt = (
    'HELP'   => '',
    'NAME'   => '', # name to be used for sample identifier in vcf
    'DEBUG'  => '',
    'IN'     => [], # input files
    'OUT'    => '', # outfilebase
    'REF'    => '', # reference file
    'NOZIP'  => '', # if set the vcf is not bgzipped and indexed
    'TMP'    => 'vcf_converter_tmp_file_before_sort', # name of temporary file needed for correct sorting
    'TMP2'   => 'vcf_converter_tmp_file_before_dupRemoval', # name of temporary file needed for correct dup removal
    'DATE'   => ($year+1900).sprintf("%0*d", 2, ($mon+1)).sprintf("%0*d", 2, $mday), # year starts at 1900 and month is array starting with 0
    'MIN_PV' => 0.15, # minimal percentage variant
);

my %IUPAC = ( 'A'=>'A', 'C'=>'C', 'G'=>'G', 'T'=>'T', 'R'=>'A,G', 'Y'=>'C,T', 'S'=>'G,C', 'W'=>'A,T', 'K'=>'G,T', 'M'=>'A,C', 'B'=>'C,G,T', 'D'=>'A,G,T', 'H'=>'A,C,T', 'V'=>'A,C,G', 'N'=>'A,C,G,T' );
my @META = qw( fileformat fileDate vcfConverter );
my @HEAD = qw( CHROM POS ID REF ALT QUAL FILTER );
my @INFO = qw( NS DP MQ );
my @FORMAT = qw( GT DP RAF AF );

## Get options and set output name
## -------------------------------
die usage() if @ARGV == 0;
GetOptions (
    'h|help'     => \$opt{HELP},
    'in|i=s@'    => \$opt{IN},
    'out|o=s'    => \$opt{OUT},
    'name|n=s'   => \$opt{NAME},
    'ref_af=f'   => \$opt{MIN_PV},
    'ref_file=s' => \$opt{REF},
    'no_zip'     => \$opt{NOZIP},
    'debug'      => \$opt{DEBUG},
) or die usage();

## check types of  input files
## -------------------------------
my $types = 'refiltered(_snps|_indels|_reference)';
print "===>\n[EXIT] provide input file\n===>\n" and usage() unless $opt{IN};
print "===>\n[EXIT] provide output filename\n===>" and usage() unless $opt{OUT};
print "===>\n[EXIT] provide vcf sample name\n===>" and usage() unless $opt{NAME};
foreach my $in_file ( @{$opt{IN}} ){
    die "[ERROR] Wrong input type [types allowed: *$types]\n" unless ($in_file =~ /$types/);
}

## check if everything is ok to start
## -------------------------------
usage() if $opt{HELP};
$opt{OUT} .= '.vcf' unless $opt{OUT} =~ /\.vcf$/;
print "[INFO] ---------- pipeline2vcf ----------\n";

## INFO HASHES
## -------------------------------
my %META_DESC = (
    'fileformat'  => 'VCFv4.1',
    'fileDate'    => $opt{DATE},
    'vcfConverter'=> $0.'(version:'.$SCRIPT_VERSION.')', # set script as source
    'reference'   => ($opt{REF} or 'unknown'),
);
my %INFO_DESC = (
    'NS'       => 'INFO=<ID=NS,Number=1,Type=Integer,Description="Number of Samples With Data">',
    'DP'       => 'INFO=<ID=DP,Number=1,Type=Integer,Description="Total Depth">',
    #'AF'       => 'INFO=<ID=AF,Number=A,Type=Float,Description="Allele Frequency">',
    'MQ'       => 'INFO=<ID=MQ,Number=1,Type=Integer,Description="Mapping Quality">',
    #'RAF'      => 'INFO=<ID=RAF,Number=1,Type=Float,Description="Reference Allele Frequency">',
    #'ORI_CALL' => 'INFO=<ID=ORI_CALL,Number=A,Type=String,Description="Original call in refiltered file">',
    #'ORI_ALTS' => 'INFO=<ID=ORI_ALTS,Number=A,Type=String,Description="Original alts in refiltered file">'
);
my %FORMAT_DESC = (
    'GT'   => 'FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">',
    'DP'   => 'FORMAT=<ID=DP,Number=1,Type=Integer,Description="Total Depth">',
    'AF'   => 'FORMAT=<ID=AF,Number=A,Type=Float,Description="Allele Frequency">',
    'RAF'  => 'FORMAT=<ID=RAF,Number=1,Type=Float,Description="Reference Allele Frequency">',
);

## convert non integer chromosomes for sorting later on
## NOTE!!! If you change/add conversions, do not forget to change the awk/sort command below too!!!!
my %CHR_CONVERSION = ( 'X' => 1000, 'Y' => 2000, 'MT' => 3000);

# ==================================
# MAIN
# ==================================
my @header_lines = (); # output first stored because settings are spliced in later
open OUT,  ">".$opt{OUT}  or die "Unable to open output $opt{OUT}: $!\n"; 
open TMP,  ">".$opt{TMP}  or die "Unable to open tmp output $opt{TMP}: $!\n"; 
#open TMP2, ">".$opt{TMP2} or die "Unable to open tmp output $opt{TMP2}: $!\n"; 
    
# if provided use name as sample id, else use filename from first input file
#my $sample_id = (fileparse( $opt{IN} ))[0];
my $sample_id = 'NO_SAMPLE_NAME';
$sample_id = $opt{NAME} if $opt{NAME};

push @header_lines, "$_=$META_DESC{ $_ }" foreach @META;
addReferenceAndContigs( $opt{REF}, \@header_lines ) if $opt{REF};
foreach my $in_file ( @{$opt{IN}} ){
    push (@header_lines, "vcfConverterInputFile=".$in_file);
    parseRefilteredSnps( $in_file, *OUT, *TMP, \@header_lines) ;
}
close TMP;

push @header_lines, "$INFO_DESC{ $_ }" foreach @INFO;
push @header_lines, "$FORMAT_DESC{ $_ }" foreach @FORMAT;
print OUT "##$_\n" foreach @header_lines; #only print header lines once
print OUT '#'.join("\t", @HEAD, 'INFO', 'FORMAT', $sample_id)."\n";


## now sort tmp file and replace X, Y, MT alternatives back to correct ones
print "[INFO] Sorting tmp file [sort -k1n -k2n + awk]\n";
my $tmp_file = $opt{TMP};
my $sorted_file = $opt{TMP2};
my @awk_sub = map( 'sub(/'.$CHR_CONVERSION{ $_ }.'/, "'.$_.'", $1)', keys %CHR_CONVERSION );
my $post_process_code = 'cat '.$tmp_file.' | sort -k1n -k2n | awk \'BEGIN { OFS = "\t" } { if($1 !~ /^#/ ){ '.join(';', @awk_sub).'; print} }\' > '.$sorted_file;

#print "CODE $post_process_code\n";
my $failed = system( $post_process_code );
if ( $failed ){
    print "[ERROR] Something went wrong with post process system command [$post_process_code] -> tmp file will not be removed [$tmp_file]\n";
}else{    
    system( "rm $tmp_file" ) unless $opt{DEBUG};
    print "[INFO] ...sorting done\n";
}

## cleanup sorted file
print "[INFO] Checking for duplicate positions\n";
mergeDuplicatePositions( $sorted_file, *OUT );
close OUT;
system( "rm $sorted_file" );
print "[INFO] Removed tmp file ($sorted_file)\n";
print "[INFO] Duplicate removal done -> output in ".$opt{OUT}."\n";

## bgzip and index unless requested not to do so
if ( $opt{NOZIP} ){
    print "[INFO] ...skipping bgzip and tabix\n";
    print "[INFO] DONE -> final output in ".$opt{OUT}."\n";
}
else{    
    my $failed = 0;
    my $unzipped = $opt{ OUT };
    my $zipped = $unzipped.'.gz';
    
    print "[INFO] ...bgzipping and tabix\n";
    system( "bgzip -c $unzipped > $zipped" );
    $failed = 1 if ($? == -1);
    system( "tabix -p vcf $zipped" );
    $failed = 1 if ($? == -1);
    if ( $failed ){
	print "[INFO] ...bgzipping and/or indexing failed somehow\n";
    }
    else{
	system( "rm $unzipped" );
	print "[INFO] DONE -> final output in ".$zipped."\n";
    }
}




# ==================================
# /MAIN
# ==================================
sub mergeDuplicatePositions{
    my ($sorted_file, $out_fh) = @_;
    
    open SORTED, $sorted_file or die "[ERROR mergeDuplicatePositions] Unable to open tmp file:$!\n";
    my (@prev_lines, $prev_chr, $prev_pos);
    while ( <SORTED> ){
	if ( $_ =~ /^#/ ){
	    print $out_fh $_;
	}
	chomp;
	my ($chr, $pos) = (split( "\t", $_))[0,1];
        
        if ( $prev_chr ){
	
	    unless ( ($prev_chr eq $chr) and ($prev_pos == $pos) ){ ## if new position found -> store in array
		if ( scalar(@prev_lines) > 1 ){ # by now multiple lines with same pos
		    my $first_line = $prev_lines[0];
		    my $merged_line = mergePositions( \@prev_lines );
		    print $out_fh $merged_line."\n";
		    print "[INFO] ...position $prev_chr:$prev_pos had multiple calls, merged into one line!!!\n";
		}else{ # or just one line stored
		    print $out_fh $prev_lines[0]."\n";
		}
		@prev_lines = ();
	    }
	}
	$prev_chr = $chr;
	$prev_pos = $pos;
	push( @prev_lines, $_ );
    }
    if (scalar(@prev_lines) > 1 ){
	print "[INFO] ...position $prev_chr:$prev_pos had multiple calls, merged into one line!!!\n";
    }

    #my $merged_line = mergePositions( \@prev_lines );
    my $merged_line =$prev_lines[0];
    if ( scalar(@prev_lines) > 1 ){
        $merged_line = mergePositions( \@prev_lines );
        }

    print $out_fh $merged_line."\n";
    close SORTED;
}

sub mergePositions{
    my ($lines) = @_;
    if ( $opt{DEBUG} ){
	print "[DEBUG] array with to merge lines...\n";
	print Dumper( $lines );
    }
    
    my %final = ();
    my ($chr, $pos, $id, $ref, $alt, $qual, $filt, $info_line, $format, $values);
    my ($longest_ref, $longest_alt) = ('','');

    my @format_fields;
    my %formats = ();
    my %alts = ();
    my %gt = ();
    my $has_ref_called = 0;
    foreach my $line ( @$lines ){
	#EXAMPLE: 
	#4	2829077	.	T	C	.	PASS	DP=46;MQ=60;NS=1	GT:AF:DP:RAF	1/1:0.98:46:0.00
	my ($tmp_chr, $tmp_pos, $tmp_id, $tmp_ref, $tmp_alt, $tmp_qual, $tmp_filt, $tmp_info_line, $tmp_format, $tmp_values) = split( "\t", $line );
	
	## skip ref call to avoid dot in alt string when other alts present
	next if $tmp_alt eq '.';

	$chr = $tmp_chr; $pos = $tmp_pos; $id = $tmp_id; $qual = $tmp_qual; $filt = $tmp_filt; $info_line = $tmp_info_line; $format = $tmp_format;
	
	$longest_ref = $tmp_ref if ( length($tmp_ref) > length($longest_ref) );
	$longest_alt = $tmp_alt if ( length($tmp_alt) > length($longest_alt) );
	
	my @orig_alts = split( ',', $tmp_alt );
	my @orig_form = split( ':', $tmp_format );
	my @orig_vals = split( ':', $tmp_values );
	die "[ERROR] No equal amount format_name/format_value in line [$line]\n" unless ( scalar(@orig_form) == scalar(@orig_vals) ); # sanity check
	
	## now collect the multiple alt fields
	foreach my $idx ( 0..$#orig_form ){
	    my $name = $orig_form[$idx];
	    my $val = $orig_vals[$idx];    
	    if ( $name eq 'GT' ){
		$has_ref_called = 1 if ($val =~ /0/);
	    }
	    elsif ($name eq 'AF'){
		my @orig_freqs = split( ',', $val );
		die "[ERROR] No equal amount alts/freqs in line [$line]\n" unless ( scalar(@orig_alts) == scalar(@orig_freqs) ); # sanity check
		foreach my $idx ( 0..$#orig_alts ){
		    my $uniq_combi = $tmp_ref.'_'.$orig_alts[ $idx ];
		    $alts{ $uniq_combi } = $orig_freqs[ $idx ];
		}
	    }
	    $formats{ $name } = $val;
	}
	@format_fields = @orig_form; # store the format field names for later use
    }
    
    my @final_alts = ();
    my @final_frqs = ();
    my @final_gt = ();
    my @final_form = ();
    push( @final_gt, 0) if $has_ref_called;
    my $gt_idx = 1;
    #print Dumper( \%alts );
    foreach my $variant ( keys %alts ){
	my ($a_ref, $a) = split( "_", $variant );
	my $new_a = adjustAltToLongest( $longest_ref, $a_ref, $a);
	push( @final_alts, $new_a );
	push( @final_frqs, $alts{ $variant } );
	push( @final_gt, $gt_idx );
	$gt_idx++;
    }
    
    $alt = join( ',', @final_alts );
    my $new_frq = join(',', @final_frqs);
    my $new_gt = join(',', @final_gt);
    $info_line =~ s/AF=[^;]+;/AF=$new_frq;/;
    $formats{ 'GT' } = join('/', @final_gt );
    $formats{ 'AF' } = $new_frq;
    foreach my $n ( @format_fields ){
	push( @final_form, $formats{ $n } );
    }
    my $new_values = join(':', @final_form );
    my @out = ($chr, $pos, $id, $longest_ref, $alt, $qual, $filt, $info_line, $format, $new_values );
    if ( $opt{DEBUG} ){
	print "[DEBUG] final merged output...\n";
	print join("\t", @out)."\n";
    }
    return( join("\t", @out) );
}
sub adjustAltToLongest{
    my ($long_ref, $ref, $alt) = @_;
    my $new_alt = $alt;
    $long_ref =~ s/^$ref//;
    $new_alt .= $long_ref;
    
    if ( $opt{DEBUG} ){
	print "----- adjustAltToLongest \n";
	print "IN: $long_ref  $ref  $alt\n";
	print "OUT: $new_alt\n";
	print "-----\n";
    }    
    return($new_alt);
}

sub addReferenceAndContigs{
    my ($ref, $header_lines) = @_;
    print "[INFO] Processing reference info\n";
    die "[ERROR addReferenceAndContigs] Unable to locate ref file [$ref]\n" unless -f $ref;
    push( @$header_lines, 'reference='.$ref );
    my $dict = $ref;
    $dict =~ s/\.fasta$/\.dict/;
    if ( -f $dict ){
	open DICT, $dict or die "[ERROR] Unable to open dict file [$dict]\n";
	while ( <DICT> ){
	    chomp;
	    my @columns = split( "\t", $_ );
	    if ( $columns[1] =~ /SN:(.+)/ ){
		my $contig_name = $1;
		if ( $columns[2] =~ /LN:(.+)/ ){
		    my $contig_len = $1;
		    push( @$header_lines, 'contig=<ID='.$contig_name.',length='.$contig_len.'>');
		}
	    }
	}
	close DICT;
    }else{
	print "[WARN] Unable to open dict file [$dict], so no contig info output to vcf\n";
    }
}

# --------------------------------------
# SUB: parses refiltered files by first storing all variants per position
# --------------------------------------
sub parseRefilteredSnps{
    my ($file, $fh, $fh_tmp, $header_lines) = @_;
    print "[INFO] Reading file settings [$file]\n";

    ## open file only to get settings info
    ## --------------------------------------
    open IN_SET, $file or die "Unable to open input $file: $!\n"; 
    while ( <IN_SET> ){
	chomp;
	if ( $_ =~ /#used settings (.*)/ ){ 
	    push( @$header_lines, 'variantCallSettings='.$1 );
	    last;
	}
    }
    close IN_SET;
    print "[INFO] Determining linecount [$file]\n";
    my $dataLineCount = `cat $file | wc -l`;
    #my $dataLineCount = `awk '!/^#/' $file | wc -l`;
    chomp( $dataLineCount );
    
    ## open file again to go trought variant calls
    ## --------------------------------------
    my $counter = 0;
    my $print_every = 100_000;
    open IN, $file or die "Unable to open input $file: $!\n"; 
    while ( <IN> ){
	chomp;
	$counter++;
	if ( ($counter % $print_every == 0) or $counter == 1 ){
	    my $percentage = int( ($counter*100 / $dataLineCount)+0.5 );
	    print "[INFO] ...processing line $counter of $dataLineCount (~$percentage %)\n" 
	}
	
	## save pipeline setting line and skip further comments
	next if $_ eq '' or $_ =~ /^#/;

	## chr, pos, reference alelle, alt allele, raw cov, informative cov, mapping qual, perc non-ref, tab delim calls (allele:depth)
	my @values = split( "\t", $_);
	die "input file [$file] seems not to be type \".refiltered_snps\, too few columns:\n$_\n" if scalar @values < 9;
	my ($chr,$pos,$ref,$alt_string,$oc,$ic,$mq,$pnr,@refilt_alts) = @values; 
	$chr =~ s/chr//;
	$chr = $CHR_CONVERSION{ $chr } if defined $CHR_CONVERSION{ $chr };
	
	## in case of iupac encoding: get all variants encoded
	my (%alts, %calls) = ( (), () );
	my @calls = ($alt_string);
	@calls = split( ',', $IUPAC{ $alt_string } ) if ( defined $IUPAC{ $alt_string } ); # get all alleles from iupac code
	$calls{ $_ } = 1 foreach @calls;
	
	## set up variables
	my (@alts, @geno, @freq, @original_alts);
	my $ref_perc = '0.00';
	my $original_call = $alt_string;
	my $original_alts = join(',', @refilt_alts);
	my $ref_reformat = $ref;
	
	
	## save all original alleles found at pos (NOTE: these might not all be calls)
	map { 
	    my ($alt,$dp) = split( ':', $_ ); 
	    $alt =~ s/^\.(.+)/$1/; # remove the stupid starting dots in indels
	    $alts{ $alt } = $dp; 
	    if ( $alt eq '.' ){ # save ref as ref allele instead of dot
		push( @original_alts, $ref.':'.$dp );
	    }else{
		push( @original_alts, $alt.':'.$dp );
	    }
	} @refilt_alts;
	
	## loop through all alleles reported and check if called
	my $ref_found = 0;
	my $alt_index = 1;
	foreach my $alt_string ( @original_alts ){
	    my ( $alt, $alt_dp ) = split( ':', $alt_string);
	    my $alt_reformat = $alt;
	    my $alt_perc = sprintf( "%.2f", $alt_dp / $ic ); # ic = informative coverage
	    
	    if ( ($alt eq '.') or ($alt eq $ref) ){ # if reference allele
	        $ref_found = 1 if $alt_perc >= $opt{ 'MIN_PV' }; # include ref call if high enough signal
	        $ref_perc = $alt_perc;
	    }
	    else{ # if alternative allele
	        next if !defined $calls{ $alt }; # next if not present as called variant in any input file
	        
	        ## reformat if indel found
	        if ( ($alt =~ /^(\+|\-)/) or (length($ref) != length($alt)) or ($ref eq '-') or ($alt eq '-') ){
	    	    ($ref_reformat, $alt_reformat) = parseIndelString( $ref, $alt ); ## example: A > +2AT becomes A > AAT
	    	}
	        die "NO alt_reformat in place\n" unless defined $alt_reformat;
	        die "NO ref_reformat in place\n" unless defined $ref_reformat;
	        push( @alts, $alt_reformat );
	        push( @freq, $alt_perc );
	        push( @geno, $alt_index++ );
	    }
	}
	
	
	## make sure final genotype string contains at least two variants
	if ( $ref_found ){ unshift( @geno, 0 );} # if ref allele found
	elsif( scalar @alts == 1 ){ unshift( @geno, 1 ); } # if no ref and only 1 variant
	
	## in case of only one reference call, fix info
	if ( scalar @geno == 1 and scalar @alts == 0 ){
	    unshift( @geno, 0 );
	    unshift( @alts, '.' );
	}
	
	my ($ALT, $AF, $RAF, $GT) = qw( . . . . );
	$ALT = join(",", @alts) if (scalar @alts > 0);
	$AF  = join(",", @freq) if (scalar @freq > 0);
	$RAF = $ref_perc;
	$GT  = join("/", @geno) if (scalar @geno > 0);
	$original_alts = join(",", @original_alts) if (scalar @original_alts > 0);
	
	## construct the vcf columns
	my @head_values = ( $chr, $pos, '.', $ref_reformat, $ALT, '.', 'PASS' );
	#y @info_values = ('NS=1', 'DP='.$ic, 'AF='.$AF, 'MQ='.$mq, 'RAF='.$RAF, 'ORI_CALL='.$original_call, 'ORI_ALTS='.$original_alts );
	#my @info_values = ( 'AF='.$AF, 'DP='.$ic, 'MQ='.$mq, 'NS=1', 'ORI_ALTS='.$original_alts, 'ORI_CALL='.$original_call, 'RAF='.$RAF );
	#my @info_values = ( 'AF='.$AF, 'DP='.$ic, 'MQ='.$mq, 'NS=1', 'ORI_ALTS='.$original_alts, 'RAF='.$RAF );
	#my @info_values = ( 'AF='.$AF, 'DP='.$ic, 'MQ='.$mq, 'NS=1', 'RAF='.$RAF );
	my @info_values = ( 'DP='.$ic, 'MQ='.$mq, 'NS=1' );
	my @format_labels = qw( GT DP AF RAF );
	my @format_values = ( $GT, $ic, $AF, $RAF );
	
	## print results to tmp file -> will later be sorted and copied to out file
    	print $fh_tmp join( "\t", @head_values, join(";", @info_values), join(":", @format_labels), join(":", @format_values)  )."\n";
    }
    print "[INFO] ...processing done [$counter lines processed]\n";
    close IN;
}

# --------------------------------------
# SUB: reformats indel string to vcf format
# Example: ref A / var +2TT becomes ref A alt ATT
# --------------------------------------
sub parseIndelString{
    my ($ref, $alt) = @_;
    die "[parseIndelString] Not all input defined [$ref > $alt]\n" unless defined($ref) and defined($alt);
    die "[parseIndelString] Not in indel? [$ref > $alt]\n" if length($ref) == length($alt);
    my $new_ref = "";
    my $new_alt = "";
    my @ref_nuc = split("", $ref );
    
    ## pipeline style insertions and deletions
    if ( $alt =~ /^(\+|\-)(\d+)(\w+)/ ){ # +2AT
	my ($type,$length,$nuc) = ($1, $2, $3); 
	if ( $type eq '+' ){ 
	    $new_alt = $ref.$nuc; 
	    $new_ref = $ref; 
	    return ($new_ref,$new_alt); # eg C,CAT
	}
	elsif( $type eq '-' ){ # eg -2AT
	    $new_ref = $ref.$nuc; 
	    $new_alt = $ref; 
	    return ($new_ref,$new_alt); # eg CAT,C
	}
    }
#    ## other than pipeline style (not supported now)
#    elsif( $alt =~ /([ACGT]{1})/ ){
#	
#	$new_alt .= $1;
#	$new_alt .= $_ foreach @ref_nuc[1..length($ref)-1];
#	return ($new_alt); 
#    }
    else{
	die "[EXIT parseIndelString] wrong format for indel (variant:$alt)\n";
    }
}

sub usage{
  my $script_name = (fileparse($0))[0];
  print <<END;
  
  Description:
      Will convert pipeline refiltered style input to vcf format
      
      For VCF specification see:
      http://www.1000genomes.org/node/101
      http://www.1000genomes.org/wiki/Analysis/Variant%20Call%20Format/vcf-variant-call-format-version-41
  
  REQUIRED: 
      -in|i     [s]  input variant list [refiltered_snps/refiltered_indels]
      -out|o    [s]  output vcf file [$opt{OUT}]
      -name|n   [s]  name of sample in vcf output
      
  OPTIONAL:
      -ref_af   [f]  minimal allele frequency for ref allele to be added to genotype [$opt{MIN_PV}]
      -ref_file [s]  path to reference file (if <REF>.dict exists the contig names are added to vcf)
      -no_zip        do not bgzip and tabix the final VCF file
      -debug         
                     
  EXAMPLE USAGE: 
      -name TEST_SAMPLE -in test.refiltered_snps -in test.refiltered_indels -in test.refiltered_reference -out test.vcf
  
  NOTES: 
      - uses informative coverage column (ic) for vcf-depth (DP)
      - '.vcf' is auto added to output name if not present in -out
      - final vcf is bgzipped and tabix indexed by default!
      - does merge positions (so 2 variants at same position
        should correctly end up in the same line in the vcf..)
  
  SCRIPT: $script_name (version:$SCRIPT_VERSION)
  
END
  exit;
}
