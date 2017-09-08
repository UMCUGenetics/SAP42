#!/usr/bin/perl -w
use strict;
use Getopt::Long;
use Data::Dumper;
use Cwd;
use File::Basename;

## =========================
## DESCR: A tool to convert a pipeline variant-list (eg .refiltered_snps) to vcf format
## AUTHR: S. van Lieshout
## USAGE: see -h
## INFO:  http://www.1000genomes.org/wiki/Analysis/Variant%20Call%20Format/vcf-variant-call-format-version-41
## =========================
my $SCRIPT_VERSION = 8;
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my %opt = (
    'HELP' => '',
    'NAME' => '', # name to be used for sample identifier in vcf
    'DEBU' => '',
    'IN'   => [], # input files
    'OUT'  => '', # outfilebase
    'OUTD' => '', # outdir
    'DATE' => ($year+1900).sprintf("%0*d", 2, ($mon+1)).sprintf("%0*d", 2, $mday), # year starts at 1900 and month is array starting with 0
    'MIN_PV' => 0.15, # minimal percentage variant
);

## conversion hash for sorting without warning
my %CHR_CONVERSION = ( 'X' => 1000, 'Y' => 2000, 'MT' => 3000);  
my %CHR_CONVER_REV = reverse( %CHR_CONVERSION );

my %IUPAC = ( 'A'=>'A', 'C'=>'C', 'G'=>'G', 'T'=>'T', 'R'=>'A,G', 'Y'=>'C,T', 'S'=>'G,C', 'W'=>'A,T', 'K'=>'G,T', 'M'=>'A,C', 'B'=>'C,G,T', 'D'=>'A,G,T', 'H'=>'A,C,T', 'V'=>'A,C,G', 'N'=>'A,C,G,T', );
my @TYPE = qw( refiltered_snps );
my @META = qw( fileformat fileDate source reference );
my @HEAD = qw( CHROM POS ID REF ALT QUAL FILTER );
my @INFO = qw( NS DP AF MQ RAF ALTS );
my @FORMAT = qw( GT DP RAF AF );


## Get options and set output name
die usage() if @ARGV == 0;
GetOptions (
    'h|help'     => \$opt{HELP},
    'in|i=s@'    => \$opt{IN},
    'out|o=s'    => \$opt{OUT},
    'name|n=s'   => \$opt{NAME},
    'outdir=s'   => \$opt{OUTD},
    'ref_af=f'   => \$opt{MIN_PV},
    'debug'      => \$opt{DEBU},
) or die usage();
## make sure we know the input type by filename or given parameter
#$opt{TYPE} = determineInputType( $opt{IN}->[0] ) unless $opt{TYPE};

if ( $opt{OUT} and $opt{OUTD} ){
    print "===>\n[EXIT] use -out OR -outdir, not both\n===>\n" and usage();
}elsif( $opt{OUTD} ){
    $opt{OUT} = $opt{OUTD}.'/'.(fileparse( $opt{IN} ))[0].'.vcf';
}
$opt{OUT} = $opt{IN}[0].'_converted2vcf' unless $opt{OUT};
$opt{OUT} .= '.vcf' unless $opt{OUT} =~ /\.vcf$/;

## check if everything is ok to start
usage() if $opt{HELP};
print "===>\n[EXIT] provide input file\n===>\n" and usage() unless $opt{IN};
print "===>\n[EXIT] provide output filename\n===>" and usage() unless $opt{OUT};
#print "===>\n[EXIT] type not recognized from filename, pls provide input type [$TYPES]\n===>" and usage() unless $opt{TYPE};
#print "===>\n[EXIT] type \"$opt{TYPE}\" not supported\n==+>" and usage() unless $opt{TYPE} =~ /^($TYPES)$/;

