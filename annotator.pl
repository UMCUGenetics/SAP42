#!/usr/bin/perl -w
use strict;

use Getopt::Long;
use Data::Dumper;
use File::Basename; # see function "fileparse"

## authr: S. van Lieshout
## descr: Adds various annotation to an input variant list (snps and/or indels) using Ensembl API
## usage: see -h

## Need to use a BEGIN for being able to optionally provide ensembl api version 
my %opt;
my $projectLocation;
BEGIN{ 
    %opt = (
		'help'           => undef, 
		'in'             => undef,
		'out'            => undef,
		'short_input'    => undef,
		'vcf_input'      => undef,
		'ion_input'      => undef,
		'varSumm_input'  => undef,
		'bamAnn_input'   => undef,
		'add_go'         => undef,
		'host'           => 'wgs10.op.umcutrecht.nl',
		'user'           => 'ensembl',
		'species'        => 'Homo_sapiens',
		'gerp_alnset'    => 'mammals',
		'gerp_offset'    => 5, # 5 leads to 11bp region
		'pred_methods'   => ['sift','polyphen'], # prediction methods (condel unsupported from v68)
		'undef_char'     => 'NA',
		'script_version' => 11, # 9 was first version with "new" consequence names
		'ensembl_v'      => 72,
		'print_extra'    => undef,
    );
    
    sub usage{ 

	print <<END;

 Usage: -in <INPUT_VARIANT_LIST>

  ** NEEDS AT LEAST V.63 ENSEMBL API **
  ** DEFAULT VERSION v69 **
  ** MOST RECENT VERSION TESTED WITH SUCCES = V.69 **
  ** CONSEQUENCE NAMES CHANGED TO SO TERMS FROM V.69 **
 
  Required params:
   -in          [s]  input file (see input-type below for accecpted formats)
 
  Options:
   -out         [s]  base output filename [default is input name]
   -host        [s]  local ensembl db [$opt{host}]
   -user        [s]  local ensembl db user [$opt{user}]
   -species     [s]  species [$opt{species}]
   -ensembl_v   [i]  version of ensembl api/db [$opt{ensembl_v}]
  
  Input-type (NOTE: script guesses by file extension): 
   -short_in|si      input is short format, 4 columns: chr pos ref alt 
                     (alt can be string with alts seperated by any of |:,/
   -vcf_in           input is treated as vcf format .vcf
   -ion_in           input is treated as ion torrent variant table format .variantTable
   -var_in           input is treated as varSumm format .varSumm
   -ban_in           input is treated as bamAnnotated format .bamAnn
 
  Description:
   Reads in a a variant list and uses the ensembl perl API 
   to annotate them and outputs to:
     - <OUT>.snv1: SNVs that (can) have a substantial effect (eg STOP_GAINED)
     - <OUT>.snv2: all other variants (such as INTRONIC etc)
 
  Notes:
   - script recognizes *refiltered_snps* in filename
   - script recognizes extensions: .vcf .varSumm .bamAnn
   - variant AG/- is part of SNP AG/TA/-, so then rs number is printed
   - COSMIC ids are put in snp_id column together with DBSNP ids
   - the conservation scores are for fixed intervals so not very informative for indels
	  
END
	exit;
    }

    die usage() if @ARGV == 0;
    GetOptions (
		'h|help'      => \$opt{help},
		'in=s'        => \$opt{in},
		'out=s'       => \$opt{out},
		'species=s'   => \$opt{species},
		'host=s'      => \$opt{host},
		'user=s'      => \$opt{user},
		'pass=s'      => \$opt{host_pwd},
		'short_in|si' => \$opt{short_input},
		'vcf_in'      => \$opt{vcf_input},
		'ion_in'      => \$opt{ion_input},
		'var_in'      => \$opt{varSumm_input},
		'ban_in'      => \$opt{bamAnn_input},
		'add_go'      => \$opt{add_go},
		'ensembl_v=i' => \$opt{ensembl_v},
		'print_extra' => \$opt{print_extra},
    ) 
    or die usage();
    die usage() if $opt{help};
    die "[ERROR] No input file or doesn't exist [ $opt{in} ]\n" unless $opt{in} and -e $opt{in};
    die "[ERROR] Local DB specified but no user name, see -h\n" if $opt{host} and not $opt{user};
    
    $projectLocation = $0;
    $projectLocation = '/data/common_scripts/SAP42-testing/' unless $projectLocation =~ /SAP42/; # if script not in pipeline, still try to find ini in default for wgs01
    $projectLocation =~ s/[\w\.]+?$//;
    $projectLocation = './' if $projectLocation !~ /\//;
    unshift(@INC, $projectLocation) ;
    require settings;
    my $pipeline_settings = settings::loadConfiguration("$projectLocation/sap42.ini");
    unshift(@INC, $pipeline_settings->{PERLMODULES});
    unshift(@INC, $pipeline_settings->{PERLMODULES}.'/vcftools/lib/perl5/site_perl/');
    #use lib 'modules';

}# END of BEGIN

use Vcf; # vcf tools for parsing vcf input

## add paths for pipeline@umc
use lib '/hpc/cog_bioinf/common_modules/bioperl-live';
use lib '/hpc/cog_bioinf/common_modules/ensembl'.$opt{ensembl_v}.'/ensembl/modules';
use lib '/hpc/cog_bioinf/common_modules/ensembl'.$opt{ensembl_v}.'/ensembl-variation/modules';
use lib '/hpc/cog_bioinf/common_modules/ensembl'.$opt{ensembl_v}.'/ensembl-compara/modules'; 
## add paths for pipeline@hubrecht
use lib '/home/sge_share_fedor8/common_modules/bioperl-live';
use lib '/home/sge_share_fedor8/common_modules/'.$opt{ensembl_v}.'/ensembl/modules';
use lib '/home/sge_share_fedor8/common_modules/'.$opt{ensembl_v}.'/ensembl-variation/modules';
use lib '/home/sge_share_fedor8/common_modules/'.$opt{ensembl_v}.'/ensembl-compara/modules';


my $current_node = `uname -n`; 
$opt{host} = 'localhost' if $current_node =~ /$opt{host}/; # node where mysql DB runs requires special attention...
$opt{out} = $opt{in} unless $opt{out}; # set output basename to input if not specified

## check extension for file type
$opt{ion_input} = 1 if ( $opt{in} =~ /\.variantsTable$/ );
$opt{varSumm_input} = 1 if ( $opt{in} =~ /\.varSumm$/ );
$opt{vcf_input} = 1 if ( $opt{in} =~ /\.vcf$/ );
if ( $opt{in} =~ /\.bamAnnotated$/ or $opt{in} =~ /\.bamAnn$/ ){
    $opt{bamAnn_input} = 1 ;
    $opt{print_extra} = 1;
}

## set output file names
if ( $opt{in} =~ /refiltered_indels/ ){ # in case of indels
	$opt{out_snv1} = $opt{out}.'.indels.snv1';
	$opt{out_snv2} = $opt{out}.'.indels.snv2';
	$opt{out_log}  = $opt{out}.'.indels.log';
}
elsif ( $opt{in} =~ /refiltered_snps/ ){ # in case of snvs
	$opt{out_snv1} = $opt{out}.'.snvs.snv1';
	$opt{out_snv2} = $opt{out}.'.snvs.snv2';
	$opt{out_log}  = $opt{out}.'.snvs.log';
}
else { # for all other cases set neutral output names
	$opt{out_snv1} = $opt{out}.'.snv1';
	$opt{out_snv2} = $opt{out}.'.snv2';
	$opt{out_log}  = $opt{out}.'.log';
}

# ======================================================
# Prepare ensembl api stuff
# ======================================================
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::ApiVersion;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
my $registry = 'Bio::EnsEMBL::Registry';
my ($sa, $ga, $va, $vfa); # adaptors

# try to load the registry and adaptors (first local DB then online)
getRequiredAdaptors( $opt{ host }, $opt{ user },  \$sa, \$ga, \$va, \$vfa ) if $opt{ host } and $opt{ user}; 
getRequiredAdaptors( 'ensembldb.ensembl.org', 'anonymous', \$sa, \$ga, \$va, \$vfa ) unless ($sa and $ga and $va and $vfa); 
die "[ERROR] After trying all hosts still not all adapters available, perhaps incorrect species name ($opt{species})?\n" unless ($sa and $ga and $va and $vfa);

# load compara adaptors (for GERP conservation score)
my $mlss_adaptor = $registry->get_adaptor("Multi", "compara", "MethodLinkSpeciesSet");
my $mlss = $mlss_adaptor->fetch_by_method_link_type_species_set_name("GERP_CONSERVATION_SCORE", $opt{gerp_alnset});
my $cs_a = $registry->get_adaptor("Multi", 'compara', 'ConservationScore');			
die "[ERROR] Unable to find ConservationScore/aligment in compara" unless ($cs_a and $mlss);

## set variation feature adaptor to include also those flagged "failed" by ensembl (from eg dbsnp, cosmic)
#$vfa->db->include_failed_variations(1);

# ======================================================
# Variables / matrices
# ======================================================

# chromosome conversion making numerically sorting w/o warning possible
my %CHR_CONVERSION_FW = ( 'X' => 1000, 'Y' => 2000, 'MT' => 3000 );
my %CHR_CONVERSION_RV = reverse %CHR_CONVERSION_FW;
my %IUPAC = %{ createIupacHash() };
my %GRANTHAM = %{ createGranthamScoresHash() };

# Significant effects (other possible effects are: SYNONYMOUS_CODING|5PRIME_UTR|3PRIME_UTR|INTRONIC|UPSTREAM|DOWNSTREAM|WITHIN_NON_CODING_GENE)
my $EFFECTS_REGEX = 'NON_SYNONYMOUS_CODING|STOP_GAINED|STOP_LOST|ESSENTIAL_SPLICE_SITE|FRAMESHIFT_CODING|REGULATORY_REGION|WITHIN_MATURE_miRNA|PARTIAL_CODON|SPLICE_SITE';

# These effects / consequences had to be added because ensembl changed default to SO terms
$EFFECTS_REGEX .= '|transcript_ablation|splice_donor_variant|splice_acceptor_variant|stop_gained|frameshift_variant|stop_lost|initiator_codon_variant|inframe_insertion';
$EFFECTS_REGEX .= '|inframe_deletion|missense_variant|transcript_amplification|splice_region_variant|incomplete_terminal_codon_variant|TFBS_ablation|TFBS_amplification';
$EFFECTS_REGEX .= '|TF_binding_site_variant|regulatory_region_variant|regulatory_region_ablation|regulatory_region_amplification|feature_elongation|feature_truncation';

## HEADER for output all the values are PRINTED IN THE ORDER OF THIS ARRAY!!
my @head1 = qw( chr pos na_change );
my @head2 = qw( strand raw_cov inf_cov inf_pnr aa_change 
genotype gene_name ccds_id codon snp_id effect hgvs_t hgvs_p polyphen_s 
polyphen_p sift_s sift_p grantham gerp gerp_region high_freq 
high_popu gene_id tran_id prot_id biotype ncbi36_hg18 );

# the last column contains several infoblocks
my @INFO_FIELDS = qw( UNIPROT REFSEQ_T REFSEQ_P UNIGENE MIM_ID MIM_DESC GENE_DESC );
my @HEADER_EXTRA_FIELDS = ();

# ======================================================
# open input pileup and output files
open SNV1, ">$opt{out_snv1}" or die "$!: @_\n";
open SNV2, ">$opt{out_snv2}" or die "$!: @_\n";
open LOG,  ">$opt{out_log}"  or die "$!: @_\n";

# ======================================================
# start analysis
# ======================================================
# collect all variations and store in hash
my $input_file_type = 'INPUT_FILE_TYPE:';
my %all_variations;
if ( $opt{ vcf_input } ){ 
    print "[INFO] Parsing input file as VCF format\n";
    print LOG "[INFO] Parsing input file as VCF format\n";
    parseVCF( $opt{in}, \%all_variations); 
    $input_file_type .= 'vcf';
}
elsif( $opt{ ion_input } ){ 
    print "[INFO] Parsing input file as ION TORRENT table format\n";
    print LOG "[INFO] Parsing input file as ION TORRENT table format\n";
    parseIonVariants( $opt{in}, \%all_variations); 
    $input_file_type .= 'ionTorrentVariantsTable';
}
elsif( $opt{ bamAnn_input } ){ 
    print "[INFO] Parsing input file as BAM ANNOTATION format\n";
    print LOG "[INFO] Parsing input file as BAM ANNOTATION format\n";
    parsePipelineRefiltered( $opt{in}, \%all_variations); 
    $input_file_type .= 'bamAnn';
}
elsif( $opt{ short_input } ){  # also short input is handled here as first columns are equal
    print "[INFO] Parsing input file as short format (4 columns)\n";
    print LOG "[INFO] Parsing input file as short format (4 columns)\n";
    parsePipelineRefiltered( $opt{in}, \%all_variations); 
    $input_file_type .= 'shortInput';
}
elsif( $opt{ varSumm_input } ){  # also short input is handled here as first columns are equal
    print "[INFO] Parsing input file as varSumm format\n";
    print LOG "[INFO] Parsing input file as varSumm format\n";
    parsePipelineRefiltered( $opt{in}, \%all_variations); 
    $input_file_type .= 'varSumm';
}
else{ # also short input is handled here as first columns are equal
    print "[INFO] Parsing input file as pipelineRefiltered format\n";
    print LOG "[INFO] Parsing input file as pipelineRefiltered format\n";
    parsePipelineRefiltered( $opt{in}, \%all_variations); 
    $input_file_type .= 'pipelineRefiltered';
}

# print script version and header to output files
my $script_n  = 'SCRIPT_NAME='.(fileparse($0))[0];
my $script_v  = 'SCRIPT_VERSION='.$opt{script_version};
my $ensembl_v = 'ENSEMBL_VERSION='.software_version();
my $host_n    = 'HOST='.$sa->dbc->host;
my $dbsnp_v   = 'DBSNP_VERSION='.$va->get_source_version('dbSNP');
my $gerp_v    = 'GERP_ALIGN_SET='.$opt{gerp_alnset};
my $settings  = '##ANNOTATOR_SETTINGS: '.join(';', $script_n, $script_v, $host_n, $ensembl_v, $dbsnp_v, $gerp_v, $input_file_type )."\n";

print SNV1 $settings;
print SNV2 $settings;
print LOG  $settings;
print SNV1 '#'.join("\t", @head1, @HEADER_EXTRA_FIELDS, @head2, 'info' )."\n";
print SNV2 '#'.join("\t", @head1, @HEADER_EXTRA_FIELDS, @head2, 'info' )."\n";


# ======================================================
my ($count, $index) = (0,1);
$count += scalar keys %{$all_variations{ $_ }} foreach keys %all_variations;

foreach my $chr_nr ( sort {$a <=> $b} keys %all_variations ){
    my $chr_char = $CHR_CONVERSION_RV{ $chr_nr } || $chr_nr; # 1000,2000,3000 == X,Y,MT
    
    # only proceed with chr if able to create slice
    my $slice = $sa->fetch_by_region('chromosome',$chr_char);
    unless ( $slice ){
		printInfoMessage('seqadapter', undef, $chr_char);
		next;
    }
    # now foreach variant position: process as snv or as indel
    foreach my $pos ( sort {$a <=> $b} keys %{$all_variations{$chr_nr}} ){
		foreach my $alt_allele ( sort keys %{$all_variations{$chr_nr}{ $pos }} ){

			my $var = $all_variations{$chr_nr}{$pos}{ $alt_allele };
			# var could be iupac code, so check and treat as seperate variations
			#my @alts = split( /[\|,]/ , $var->{alt} );
			my $pnrs = $var->{ inf_pnr };
			my @alts = split( /[\|,]/ , $alt_allele );
			my @pnrs = split( /[\|,]/ , $pnrs );
			
			print "[INFO] $index of $count | $chr_char\:$pos GT:$alt_allele\n";
			foreach my $alt_sub_allele ( @alts ){
			
			    $var->{inf_pnr} = shift @pnrs; # set pnr corresponding to current var
			    print "  [SKIP] Ref ($var->{ref} same as variant ($alt_sub_allele)\n" and next if $alt_sub_allele eq $var->{ref};
			    next if $alt_sub_allele eq 'REF'; # varSumm format contains all alleles in CALL string
			    my $is_indel = isIndel( $var->{ref}, $alt_sub_allele );
			    $var->{alt} = $alt_sub_allele;
			
			    # a different (pre-)processing for snvs vs. indels
			    print "[INFO]   VARIANT:$var->{ref}/$alt_sub_allele\n";
			    process_snv( $all_variations{$chr_nr}{$pos}{ $alt_allele }, $slice ) unless $is_indel;
			    process_indel( $all_variations{$chr_nr}{$pos}{ $alt_allele }, $slice ) if $is_indel;
			}
		}
		$index++;
    }
}

# end message for later completeness check
print SNV1 "#END\n";
print SNV2 "#END\n";
print LOG  "#END\n";

close SNV1;
close SNV2;
close LOG;

printConfigMessage();

########################################################
## SUBROUTINES
########################################################
sub parsePipelineRefiltered{
    my ($file, $variant_hash) = @_;
    my $sep_regex = '[|:,\/]';
    
    ## get header info
    my $header;
    if ( $opt{ 'varSumm_input' } ){
	$header = getHeaderFromFile( $file, '#CHROM' ); ## get the header from the file to make sure we always select correct column
	die "[header_check] unable to get header (/^#CHROM/) from file [$file]...?\n" unless scalar @$header;
    }
    elsif( $opt{ 'bamAnn_input' } ){
	$header = getHeaderFromFile( $file, '#chr' ); ## get the header from the file to make sure we always select correct column
	my $last_index = scalar( @$header )-1;
	push( @HEADER_EXTRA_FIELDS, @{$header}[4..$last_index] );
	die "[header_check] unable to get header (/^#chr/) from file [$file]...?\n" unless scalar @$header;
    }
    
    ## get variants info
    open IN, $file or die "$!: @_\n";
    while ( <IN> ) {
		chomp;
		next if $_ eq ''; # skip empty lines

		# print all comments (except header and END) to all output
		if ( $_ =~ /^#/ ){ 
			next if ( $_ =~ /^CHROM|#chr|#CHROM|#END/ );
			my $prefix = '';
			$prefix = '#' if $_ !~ /^#{2,}/;
			print SNV1 $prefix.$_."\n";
			print SNV2 $prefix.$_."\n";
			print LOG  $prefix.$_."\n";
			next;
		}
		
		my @fields = split("\t", $_);
		my @extra = ();
		my ($chr, $pos, $ref, $strand, $ref_alt_string, $alt_string, $cov_raw, $cov_inf, $pnr_inf, $calls) = ('NA','NA','NA','NA','NA','NA',0,0,0,'NA');
		my @alts = ();
		
		if ( $opt{ 'short_input' } ){ # fewer columns
			($chr, $pos, $ref, $alt_string) = @fields[0..3];
			@alts = split( /$sep_regex/, $alt_string );
		}
		elsif( $opt{ 'bamAnn_input' } ){
			die "[ERROR] header count != nr of fields!!!\n" unless (scalar @$header == scalar @fields);
			($chr, $pos, $strand, $ref_alt_string, @extra) = @fields;
			($ref, $alt_string) = split( "/", $ref_alt_string );
			@alts = split( /$sep_regex/, $alt_string );
			
		}
		elsif( $opt{ 'varSumm_input' } ){ # parse as varSumm
			
			my %info = ();
			$info{ $_ } = shift @fields foreach @$header;
			$chr = $info{ '#CHROM' };
			$pos = $info{ 'POSITION' };
			$ref = $info{ 'REF' };
			$alt_string = $info{ 'ALLELES' } or die "[ERR] no ALLELES field for varSumm?\n";
			if ( defined($info{ 'MAX_FRQ' }) ){
			    $pnr_inf = $info{ 'MAX_FRQ' };
			}else{
			    $pnr_inf = $info{ 'pALT' } or die "[ERR] no MAX_FRQ and no pALT field...unable to define pnr_inf\n";
			    print LOG "[WARNING] newer versions of varSumm files have MAX_FRQ to be used as pnr_inf, now pALT was used...[$chr:$pos]\n";
			}
			$cov_raw = $info{ 'rawCOV' };
			$cov_inf = $info{ 'infCOV' };
			@alts = split( /$sep_regex/, $alt_string );
		}
		else{ # parse as refiltered_snps (first 8 columns contain general info)
			if ( scalar @fields < 8 ){
			    die "[ERROR] Input does not contain all columns for refiltered_snps or refiltered_indels!!\n";
			}
			($chr, $pos, $ref, $alt_string, $cov_raw, $cov_inf, $pnr_inf) = @fields[0..5,7];
			@alts = split( /$sep_regex/, $alt_string );
			# last columns contain the calls made with count (nr of columns varies)
			$calls = join( "_", @fields[8..$#fields] );
		}
		
		$chr =~  s/chr//; # remove 'chr' from chr if present
		my $chr_nr = $CHR_CONVERSION_FW{ $chr } || $chr; # to allow for sorting numerically X,Y,MT w/o warnings
		
		# init / set variant information
		foreach my $alt ( @alts ){
		    next if ($alt eq $ref); # some formats contain ref in alt string
		    $variant_hash->{ $chr_nr }{ $pos }{ $alt }{ $_ }       = $opt{ undef_char } foreach (@head1,@head2); # init
		    $variant_hash->{ $chr_nr }{ $pos }{ $alt }{ snp_id }   = 'novel';
		    $variant_hash->{ $chr_nr }{ $pos }{ $alt }{ chr }      = $chr;
		    $variant_hash->{ $chr_nr }{ $pos }{ $alt }{ pos }      = $pos;
		    $variant_hash->{ $chr_nr }{ $pos }{ $alt }{ ref }      = $ref;
		    $variant_hash->{ $chr_nr }{ $pos }{ $alt }{ alt }      = $alt;
		    $variant_hash->{ $chr_nr }{ $pos }{ $alt }{ genotype } = $alt;
		    $variant_hash->{ $chr_nr }{ $pos }{ $alt }{ inf_pnr }  = $pnr_inf;
		    $variant_hash->{ $chr_nr }{ $pos }{ $alt }{ raw_cov }  = $cov_raw;
		    $variant_hash->{ $chr_nr }{ $pos }{ $alt }{ inf_cov }  = $cov_inf;
		    $variant_hash->{ $chr_nr }{ $pos }{ $alt }{ calls }    = $calls;
		    $variant_hash->{ $chr_nr }{ $pos }{ $alt }{ is_indel } = isIndel($ref,$alt);
		    $variant_hash->{ $chr_nr }{ $pos }{ $alt }{ extra }     = \@extra;
		}
    }
    close IN;
}

sub parseIonVariants{
    
    my ($file, $variant_hash) = @_;
    print "[INFO] Parsing input file as ION TORRENT table\n";
    
    open IN, $file or die "$!: @_\n";
    while ( <IN> ) {
		chomp;
		next if $_ eq ''; # skip empty lines

		# print all comments (except header and END) to all output
		if ( $_ =~ /^Chrom|#/ ){ 
			next if ( $_ =~ /^Chrom|CHROM|#chr|#CHROM|#END/ );
			my $prefix = '';
			$prefix = '#' if $_ =~ /^#{1}/;
			print SNV1 $prefix.$_."\n";
			print SNV2 $prefix.$_."\n";
			print LOG  $prefix.$_."\n";
			next;
		}

		my @fields = split("\t", $_);
		
		## file columns (COSMIC ids can be missing, is column 14)
		## chr12   25398284        KRAS    AMPL553293      SNP     Het     C       A       35.84   1.00e-10        957     614     343     COSM521;COSM520;COSM522
		if ( scalar @fields < 13 ){
			die "[ERROR] Input seems to have less columns than required [13] for ion torrent table type...?\n";
		}
		
		my ($chr, $pos, $gene, $amplicon, $vartype, $hethom, $ref, $alt, $pnr_inf, $pval, $cov_raw) = @fields;
		my $cov_inf = $cov_raw;
		my $calls = 'NA';
		
		# remove 'chr' from chr if present
		$chr =~  s/chr//; 
		# to allow for sorting numerically X,Y,MT w/o warnings
		my $chr_nr = $CHR_CONVERSION_FW{ $chr } || $chr;
		
		# init / set variant information
		$variant_hash->{ $chr_nr }{ $pos }{ $alt }{ $_ }       = $opt{ undef_char } foreach (@head1,@head2); # init
		$variant_hash->{ $chr_nr }{ $pos }{ $alt }{ snp_id }   = 'novel';
		$variant_hash->{ $chr_nr }{ $pos }{ $alt }{ chr }      = $chr;
		$variant_hash->{ $chr_nr }{ $pos }{ $alt }{ pos }      = $pos;
		$variant_hash->{ $chr_nr }{ $pos }{ $alt }{ ref }      = $ref;
		$variant_hash->{ $chr_nr }{ $pos }{ $alt }{ alt }      = $alt;
		$variant_hash->{ $chr_nr }{ $pos }{ $alt }{ genotype } = $alt;
		$variant_hash->{ $chr_nr }{ $pos }{ $alt }{ inf_pnr }  = $pnr_inf;
		$variant_hash->{ $chr_nr }{ $pos }{ $alt }{ raw_cov }  = $cov_raw;
		$variant_hash->{ $chr_nr }{ $pos }{ $alt }{ inf_cov }  = $cov_inf;
		$variant_hash->{ $chr_nr }{ $pos }{ $alt }{ calls }    = $calls;
		$variant_hash->{ $chr_nr }{ $pos }{ $alt }{ is_indel } = isIndel($ref,$alt);
    }
    close IN;
}

sub parseVCF{
    my ($file, $variant_hash) = @_;
    print "[INFO] Parsing input file as VCF file\n";
    my $vcf = Vcf->new( file => $file );
    $vcf->parse_header();
    
    while (my $next_var = $vcf->next_data_hash()){
		my ($chr, $pos, $ref, $alts, $cov_raw, $cov_inf, $pnr_inf, $calls, $gt) = (0,0,0,0,0,0,0,0,0);
		$chr = $next_var->{ CHROM };
		$pos = $next_var->{ POS };
		$ref = $next_var->{ REF };
		$alts = $next_var->{ ALT };
		
		$cov_raw = $next_var->{ INFO }{ DP } if $next_var->{ INFO }{ DP };
		$cov_inf = $next_var->{ INFO }{ DP } if $next_var->{ INFO }{ DP };
		$cov_raw = $next_var->{gtypes}{Sample}{DP} if $next_var->{gtypes}{Sample}{DP};
		$cov_inf = $next_var->{gtypes}{Sample}{FDP} if $next_var->{gtypes}{Sample}{FDP};
		$gt = $next_var->{gtypes}{Sample}{GT} if $next_var->{gtypes}{Sample}{GT};
		
		$pnr_inf = $next_var->{ INFO }{ AF } if $next_var->{ INFO }{ AF };
		
		# remove 'chr' from chr if present
		$chr =~  s/chr//; 
		# to allow for sorting numerically X,Y,MT w/o warnings
		my $chr_nr = $CHR_CONVERSION_FW{ $chr } || $chr;
	
		foreach my $alt ( @$alts ){
			next if $alt eq $ref;
			$variant_hash->{ $chr_nr }{ $pos }{ $alt }{ $_ }       = $opt{ undef_char } foreach (@head1,@head2); # init
			$variant_hash->{ $chr_nr }{ $pos }{ $alt }{ snp_id }   = 'novel';
			$variant_hash->{ $chr_nr }{ $pos }{ $alt }{ chr }      = $chr;
			$variant_hash->{ $chr_nr }{ $pos }{ $alt }{ pos }      = $pos;
			$variant_hash->{ $chr_nr }{ $pos }{ $alt }{ ref }      = $ref;
			$variant_hash->{ $chr_nr }{ $pos }{ $alt }{ alt }      = $alt;
			$variant_hash->{ $chr_nr }{ $pos }{ $alt }{ genotype } = $gt;
			$variant_hash->{ $chr_nr }{ $pos }{ $alt }{ inf_pnr }  = $pnr_inf;
			$variant_hash->{ $chr_nr }{ $pos }{ $alt }{ raw_cov }  = $cov_raw;
			$variant_hash->{ $chr_nr }{ $pos }{ $alt }{ inf_cov }  = $cov_inf;
			$variant_hash->{ $chr_nr }{ $pos }{ $alt }{ calls }    = $calls;
    		$variant_hash->{ $chr_nr }{ $pos }{ $alt }{ is_indel } = isIndel($ref,$alt);
    	}
    }                                                              
    $vcf->close();
}

# ------------------------------------------------------
# SUBROUTINE: preprocesses snv and runs process_var on it
# Adds/adjusts info for snv processing
# ------------------------------------------------------
sub process_snv{
	my ($var, $chr_slice) = @_; # hash with all variation info
	my @snvs =();

	# set some settings for snv
	$var->{start} = $var->{end} = $var->{pos};
	
	my $reflength = length( $var->{ref} );
	if ( $reflength > 1){ 
	    $var->{end} = $var->{start} + $reflength-1;
	}

	# var could be iupac code, so check and treat as seperate variations
	if ( $var->{alt} =~ /A|T|C|G/ ) { 
		@snvs = ( $var->{alt} ); # only one allele
	}else { 
		@snvs = @{retrieveNucFromIupac( $var )};
	}

	# process snvs one by one 
	foreach my $snv ( @snvs ){
		#next unless $snv; # if iupac check failed, $snv == 0
		$var->{alt} = $snv;
		process_var( $var, $chr_slice );
	}
}

# ------------------------------------------------------
# SUBROUTINE: preprocesses indel and runs process_var on it
# Adds/adjusts info for indel processing
# ------------------------------------------------------
sub process_indel{
	my ($var, $chr_slice) = @_; # hash with all variation info
	my $ref = $var->{ref};
	my $alt = $var->{alt};
	setIndelEnsemblString( $var );
	#setIndelEnsemblString( $var ) unless ( $ref eq '-' or $alt eq '-' );
	removeDotCommaFromIndelCalls( $var );
	process_var( $var, $chr_slice );
}

# ------------------------------------------------------
# SUBROUTINE: this method is called by process_snv and/or process_indel
# It will annotate the variation with various info
# ------------------------------------------------------
sub process_var{
    my ($orig_var, $chr_slice) = @_; # hash with all variation info
    $orig_var->{na_change} = $orig_var->{ref}."/".$orig_var->{alt};
    my $start = $orig_var->{start};
    my $end = $orig_var->{end};

    # make a slice to check for known snps and allele frequency
    # start & end are var->{pos} for a snv and variable for indel
    my $slice;
    if ( $orig_var->{start} > $orig_var->{end} ){
	## in case of an insertion the start is end+1 because this is how ensembl can read it
	## but to retrieve snps etc the slice cant do this 
	$slice = $sa->fetch_by_region( 'chromosome', $orig_var->{chr}, $orig_var->{end}-1, $orig_var->{end} );
    }else{
	$slice = $sa->fetch_by_region( 'chromosome', $orig_var->{chr}, $orig_var->{start}, $orig_var->{end} );
    }

    # add various info to $var hash
    addKnownSnpsAndAlleleFreq( $orig_var, $slice );
    addKaryotypeBand( $orig_var, $slice ) if $opt{'species'};
    addNCBI36coordinate( $orig_var, $slice ) if $opt{'species'} =~ /human|homo_sapiens/i;
    addGerpScores( $orig_var );
    
    # create a new VariationFeature object (always on forward strand, but will return effects for both strands)
    my $vf = Bio::EnsEMBL::Variation::VariationFeature->new(
		-start => $orig_var->{start}, # position relative to start of slice!
		-end => $orig_var->{end},   # position relative to start of slice!
		-slice => $chr_slice,
		-allele_string => $orig_var->{na_change}, # in form "A/T" or "TG/-" or "-/AATC"
		-strand => 1,
		-map_weight => 1,
		-adaptor => $vfa,
    );
    #print "CHANGE $orig_var->{na_change}\n";
    print LOG "[INFO]   infoToEnsembl: START=$orig_var->{start} END=$orig_var->{end} VARIANT=$orig_var->{na_change}\n";
    print "[INFO]   infoToEnsembl: START=$orig_var->{start} END=$orig_var->{end} VARIANT=$orig_var->{na_change}\n";
    
    my $count = scalar @{$vf->get_all_TranscriptVariations};
    #print "....processing var with $count\n";
    # now visit all transcript variations to get their consequences/effects
    #my %selected_variations; # the info per transcript is stored, to be able to skip some    
    foreach my $tv ( @{$vf->get_all_TranscriptVariations} ){
	
		# check if this tv has ANY effects, as a rare undef in ensembl DB caused an error
		my @all_effects = $tv->consequence_type();
		next unless scalar @{$all_effects[0]} > 0;

		# from here we need a CLEAN hash with only shared proporties kept !!
		my %new_var = %{$orig_var};
		my $var = \%new_var; # copy to keep original common values
		$var->{info} = undef; # reset info fields IMPORTANT! references in hash get copied as well..
		$var->{info}{ $_ } = "" foreach @INFO_FIELDS; # init all possible extra-info fields
		
		# get strand and transcript id
		if ( $tv->transcript ){
			addTranscriptInfo( $var, $tv->transcript );
			addProteinInfo( $var, $tv ) if defined $tv->transcript->translation;
			addGeneInfo( $var );
		}
		$var->{effect} = $tv->display_consequence; # only most severe effect
		
		## been trying to get new functions to work but from v69 the transcript variation
		## object seems to be removed / changed so should change complete code
		
		#my $worst = $tv->most_severe_OverlapConsequence();
		#my $hgvs_cod = $tv->hgvs_coding();
		#my $hgvs_gen = $tv->hgvs_genomic();
		#my $eff1 = $tv->display_consequence( );
		#my $eff2 = $tv->display_consequence( 'label' );
		#my $eff3 = $tv->display_consequence( 'SO' );
		#my $eff4 = $tv->display_consequence( 'NCBI' );
		#print "\tEFFECTS:: ".join( ", ", 'WORST:'.$worst, 'HGVS_COD:'.$hgvs_cod, 'HGVS_GEN:'.$hgvs_gen )."\n";
		#print "\tEFFECTS:: ".join( ", ", 'ENS:'.$eff1, 'LABEL:'.$eff2, 'SO:'.$eff3, 'NCBI:'.$eff4 )."\n";

		# now gather additional info by using new v63 object TranscriptVariationAllele
		foreach my $tva (@{$tv->get_all_alternate_TranscriptVariationAlleles}) {
			
			#$var->{effect} = $tv->display_consequence; # only most severe effect
			#$var->{effect} = $tv->most_severe_OverlapConsequence()->display_term; # most severe
			#$var->{effect} = join ",", map {$_->display_term} @{$tva->get_all_OverlapConsequences}; # all effects
			$var->{allele} = $tva->variation_feature_seq if $tva->variation_feature_seq;
			$var->{pepstr} = $tva->pep_allele_string if $tva->pep_allele_string;
			$var->{codon}  = $tva->display_codon_allele_string if $tva->display_codon_allele_string;
			
			# add HGCV info
			my $t_method = 'hgvs_transcript';
			$t_method = 'hgvs_coding' if $opt{ensembl_v} < 67; # method name was changed and deprecated from v68
			$var->{hgvs_t} = $tva->$t_method if defined $tva->$t_method;
			$var->{hgvs_p} = $tva->hgvs_protein if defined $tva->hgvs_protein;
					
			# add polyphen/sift scores
			foreach my $method ( @{$opt{ pred_methods }} ){
				my $pred_meth   = $method.'_prediction';
				my $score_meth  = $method.'_score';
				$var->{ $method.'_s' } = $tva->$score_meth if defined $tva->$score_meth;
				$var->{ $method.'_p' } = $tva->$pred_meth if defined $tva->$pred_meth;
			}
				
			# if present -> get the aa change ( eg M/R or M867R )
			$var->{aa_ref} = $var->{aa_alt} = '-';
			if ( defined $tva->pep_allele_string and $tva->pep_allele_string ne '' ){
				$var->{aa_change} = $tva->pep_allele_string;
				my @aas = split("/",$var->{aa_change}) if $var->{aa_change} =~ /\//;
				$var->{aa_ref} = $aas[0] if defined $aas[0];
				$var->{aa_alt} = $aas[1] if defined $aas[1];
				my $protein_pos = formatCoordinates($tv->translation_start, $tv->translation_end);
				$var->{aa_change} = $var->{aa_ref}.$protein_pos.$var->{aa_alt} if defined $protein_pos;
				addGranthamScore( $var );	
			}
				
			# Skip if strand/gene_id/effect combi was already seen
			# because many transcripts per gene will harbour the same effect
			# This code makes a lot of probably redundant transcript effects being skipped, see *.log
			my $has_substantial_effect = $var->{effect} =~ /$EFFECTS_REGEX/;
			if ( $has_substantial_effect ){ 
			    ## DEBUG
			    #my $ref = $var->{ref};
			    #my $alt = $var->{alt};
			    #my $sta = $var->{start};
			    #my $end = $var->{end};
			    #my $hgvs_t = $var->{hgvs_t};
			    #print "================> In final print: $ref/$alt $sta $end $hgvs_t\n";
			    ## /DEBUG
			    printVarOutput( $var, 'SNV1' ); 
			}
			else{ 
			    printVarOutput( $var, 'SNV2' ); 
			}
		}
    }
}

# ------------------------------------------------------
# SUBROUTINE: print var info on a line to correct output file
# ------------------------------------------------------
sub printVarOutput{
	my ($var, $output_file) = @_;

	my @fields;
	my @info;
	my @extra = ();
	foreach my $column ( @head1 ){ 
		die "[WARN] field seems not to be set [$column]\n" unless defined $var->{ $column};
		push( @fields, $var->{ $column } ); 
	}
	push( @fields, @{$var->{extra}} ) if $var->{extra};
	foreach my $column ( @head2 ){ 
		die "[WARN] field seems not to be set [$column]\n" unless defined $var->{ $column};
		push( @fields, $var->{ $column } ); 
	}
	my $info_string = join ' | ', map { $_.'='.$var->{info}->{$_} } keys %{ $var->{info} || {} };
	@extra = @{$var->{extra}} if ($var->{extra} and $opt{print_extra} );
	print SNV1 join( "\t", @fields, $info_string)."\n" if $output_file eq 'SNV1';
	print SNV2 join( "\t", @fields, $info_string)."\n" if $output_file eq 'SNV2';
}


# ------------------------------------------------------
# SUBROUTINE: disects the iupac code into the right base(s)
# Returns: array with 1 or 2 snv options -> eg ('A','T')
# ------------------------------------------------------
sub retrieveNucFromIupac{
	my $var = shift;
	my $ref = $var->{'ref'};  # reference
	my $snv = $var->{'alt'};  # variation 
	my @out = ();

	# skip if non-existing iupac code, haven't seen this happen yet, but just in case
	if ( !exists $IUPAC{$ref}{$snv} ) {
		printInfoMessage('non_existing_iupac_code', $var);
	}
	# NOTE: if two alleles were sequenced that are both non-reference
	# these are included as two different SNVs (in array)
	elsif ( $IUPAC{$ref}{$snv} =~ /\|/ ) { # if more alleles found of which none is the reference
		printInfoMessage('two_non_ref_alts', $var);
		my ($option1, $option2 ) = split(/\|/, $IUPAC{$ref}{$snv}); 
		push( @out, $option1, $option2 );
	}
	# else just return the 'other' option of iupac code  
	else { 
		push( @out, $IUPAC{$ref}{$snv} );
	}
	return \@out;
}

# ------------------------------------------------------
# SUBROUTINE: determines type of variation_name
# RETURNS: 'insertion' | 'deletion' | 0
# ------------------------------------------------------
sub isIndel{
	my ($ref, $alt) = @_; # eg M or A or +2GT or -1A
	my $type = '';
	
	return( 'insertion' ) if $alt =~ /^\+/;
	return( 'deletion' )  if $alt =~ /^-/;
	return( 'insertion' ) if $ref eq '-';
	return( 'deletion' )  if $alt eq '-';
	return( 'insertion' ) if length($alt) > length($ref);
	return( 'deletion' )  if length($alt) < length($ref);
	
	#print " DEBUG In isIndel: $ref / $alt / $type\n";
	return $type;;
}


# ------------------------------------------------------
# SUBROUTINE: adds known snp info (rs###) and highest frequency population allele info
# RETURNS: nothing
# ------------------------------------------------------
sub addKnownSnpsAndAlleleFreq{
	my ($var, $slice) = @_;
	my @known_snp_ids = ();
	my $frequency  = -1000; # low init
	my $population = 0;

	my $features = $vfa->fetch_all_by_Slice( $slice ); # returns ALL known variations in $slice
	my $somatic_features = $vfa->fetch_all_somatic_by_Slice( $slice ); # returns ALL known variations in $slice

	foreach my $vf ( @{$features}, @{$somatic_features} ){ 

		## check if dbsnp variant contains both ref and our alternative allele (eg A/T/G contains A/G)
		## and get frequency info as well if available
		my @alleles = @{$vf->variation->get_all_Alleles};

		my ($has_ref, $has_alt) = (0,0);
		foreach my $a ( @alleles ){
			
		    next unless defined $a->allele;
		    #print "$var->{ref} / $var->{alt} ==> ".$a->allele."\n";
		    
		    if ( $a->allele eq $var->{ref} ){ # if allele is equal to the ref allele
			$has_ref = 1;
		    }
		    elsif ( $a->allele eq $var->{alt} ){ # if allele is equal to our current variant
			$has_alt = 1;
			if ( defined $a->frequency and $a->frequency > $frequency and defined $a->population ){ ## overwrite stored frequency if new one is higher
			    $frequency = $a->frequency;
			    $population = $a->population->name;
			}
		    }
		    
		}
		#$known = 1 if ($has_ref and $has_alt);
		push(@known_snp_ids, $vf->variation_name) if $has_ref and $has_alt and $vf->variation_name ne '';
	}
	$var->{snp_id} = join(",", @known_snp_ids) if @known_snp_ids > 0;
	$var->{high_freq} = $frequency unless $frequency == -1000;
	$var->{high_popu} = $population if $population;
}


# ------------------------------------------------------
# SUBROUTINE: adds karyotype
# ------------------------------------------------------
sub addKaryotypeBand{
	my ($var, $slice) = @_;
	my $karyo_bands = $slice->get_all_KaryotypeBands;
	$var->{karyo} = $karyo_bands->[0]->name if defined $karyo_bands->[0];
}

# ------------------------------------------------------
# SUBROUTINE: adds coodinate
# ------------------------------------------------------
sub addNCBI36coordinate{
	my ($var, $slice) = @_;
	my @ncbi36_slice = @{ $slice->project('chromosome', 'NCBI36') };
	if ( $ncbi36_slice[0] and ($ncbi36_slice[0] ne 'undef') ){
		my $chr = $ncbi36_slice[0]->to_Slice->seq_region_name;
		my $pos = $ncbi36_slice[0]->to_Slice->start;
		$var->{ncbi36_hg18} = $chr.'_'.$pos;
	}
}

# ------------------------------------------------------
# SUBROUTINE: remove dot/comma in indel calls added by samtools pileup
# ------------------------------------------------------
sub removeDotCommaFromIndelCalls{
	my ($var) = @_;
	my @old_calls = split( '_', $var->{calls} );
	my @new_calls;
	foreach my $call ( @old_calls ){
		if ($call =~ /([\+|-]\d+\w+:\d+)/){
			push( @new_calls, $1);
		}
	}
	$var->{calls} = join( '_', @new_calls );
}


# ------------------------------------------------------
# SUBROUTINE: adds various protein info
# ensembl_prot_id, uniprot_id, refseq_id, $unigene
# ------------------------------------------------------
sub addProteinInfo{ 
	my ($var, $tv) = @_;

	my $trl = $tv->transcript->translation;
	$var->{prot_id} = $trl->display_id() if defined $trl->display_id();

	my $dbs = $trl->get_all_DBEntries;
	next unless $dbs;

	my (%uniprot, %refseq_p, %unigene);
	while ( my $f = shift @{$dbs} ) {
		if ($f->dbname eq 'Uniprot/SWISSPROT'){
			$uniprot{$f->primary_id} = 1;
		}
		elsif ($f->dbname eq 'RefSeq_peptide'){ # RefSeq_peptide_predicted is skipped
			$refseq_p{$f->primary_id} = 1; 
		}
	}
	$var->{info}{UNIPROT}  = join(',', keys %uniprot ) if keys %uniprot > 0;
	$var->{info}{REFSEQ_P} = join(',', keys %refseq_p ) if keys %refseq_p > 0; 
}

# ------------------------------------------------------
# SUBROUTINE: adds transcript name and external info
# ------------------------------------------------------
sub addTranscriptInfo{
	my ($var, $transcript) = @_;

	$var->{tran_id} = $transcript->stable_id if $transcript->stable_id;
	$var->{strand}  = $transcript->strand if $transcript->strand;

	my $xrefs = $transcript->get_all_object_xrefs;
	next unless $xrefs;

	my %db_info;
	foreach my $dblink ( @{$xrefs} ) {
		my ( $id, $desc ) = ('no_id', 'no_desc');
		$id = $dblink->primary_id if $dblink->primary_id;
		$desc = $dblink->description if $dblink->description;
		
		if ( $dblink->{dbname} eq 'RefSeq_mRNA' ){
		    $id = $dblink->display_id;	    
		    $id .= '(identity='.$dblink->{ensembl_identity}.'%/'.$dblink->{xref_identity}.'%)' if $dblink->{ensembl_identity} and $dblink->{xref_identity};
		}
		$db_info{ $dblink->dbname }{ $id } = $desc;
	}
	$var->{ccds_id} = join(',', keys %{$db_info{ CCDS }} ) if $db_info{ CCDS };
	$var->{info}{REFSEQ_T} = join(',', keys %{$db_info{ RefSeq_mRNA }} ) if $db_info{ RefSeq_mRNA };
	
	#print join( " ", keys %db_info )."\n";
	#<>;
	#print STDOUT "LRG FOUND: ".join(',', keys %{$db_info{  }} ) if $db_info{ CCDS };
}

# ------------------------------------------------------
# SUBROUTINE: adds gene_name, gene_id, gene_desc and external info
# ------------------------------------------------------
sub addGeneInfo{ 
	my ($var) = @_;

	my $gene = $ga->fetch_by_transcript_stable_id($var->{tran_id});
	next unless $gene;
	
	#print Dumper( $gene->summary_as_hash() );
	#<>;

	$var->{gene_id} = $gene->stable_id if defined $gene->stable_id;
	$var->{gene_name} = $gene->external_name if defined $gene->external_name;
	$var->{info}{GENE_DESC} = $gene->description if defined $gene->description;
	$var->{biotype} = $gene->biotype if defined $gene->biotype;

	my $xrefs = $gene->get_all_xrefs;
	next unless $xrefs;

	# =============================================================
	# DEBUG code
	#foreach my $dblink ( @{$dblinks} ) {
		#next unless $dblink->dbname eq "MIM_MORBID";
		#while( my($key,$val) = each %{$dblink}){
			##print "$key $val\n" if $key eq "description";
			##print "$key $val\n";
		#}
	#}
	# =============================================================

	# in db_info all external link info (such as OMIM) is stored
	my %xref_info;
	foreach my $xref ( @{$xrefs} ) {
		if ( $xref->primary_id and $xref->description){
		  $xref_info{$xref->dbname}{$xref->primary_id} = $xref->description;
		}
		elsif( $xref->primary_id ){
		  $xref_info{$xref->dbname}{$xref->primary_id} = 'no_desc';
		}
	}
	foreach my $key ( keys %xref_info ){
	    my $val = $xref_info{ $key };
	    if ( $key =~ /LRG/ or $val =~ /LRG/ ){
		#print "DEBUG LRG found: $key $val\n";
		#<>;
	    }
	}
	
	my @mim_descr;
	foreach my $mim_desc ( values %{$xref_info{MIM_MORBID}} ){
		push( @mim_descr, $mim_desc ) if $mim_desc;
	}
	$var->{info}{ MIM_ID }   = join(';', keys %{$xref_info{MIM_MORBID}} ) if $xref_info{MIM_MORBID};
	$var->{info}{ MIM_DESC } = join(';', values %{$xref_info{MIM_MORBID}} ) if $xref_info{MIM_MORBID};
	$var->{info}{ UNIGENE }  = join(';', keys %{$xref_info{UniGene}} ) if $xref_info{UniGene};
	$var->{info}{ GO_IDS }   = join(',', keys %{$xref_info{GO}} ) if $opt{add_go} and $xref_info{GO}; # too much data
	$var->{info}{ GO_TERMS } = join(',', values %{$xref_info{GO}} ) if $opt{add_go} and  $xref_info{GO}; # too much data 
}

# ------------------------------------------------------
# SUBROUTINE: uses variation and position info to reset 
# the indel values for start, end, ref, alt in order
# to make it work for the ensembl api
# ------------------------------------------------------
sub setIndelEnsemblString{ 
    my ( $var ) = @_;
    my $ref = $var->{ref};
    my $alt = $var->{alt};
    my $ref_length = length($ref);
    my $alt_length = length($alt);
    my $type = 'NA';
	
    ## INSERTION/DELETION PIPELINE STYLE: ie +2AT -5TGAAA +1A
    if ($var->{alt} =~ /^(\+|-)(\d+)(\D+)/){
	$type = 'PIPELINE_STYLE';

	if( $1 ne '+' and $1 ne '-' ){ # if unable to detect insertion or deletion
	    printInfoMessage( 'getIndelEnsemblString' );
	}elsif( $1 eq '+'){ # in case of a insertion
	    $var->{ref}   = '-';
	    $var->{alt}   = $3;
	    $var->{start} = $var->{pos}+1;
	    $var->{end}   = $var->{pos};
	}elsif ( $1 eq '-'){ # in case of a deletion
	    $var->{ref}   = $3;
	    $var->{alt}   = '-';
	    $var->{start} = $var->{pos}+1;
	    $var->{end}   = $var->{pos}+$2;      
	}
    }
	
    ## INSERTION ENSEMBL STYLE: ie -/A or -/TTGA
    elsif($var->{ref} eq '-'){ # INSERTION
	$type = 'INSERTION_ENSEMBL_STYLE';
	$var->{start} = $var->{pos}+1; # in ensembl api insertion needs start = end+1
	$var->{end}   = $var->{pos};	    
    }
	
    ## DELETION ENSEMBL STYLE: ie A/- or TTGA/-
    elsif($var->{alt} eq '-'){ #DELETION
	$type = 'DELETION_ENSEMBL_STYLE';
	$var->{start} = $var->{pos};
	$var->{end}   = $var->{pos} + ($ref_length-1);
    }
	
    ## INSERTION VCF STYLE: ie A/ATCG or TTT/TTTA
    elsif( $ref_length < $alt_length ){
	$type = 'INSERTION_VCF_STYLE';
	$var->{start} = $var->{pos};
	$var->{end}   = $var->{pos} + ($alt_length);
	if ( $alt =~ s/^$ref// ){ # reset A/AG to -/G and adjust start+end accordingly
	    $var->{ref} = '-';
	    $var->{alt} = $alt;
	    $var->{start} = $var->{pos}+$ref_length;
	    $var->{end}   = $var->{start}-1;
	}
    }
	
    ## DELETION VCF STYLE: ie ATCG/A or TTTA/TTT
    elsif( $ref_length > $alt_length ){
        $type = 'DELETION_VCF_STYLE';
        $var->{start} = $var->{pos};
        $var->{end}   = $var->{pos} + ($ref_length-1);
        if ( $ref =~ s/^$alt// ){ # reset AG/A to G/- and adjust start+end accordingly
	    $var->{alt} = '-';
	    $var->{ref} = $ref;
	    $var->{start} = $var->{pos}+$alt_length;
	    $var->{end}   = $var->{pos} + ($ref_length-$alt_length);
	}
    }
    else{ # if unable to parse the indel string
    	printInfoMessage( 'getIndelEnsemblString' );
    }
    ## DEBUG
    #print "----> $var->{ref} | $var->{alt} | $type\n";
    #print Dumper( $var );
    ## /DEBUG
}

# ------------------------------------------------------
# SUBROUTINE: adds conservation score to $var hash
# ------------------------------------------------------
sub addGerpScores{
	my ( $var ) = @_;
	my $offset = $opt{gerp_offset};
	my ($gerp, $gerp_region);

	# get block of bases around pos and determine all scores within
	my $slice = $sa->fetch_by_region('toplevel', $var->{chr}, $var->{pos} - $offset, $var->{pos} + $offset);
	my $display_size = $slice->end - $slice->start + 1; # resolution
	my @scores = @{$cs_a->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss, $slice, $display_size)};

	# only if all scores have been found: determine gerp and gerp1 (block of 11 bases)
	if ( scalar @scores == ( 2*$offset +1 ) ){

		$gerp = sprintf("%.3f", $scores[ $offset ]->diff_score) if @scores > 0 and $scores[ $offset ]->diff_score;

		my ($average, $count) = (0,0);
		foreach my $score (@scores) {
			if ( $score->diff_score ){
				$average += $score->diff_score;
				$count++;
			}
		}
		$gerp_region = sprintf("%.3f", ($average / $count)) unless $count == 0;
		$var->{gerp} = $gerp;
		$var->{gerp_region} = $gerp_region;
	}
}

# ------------------------------------------------------
# SUBROUTINE: adds grantham score from GRANTHAM hash
# ------------------------------------------------------
sub addGranthamScore{
	my ($var) = @_;
	my ($aa1, $aa2) = ($var->{aa_ref}, $var->{aa_alt});

	# only lower triangle available in matrix, so use both ways
	if ($GRANTHAM{$aa1}{$aa2}){ $var->{grantham} = $GRANTHAM{$aa1}{$aa2}; }
	elsif ($GRANTHAM{$aa2}{$aa1}){ $var->{grantham} = $GRANTHAM{$aa2}{$aa1}; }
}


# ------------------------------------------------------
# SUBROUTINE: print warning/error/info messaged to screen and LOG
# ------------------------------------------------------
sub printInfoMessage{
	my ($type, $var, $chr, $pos ) = @_;
	my ($cp, $ra); # if all info available, will hold chr:pos and ref:alt

	my $time = substr(scalar(localtime), 11, -5);
	$chr = $var->{chr} if $var;
	$pos = $var->{pos} if $var;
	$cp  = "$chr:$pos";
	$ra  = "$var->{ref}/$var->{alt}" if $var;

	# set default message
	my $msg = "  [WARNING] \$type \"$type\" does not exist in sub printInfoMessage()\n";  

	# set message accoring to type
	if ( $type eq 'analyse' ){ 
		$msg = '[INFO] '.$time." Now analysing: $cp\n"; 
	}
	elsif ( $type eq 'seqadapter' ){ 
		$msg = $time."    [SKIP] chr [ $chr ] ==> REASON: SeqAdapter doesn't know region\n"; 
	}
	elsif ( $type eq 'two_non_ref_alts' ){ 
		$msg = $time."    [INFO] $cp ==> MSG: Two non-reference-alternatives sequenced\n";
	}
	elsif ( $type eq 'non_existing_iupac_code' ){ 
		$msg = $time."    [SKIP] $cp $ra ==> REASON: non_existing_iupac_code\n";
	}
	elsif ( $type eq 'gerp' ){ 
		$msg = $time."    [INFO] $cp $ra ==> MSG: Not all GERP scores found for this position\n";
	}
	elsif ( $type eq 'getIndelEnsemblString' ){ 
		$msg = $time."    [WARNING] unable to detect ins or del, check sub getIndelEnsemblString\n";
	}
	elsif ( $type eq 'redundancy' ){ 
		my $effect =  substr $var->{effect}, 0, 8; 
		$msg = $time."    [SKIP] $cp $ra $effect $var->{aa_change} $var->{tran_id} ==> REASON: redundancy\n"; 
	}
	
	# print message
	print     $msg;
	print LOG $msg;
}


# ------------------------------------------------------
# SUBROUTINE: format coordinates for printing 
# ------------------------------------------------------
sub formatCoordinates {
    my ($start, $end) = @_;
    if( !defined($start)  ) { return '-'; } # if undef
    elsif( !defined($end) ) { return $start; } # if strange :P
    elsif( $start == $end ) { return $start; } # if snv
    elsif( $start > $end  ) { return $end.'-'.$start; } # if deletion
    else                    { return $start.'-'.$end; } # if insertion
}

sub createGranthamScoresHash{
    # grantham scores, predicting amino acid change effect by structural change
    # see http://www.ncbi.nlm.nih.gov/pubmed/4843792
    my %GRANTHAM;
    $GRANTHAM{'A'} = {'A'=>0};
    $GRANTHAM{'R'} = {'A'=>112,'R'=> 0};
    $GRANTHAM{'N'} = {'A'=>111,'R'=> 86,'N'=>  0,};
    $GRANTHAM{'D'} = {'A'=>126,'R'=> 96,'N'=> 23,'D'=>  0,};
    $GRANTHAM{'C'} = {'A'=>195,'R'=>180,'N'=>139,'D'=>154,'C'=>  0,};
    $GRANTHAM{'Q'} = {'A'=> 91,'R'=> 43,'N'=> 46,'D'=> 61,'C'=>154,'Q'=>  0,};
    $GRANTHAM{'E'} = {'A'=>107,'R'=> 54,'N'=> 42,'D'=> 45,'C'=>170,'Q'=> 29,'E'=>  0,};
    $GRANTHAM{'G'} = {'A'=> 60,'R'=>125,'N'=> 80,'D'=> 94,'C'=>159,'Q'=> 87,'E'=> 98,'G'=>  0,};
    $GRANTHAM{'H'} = {'A'=> 86,'R'=> 29,'N'=> 68,'D'=> 81,'C'=>174,'Q'=> 24,'E'=> 40,'G'=> 98,'H'=>  0,};
    $GRANTHAM{'I'} = {'A'=> 94,'R'=> 97,'N'=>149,'D'=>168,'C'=>198,'Q'=>109,'E'=>134,'G'=>135,'H'=> 94,'I'=>  0,};
    $GRANTHAM{'L'} = {'A'=> 96,'R'=>102,'N'=>153,'D'=>172,'C'=>198,'Q'=>113,'E'=>138,'G'=>138,'H'=> 99,'I'=>  5,'L'=>  0,};
    $GRANTHAM{'K'} = {'A'=>106,'R'=> 26,'N'=> 94,'D'=>101,'C'=>202,'Q'=> 53,'E'=> 56,'G'=>127,'H'=> 32,'I'=>102,'L'=>107,'K'=>  0,};
    $GRANTHAM{'M'} = {'A'=> 84,'R'=> 91,'N'=>142,'D'=>160,'C'=>196,'Q'=>101,'E'=>126,'G'=>127,'H'=> 87,'I'=> 10,'L'=> 15,'K'=> 95,'M'=>  0,};
    $GRANTHAM{'F'} = {'A'=>113,'R'=> 97,'N'=>158,'D'=>177,'C'=>205,'Q'=>116,'E'=>140,'G'=>153,'H'=>100,'I'=> 21,'L'=> 22,'K'=>102,'M'=> 28,'F'=>  0,};
    $GRANTHAM{'P'} = {'A'=> 27,'R'=>103,'N'=> 91,'D'=>108,'C'=>169,'Q'=> 76,'E'=> 93,'G'=> 42,'H'=> 77,'I'=> 95,'L'=> 98,'K'=>103,'M'=> 87,'F'=>114,'P'=>  0,};
    $GRANTHAM{'S'} = {'A'=> 99,'R'=>110,'N'=> 46,'D'=> 65,'C'=>112,'Q'=> 68,'E'=> 80,'G'=> 56,'H'=> 89,'I'=>142,'L'=>145,'K'=>121,'M'=>135,'F'=>155,'P'=> 74,'S'=>  0,};
    $GRANTHAM{'T'} = {'A'=> 58,'R'=> 71,'N'=> 65,'D'=> 85,'C'=>149,'Q'=> 42,'E'=> 65,'G'=> 59,'H'=> 47,'I'=> 89,'L'=> 92,'K'=> 78,'M'=> 81,'F'=>103,'P'=> 38,'S'=> 58,'T'=>  0,};
    $GRANTHAM{'W'} = {'A'=>148,'R'=>101,'N'=>174,'D'=>181,'C'=>215,'Q'=>130,'E'=>152,'G'=>184,'H'=>115,'I'=> 61,'L'=> 61,'K'=>110,'M'=> 67,'F'=> 40,'P'=>147,'S'=>177,'T'=>128,'W'=>  0,};
    $GRANTHAM{'Y'} = {'A'=>112,'R'=> 77,'N'=>143,'D'=>160,'C'=>194,'Q'=> 99,'E'=>122,'G'=>147,'H'=> 83,'I'=> 33,'L'=> 36,'K'=> 85,'M'=> 36,'F'=> 22,'P'=>110,'S'=>144,'T'=> 92,'W'=> 37,'Y'=>  0,};
    $GRANTHAM{'V'} = {'A'=> 64,'R'=> 96,'N'=>133,'D'=>152,'C'=>192,'Q'=> 96,'E'=>121,'G'=>109,'H'=> 84,'I'=> 29,'L'=> 32,'K'=> 97,'M'=> 21,'F'=> 50,'P'=> 68,'S'=>124,'T'=> 69,'W'=> 88,'Y'=> 55,'V'=>  0,};
    return( \%GRANTHAM );
}

sub createIupacHash{
    # IUPAC convention: Example: if reference = A & code = M -> new variation = C
    # see http://www.bioinformatics.org/sms2/iupac.html
    my %IUPAC;
    $IUPAC{'A'}{'R'} = 'G';
    $IUPAC{'A'}{'W'} = 'T';
    $IUPAC{'A'}{'M'} = 'C';
    $IUPAC{'A'}{'Y'} = 'C|T';
    $IUPAC{'A'}{'K'} = 'G|T';
    $IUPAC{'A'}{'S'} = 'G|C';
    $IUPAC{'G'}{'R'} = 'A';
    $IUPAC{'G'}{'S'} = 'C';
    $IUPAC{'G'}{'K'} = 'T';
    $IUPAC{'G'}{'Y'} = 'C|T';
    $IUPAC{'G'}{'W'} = 'A|T';
    $IUPAC{'G'}{'M'} = 'A|C';
    $IUPAC{'C'}{'Y'} = 'T';
    $IUPAC{'C'}{'S'} = 'G';
    $IUPAC{'C'}{'M'} = 'A';
    $IUPAC{'C'}{'R'} = 'A|G';
    $IUPAC{'C'}{'W'} = 'A|T';
    $IUPAC{'C'}{'K'} = 'G|T';
    $IUPAC{'T'}{'Y'} = 'C';
    $IUPAC{'T'}{'W'} = 'A';
    $IUPAC{'T'}{'K'} = 'G';
    $IUPAC{'T'}{'R'} = 'A|G';
    $IUPAC{'T'}{'S'} = 'G|C';
    $IUPAC{'T'}{'M'} = 'A|C';
    return( \%IUPAC );
}


# ------------------------------------------------------
# SUBROUTINE: retrieving all adaptors for a certain host if available 
# ------------------------------------------------------
sub getRequiredAdaptors{
    my ($server_path, $user, $sa, $ga, $va, $vfa) = @_;
    my $spc = $opt{ species };
    print "[INFO] Initializing: Trying to find out if host $server_path has correct species [$spc]\n";
	
    eval { 
        $registry->load_registry_from_db( -host => $server_path, -user => $user, -verbose => 0 ); 
        my $has_species = $registry->alias_exists($spc);
        if( $has_species ){
	    print "[INFO] Initializing: ...OK: species available at $server_path\n";
	    print "[INFO] Initializing: Trying to get ensembl adaptors at $server_path\n";
	    $$sa  = $registry->get_adaptor( $spc, 'core', 'slice' );
    	    $$ga  = $registry->get_adaptor( $spc, 'core', 'gene');
    	    $$va  = $registry->get_adaptor( $spc, 'variation', 'variation');
	    $$vfa = $registry->get_adaptor( $spc, 'variation', 'variationfeature');
	}
	else{
	    print "  [getRequiredAdaptors] Species [$spc] seems not installed at $server_path...skip db\n";
	}
    }; warn $@ if $@;
    
    if ( !$@ and $$sa and $$ga and $$va and $$vfa ){ print "[INFO] Initializing: ...OK: all required adaptors loaded for version ".software_version()."\n"; }
    else{ print "  [getRequiredAdaptors] Failed to load all required adaptors\n"; }
}

## Get header from a file
sub getHeaderFromFile{
    my ($file,$head_regex) = @_;
    my @header = ();
    open IN, $file or die "Unable to open file:$!\n";
    while( <IN> ){
	chomp;
	if ( /^$head_regex/ ){
	    @header = split( "\t", $_ );
	}
	last if @header or !/^#/;
    }
    close IN;
    return( \@header);
}


# ------------------------------------------------------
# SUBROUTINE: Printing config to STDOUT
# ------------------------------------------------------
sub printConfigMessage{
	print STDOUT "\n====================\n";
	print STDOUT "  Input file   : $opt{in}\n";
	print STDOUT "  Output SNV1  : $opt{out_snv1}\n";
	print STDOUT "  Output SNV2  : $opt{out_snv2}\n";
	print STDOUT "  Output LOG   : $opt{out_log}\n";
	print STDOUT "  Species      : $opt{species}\n";
	print STDOUT "  Ensembl      : version $opt{ensembl_v}\n";
	print STDOUT "====================\n\n";
}