## INFO HASHES
my %META_DESC = (
    'fileformat' => 'VCFv4.1',
    'fileDate'   => $opt{DATE},
    'source'     => $0.'(version:'.$SCRIPT_VERSION.')', # set script as source
    'reference'  => 'unknown',
);
my %INFO_DESC = (
    'NS'   => 'INFO=<ID=NS,Number=1,Type=Integer,Description="Number of Samples With Data">',
    'DP'   => 'INFO=<ID=DP,Number=1,Type=Integer,Description="Total Depth">',
    'AF'   => 'INFO=<ID=AF,Number=A,Type=Float,Description="Allele Frequency">',
    'MQ'   => 'INFO=<ID=MQ,Number=1,Type=Integer,Description="Mapping Quality">',
    'RAF'  => 'INFO=<ID=RAF,Number=1,Type=Float,Description="Reference Allele Frequency">',
    'ALTS' => 'INFO=<ID=ALTS,Number=A,Type=String,Description="Original Alelle String">',
);
my %FORMAT_DESC = (
    'GT'  => 'FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">',
    'DP'  => 'FORMAT=<ID=DP,Number=1,Type=Integer,Description="Total Depth">',
    'AF'  => 'FORMAT=<ID=AF,Number=A,Type=Float,Description="Allele Frequency">',
    'RAF' => 'FORMAT=<ID=RAF,Number=1,Type=Float,Description="Reference Allele Frequency">',
);


# ==================================
# MAIN
# ==================================
$META_DESC{ 'reference' } = parseReferenceFileFromConfig( $opt{ IN }->[0] );

my %VARIANTS = ();
my @EXTRA_LINES = ();

my $file_index = 1;
foreach my $file ( @{$opt{IN}} ){
    parseRefilteredSnps( $file, \%VARIANTS, \@EXTRA_LINES, $file_index++ );
}
outputVcf( $opt{OUT}, \%VARIANTS, \@EXTRA_LINES, \%META_DESC, \%INFO_DESC, \%FORMAT_DESC );
# ==================================
# /MAIN
# ==================================



# --------------------------------------
# SUB: If input file is in library dir, the .conf file can be used to get reference file
# --------------------------------------
sub parseReferenceFileFromConfig{
    my ($input_file) = @_;
    my $base_dir = (fileparse( $input_file ))[1];
    foreach my $config_file ( <$base_dir/*.conf> ){
	my @grep_out = `grep REFERENCE $config_file`;
	while ( my $line = `grep REFERENCE $config_file` ){
	    chomp($line); 
	    my ($desc, $file) = split("\t", $line);
	    return( $file ) if ( $desc eq 'REFERENCE' and $file );
	}
    }
    return( 'unknown' );
}

# --------------------------------------
# SUB: parses refiltered files by first storing all variants per position
# --------------------------------------
sub parseRefilteredSnps{
    my ($file, $variants, $extra_lines, $file_index) = @_;
    
    open IN, $file or die "Unable to open input $file: $!\n"; 
    print "[INFO] Reading file [$file]\n";
    push( @{$extra_lines}, 'converter_input_file_'.$file_index.'='.$file );
    
    while ( <IN> ){
	chomp;

	## save pipeline setting line and skip further comments
	push( @{$extra_lines}, 'varcall_settings_file_'.$file_index.'='.$1 ) if ( $_ =~ /#+used settings (.*)/ );
	next if $_ eq '' or $_ =~ /^#/;

	## chr, pos, reference alelle, alt allele, raw cov, informative cov, mapping qual, perc non-ref, tab delim calls (allele:depth)
	my @values = split( "\t", $_);
	die "input file [$file] seems not be of type \".refiltered_snps\, too few columns:\n$_\n" if scalar @values < 9;
	my ($chr,$pos,$ref,$alt,$oc,$ic,$mq,$pnr,@alts) = @values; 
	$chr =~ s/chr//;
	my $chr_nr = $chr;
	$chr_nr = $CHR_CONVERSION{ $chr } if $CHR_CONVERSION{ $chr };
	
	## in case of iupac encoding: get all variants encoded
	my (%alts, %calls) = ( (), () );
	my @calls = ($alt);
	@calls = split( ',', $IUPAC{ $alt } ) if ( defined $IUPAC{ $alt } ); # get all alleles from iupac code
	
	map { my ($alt,$dp) = split( ':', $_ ); $alt =~ s/^\.(.+)/$1/; $alts{ $alt } = $dp; } @alts;
	map { $calls{ $_ } = {}; } @calls;

	if ( defined $variants->{ $chr_nr }{ $pos } ){ ## add calls is variant pos already stored
	    $variants->{ $chr_nr }{ $pos }{ CALLS }{ $_ } = {} foreach @calls;
	}
	else { ## create new variant if not yet stored
	    my %var = (
		'CHROM' => $chr,
		'POS'   => $pos,
		'REF'   => $ref,
		'ALTS'  => \%alts,
		'CALLS' => \%calls,
		'FILTER'=> 'PASS',
		'NS'    => 1,
		'DP'    => $ic,
		'MQ'    => $mq,
		'RAF'   => sprintf( "%.3f", 0 ),
	    );
	    map { $var{ $_ } = '.' unless defined $var{ $_ } } ( @HEAD, @FORMAT, @INFO );
	    $variants->{ $chr_nr }{ $pos } = \%var;
	}
    }
    close IN;
}

# --------------------------------------
# SUB: prints all variants in hash as vcf file
# --------------------------------------
sub outputVcf{
    my ($out,$variants,$extra_lines,$meta,$info,$format) = @_;
    my @output; # output first stored because settings are spliced in later
    open OUT, ">$out" or die "Unable to open output $out: $!\n"; 
    
    ## if provided use name as sample id, else read filename from first inptu
    my $sample_id = (fileparse( $opt{IN}->[0] ))[0];
    $sample_id = $opt{NAME} if $opt{NAME};
    
    ## print the info lines at top of vcf
    push @output, "##$_=$meta->{ $_ }\n" foreach @META;
    push @output, "##$_\n" foreach @$extra_lines;
    push @output, "##$info->{ $_ }\n" foreach @INFO;
    push @output, "##$format->{ $_ }\n" foreach @FORMAT;
    push @output, '#'.join("\t", @HEAD, 'INFO', 'FORMAT', $sample_id)."\n";
    print OUT $_ foreach @output;
        
    ## collect per position the variants and output to vcf
    my $counter = 0;
    foreach my $chr ( sort {$a <=> $b} keys %$variants ){
	my $chr_name = $chr;
	$chr_name = $CHR_CONVER_REV{ $chr } if $CHR_CONVER_REV{ $chr };
	print "[INFO] Outputting VCF records for chr $chr_name\n";
	
	foreach my $pos ( sort {$a <=> $b} keys %{$variants->{ $chr }} ){
	    my $var = $variants->{ $chr }{ $pos };
	    
	    ## find the longest common REF sequence from actual calls
	    my $original_ref = $var->{REF};
	    die "[ERROR] At this stage ref [$original_ref] lenght should be 1...?!\n" if length($original_ref) != 1;
	    foreach my $call ( keys %{$var->{CALLS}} ){
		if ( $call =~ /^\-(\d+)(\w+)$/ ){
		    my $new_len = $1+1;
		    my $del_nuc = $2;
		    $var->{REF} = $original_ref.$del_nuc if $new_len > length($var->{REF});
		}
	    }
	    
	    ## set up variables
	    my @ref_nuc = split( "", $var->{REF} );
	    my $ref_len = length( $var->{REF} );
	    my (@alts, @geno, @freq, @original_alts);
	    my $ref_found = 0;
	    
	    ## loop through all alleles reported and check if called
	    my $alt_index = 1;
	    foreach my $alt ( keys %{$var->{ ALTS }} ){
		
		my $alt_dept = $var->{ ALTS }{ $alt };
		my $alt_perc = sprintf( "%.3f", $alt_dept / $var->{ DP } );
		
		if ( $alt eq '.' ){ # if reference allele
		    $ref_found = 1 if $alt_perc >= $opt{ 'MIN_PV' }; # include ref call if high enough signal
		    $var->{ RAF } = $alt_perc;
		}
		else{ # if alternative allele
		    next if !defined $var->{CALLS}{ $alt }; # next if not present as called variant in any input file
		    my $alt_reformat = parseIndelString( $var->{REF}, $alt ); ## example: A > +2AT becomes A > AAT
		    push( @alts, $alt_reformat );
		    push( @freq, $alt_perc );
		    push( @geno, $alt_index++ );
		    push( @original_alts, $alt );
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
	    
	    ## replace info to match all variants found at this pos
	    $var->{ ALT } = 'NA';
	    $var->{ GT  } = 'NA';
	    $var->{ AF  } = '0.00';
	    $var->{ ALTS } = 'NA';
	    
	    $var->{ ALT } = join(",", @alts) if (scalar @alts > 0);
	    $var->{ GT  } = join("/", @geno) if (scalar @geno > 0);
	    $var->{ AF  } = join(",", @freq) if (scalar @freq > 0);
	    $var->{ ALTS } = join(",", @original_alts) if (scalar @original_alts > 0);
	    
	    
	    ## check whether all info is present and print if so
	    map { die "COLUMN INFO not present for column $_\n" unless defined $var->{ $_ } } @HEAD, @INFO, @FORMAT; 	    
	    my @head_values = map( $var->{ $_ }, @HEAD );
	    my @info_values = map( $_.'='.$var->{ $_ }, @INFO );
	    my @format_labels = map ( $_, @FORMAT );
	    my @format_values = map ( $var->{ $_ }, @FORMAT );
	
    	    #push @output, join( "\t", @head_values, join(";", @info_values), join(":", @format_labels), join(":", @format_values)  )."\n";
    	    print OUT join( "\t", @head_values, join(";", @info_values), join(":", @format_labels), join(":", @format_values)  )."\n";
	    $counter++;
	}
    }
    print "[INFO] ...$counter variants processed\n";
    print "[INFO] ...output in $out\n";    
    close OUT;
}

# --------------------------------------
# SUB: reformats indel string to vcf format
# Example: ref A / var +2TT becomes ref A alt ATT
# --------------------------------------
sub parseIndelString{
    my ($ref, $alt) = @_;
    my $new_alt = "";
    my @ref_nuc = split("", $ref );
    
    if ( $alt =~ /^(\+|\-)(\d+)(\w+)/ ){ # +2AT
	my ($type,$length,$nuc) = ($1, $2, $3); 
	if ( $type eq '+' ){ 
	    #$new_alt .= $_ foreach @ref_nuc
	    $new_alt = $ref.$nuc; return ($new_alt); 
	}
	elsif( $type eq '-' ){
	    my $last_index = scalar( @ref_nuc ) - ($2+1);
	    $new_alt .= $_ foreach @ref_nuc[0..$last_index];
	    return ($new_alt); 
	}
    }
    elsif( $alt =~ /([ACGT]{1})/ ){
	$new_alt .= $1;
	$new_alt .= $_ foreach @ref_nuc[1..length($ref)-1];
	return ($new_alt); 
    }
    else{
	die "[EXIT parseIndelString] wrong format for indel (variant:$alt)\n";
    }
}

# --------------------------------------
# SUB: guesses input type by filename
# --------------------------------------
sub determineInputType{
    my ($file) = @_;
    my $type = '';
    $type = 'refiltered_snps' if $file =~ /refiltered(_snps|_indels)/;
    return $type;
}


sub usage{
  print <<END;
  
  Description:
      Will convert the input variant list into VCF format. For VCF specification see:
      http://www.1000genomes.org/node/101
      http://www.1000genomes.org/wiki/Analysis/Variant%20Call%20Format/vcf-variant-call-format-version-41
  
  Usage: 
      -in|i     [s]  input variant list [refiltered_snps/refiltered_indels]
      
  Options:
      -out|o    [s]  output vcf file [$opt{OUT}]
      -name|n   [s]  name of sample in vcf output [defaults to first input file]
      -ref_af   [f]  minimal allele frequency for ref allele to be added to genotype [$opt{MIN_PV}]
                     
  Example usage: 
      -in test.refiltered_snps -out test.vcf
  
  NOTE: 
      - uses informative coverage column (ic) for vcf-depth (DP)
      - '.vcf' is added to output name if not present
  
  Version: $SCRIPT_VERSION
  
END
  exit;
}
