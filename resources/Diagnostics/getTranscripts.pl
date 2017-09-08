#!/usr/bin/perl -w
use strict;
use Getopt::Long;
use Data::Dumper;
use File::Basename; # used for retrieving script name (see "fileparse")
use List::Util qw(sum);
use HTTP::Tiny;

#use lib '/data/common_modules/ensembl69/ensembl/modules';
use lib '/data/common_modules/ensembl72/ensembl/modules';
use lib '/data/common_modules/bioperl-live';
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::ApiVersion;
use Bio::EnsEMBL::DBSQL::DBAdaptor;

## when run with option -coding these transcript biotypes are skipped
my $SKIP_REGEX = 'pseudogene|retained_intron|nonsense_mediated_decay|processed_transcript|ambiguous_orf';
my @CHRS = qw( 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 X Y M MT Mt mt x y );

my %opt = (
  'help'          => undef, 
  'name'          => undef,
  'genes'         => undef,
  'probes'        => undef,   
  'species'       => 'Homo_sapiens',
  'loc_serv'      => '',
  'web_serv'      => 'ensembldb.ensembl.org',
  'default_xref'  => [ 'CCDS' ], # used for filter option
  'extra_xref'    => [], # used for filter option
  'flank'         => 0,
  'verbose'       => undef,
  'probe_lim'     => 0.5,
  'no_local'      => undef,
  'auto_filter'   => undef,
  'coding_only'   => undef,
  'longest_only'  => undef,
  'canonical_only'=> undef,
  'coding_genes_only'=>undef,
);

my $xref_fields = join(',', @{$opt{'default_xref'}});
my $usage = <<END;

  For a list of gene-ids, gene-names, transcript-ids, refseq-ids:
    - gets gene from ensembl (if able to retrieve by input)
    - visits all transcripts from the gene
    - filters transcripts if requested (eg -auto_filter or -canonical)
    - prints information about exons/transcripts

  Example usage:
    all transcripts    : -o <OUTNAME> -genes <GENE_LIST>
    only canonical tx  : -o <OUTNAME> -genes <GENE_LIST> -canonical
    sensible selection : -o <OUTNAME> -genes <GENE_LIST> -auto_filter
    sensible longest   : -o <OUTNAME> -genes <GENE_LIST> -auto_filter -longest
        
   Required params:
     -out_base|o     basename of the output files (and name of the design)
     -genes          file with ids/names (see below for example input)
    
   Optional params:
     -auto_filter|f only select (if present) with these fields present: $xref_fields 
                    NOTE: if no "well annotated" ->  all transcripts are selected
     -canonical|c   only select ensembl canonical transcript for each gene
                    NOTE: BY FAR THE FASTEST OPTION
     -coding_tran   only include transcripts where biotype does NOT contain any of:
                    $SKIP_REGEX
     -coding_gene   skip genes where biotype is not "protein_coding"
     -longest       only output longest transcript (cds length is used when possible)
     
     Untested:
       -probes      design file with probe coordinates 
       -add_xref    add xref field (eg RefSeq_mRNA, see ensembl docs) for the auto_filter
                    NOTE: transcripts with field occupied are added to output
               
     Debug options:
       -verbose     load ensembl registry with verbose = 1
       -no_local    do not try local ensembl, go to web directly
     
   Notes:
     - for coding exons the start and end are replaced 
       by coding start and coding end.
     - only human supported for now (due to hardcoded 
       chromosome restrictions)
     - works with v69
     - works with v72
     - works with v71 but then misses the refseq identity 
       scores due to ensembl bug 
     - Tries to connect to local server first [$opt{ loc_serv }].
     - when input gene names occurs multiple times in the
       ensembl DB all are printed
  
   ------------------------------------
   Example input file:
   ------------------------------------
     # commented lines are ignored
     BRCA2
     NM_12345678.2=BRCA2
     ENST00000001
     EMSG00000001

END


# ======================================================
# Options / init
# ======================================================
die $usage if @ARGV == 0;
GetOptions (
  'h|help'        => \$opt{help},
  'out_base|o=s'  => \$opt{out_base},
  #'species|s=s'   => \$opt{species},
  'genes=s@'      => \$opt{genes},
  'probes=s'      => \$opt{probes},
  'verbose'       => \$opt{verbose},
  'no_local'      => \$opt{no_local},
  'coding_tran'   => \$opt{coding_only},
  #'flank=i'       => \$opt{flank},
  'longest'       => \$opt{longest_only},
  'auto_filter|f' => \$opt{auto_filter},
  'canonical|c'   => \$opt{canonical_only},
  'add_xref=s@'   => \$opt{extra_xref},
  'coding_gene'   => \$opt{coding_genes_only},
) 
or die $usage;
die $usage if $opt{help};
die "[ERROR] Missing input: pls provide output base (-o)\n" unless $opt{ out_base };
die "[ERROR] Missing input: pls provide genes (-genes)\n" unless $opt{ genes };
die "[ERROR] Use auto_filter (-f) OR canonical (-c) but not both\n" if ( $opt{auto_filter} and $opt{canonical_only} );


my $registry = 'Bio::EnsEMBL::Registry';
## create slice-adaptor and gene-adaptor
my ( $sa, $ga, $ga_of, $dbentry_a ); # of = otherfeatures (is needed for refseq ids NM_ input, so use no_local)

## first try local db
loadEnsemblAdaptors( $opt{loc_serv}, 'ensembl', $registry, \$sa, \$ga, \$ga_of, \$dbentry_a ) unless $opt{ no_local };
## if local failed, try online
#loadEnsemblAdaptors( $opt{web_serv}, 'anonymous', $registry, \$sa, \$ga, \$ga_of ) unless $sa and $ga and $ga_of;
loadEnsemblAdaptors( $opt{web_serv}, 'anonymous', $registry, \$sa, \$ga, \$ga_of, \$dbentry_a ) unless $sa and $ga;
## only continue if adaptor loaded
#die "[ERROR] (some) ensembl adaptors not loaded...\n" unless $sa and $ga and $ga_of;
die "[ERROR] (some) ensembl adaptors not loaded...\n" unless $sa and $ga;

# ======================================================
## start analysis
# ======================================================
my %ids_to_include = (); # keys will be gene-ids and/or gene-names
my %probe_coverage = (); # keys will be chr->pos, values probe-coverage
my @id_array = ();

my $out_unq = $opt{out_base}.'.exoncovExonsUnique.bed';
my $out_red = $opt{out_base}.'.exoncovExonsMulti.bed';
my $out_tra = $opt{out_base}.'.exoncovTranscripts';
my $out_log = $opt{out_base}.'.exoncovLog';
open my $fh_unq, ">$out_unq" or die "$!: @_\n"; # this will contain the uniq exons in bed file
open my $fh_red, ">$out_red" or die "$!: @_\n"; # this will contain all exons with their transcript (so might contain double ones)
open my $fh_tra, ">$out_tra" or die "$!: @_\n"; # this will contain transcript annotations
open my $fh_log, ">$out_log" or die "$!: @_\n"; # just a log

printMsg( 'i', "...OK adaptors loaded (ensembl_version: ".software_version().")", *STDOUT, $fh_log );

my $genes_in  = 'INPUT_GENES_FILE='.join(',', @{$opt{ genes }} );
my $script_n  = 'SCRIPT_NAME='.(fileparse($0))[0];
my $ensembl_v = 'ENSEMBL_VERSION='.software_version();
my $host_n    = 'HOST='.$sa->dbc->host;
my $species_s = 'SPECIES='.$opt{species};
my $design_n  = 'DESIGN_NAME='.$opt{ out_base };
my $settings  = '##ANNOTATOR_SETTINGS: '.join(';', $script_n, $host_n, $ensembl_v, $species_s, $genes_in )."\n";
#my @comment_lines = ($design_n, $script_n, $ensembl_v, $host_n, $species_s, $genes_in );
my @comment_lines = ($design_n, $script_n, $ensembl_v, $host_n, $genes_in );

foreach ( qw( species coding_only flank longest_only auto_filter canonical_only default_xref extra_xref ) ){
    die "[ERROR] Missing a param in opt hash ($_)...\n" unless exists( $opt{ $_ } );
    my $final = 'off';
    if ( defined $opt{$_} ){
	my $value = $opt{$_};
	$value = join(',',@{$opt{$_}}) if ( ref($opt{$_}) eq 'ARRAY' ); # some options are an array
	$final = $value if ($value ne '' );
    }
    push( @comment_lines, join( '=', uc($_), $final) );
}

foreach ( $fh_unq, $fh_red, $fh_tra, $fh_log ){
    print $_ join( "\n", map( '## '.$_, @comment_lines) )."\n";
}

## load genes to include exons from
foreach my $f ( @{$opt{genes}} ){
    printMsg( 'i', "Reading input gene list [$f]...", *STDOUT );
    parseGeneFile( \%ids_to_include, $f, \@id_array );
}
## load probe coordinates if given
if ( $opt{probes} ){
    printMsg( 'i', "Reading probe file [$opt{probes}]...", *STDOUT );
    parseProbeFile( \%probe_coverage, $opt{probes} );
}
## start exon retrieval for included gene-ids

printMsg( 'i', "Start exon retrieval...", *STDOUT );
retrieveExons( \%ids_to_include, \%probe_coverage, \@id_array, $SKIP_REGEX );

close $fh_unq;
close $fh_red;
close $fh_tra;
close $fh_log;
printMsg( 'i', "DONE", *STDOUT );



# ======================================================
## SUBROUTINES
# ======================================================
sub retrieveExons{
    my ($ids, $probe, $input_list, $skip_type_regex) = @_;
    
    my %seen_gene_ids = ();
    my %genes_with_probe = ();
    my %seen_exons = ();
    my %failed = ();
    my %tran_skipped = ();
    my $total = scalar keys %$ids;
    
    my $script_v = 'SCRIPT:'.(fileparse($0))[0];
    
    my @header_unq = qw( chr start end exon_id gene_id gene_name probe_av );
    my @header_red = qw( chr start end exon_id gene_id gene_name probe_av strand tran_id ccds_id);
    my @header_tra = qw( gene transcript strand ens_gene_id ens_tran_id is_canonical t_length p_length t_biotype ccds_id refseq_id chr cdna_start cdna_end cds_start cds_end exon_count exon_starts exon_ends exon_names gene_synonyms);
        
    print $fh_unq '#'.join("\t", @header_unq)."\n";
    print $fh_red '#'.join("\t", @header_red)."\n";
    print $fh_tra '#'.join("\t", @header_tra)."\n";
    
    my $counter = 0;
    foreach my $object_ids ( @$input_list ){
	$counter++;
	my @genes;
	my $working_id;
	my $g_nm = 'NA';
	
	
	## fetch gene from input ids array
	my $gene_objects; 
	foreach my $in_id ( @$object_ids ){ # multiple ids for same gene can be inputted on same line in case one fails
	    last if defined $gene_objects; # a gene has succesfully been retrieved by previous id on same line
	    $working_id = $in_id;
	    print "[INFO] SEARCHING with search-id: $in_id ($counter of $total)\n";
	    if ( $in_id =~ /^(NM_\d+\.\d+)=(.+)/ ){
		$gene_objects = fetchGene( $1 );
		$g_nm = $2;
		$working_id = $1;
	    }
	    elsif( $in_id =~ /NM_\d+/ ){
		die "[WARNING] searching by NM_ (\"$in_id\") should be like NM_###.2=<GENE>, see help...\n";
	    }
	    else{
		$gene_objects = fetchGene( $in_id );
	    }
	}
	
	## check if at least one gene object has been retrieved for input id(s)
	unless( scalar(@$gene_objects) ){
	    my $failed_ids = join(",",@$object_ids);
	    printMsg( 'w', "Input [$failed_ids] not found, so not included...", *STDOUT, $fh_log );
	    $failed{ id_absent_in_db }{ $failed_ids } = 1;
	    next;
	}
	
	## remove non protein_coding is requested
	my @final_genes = ();
	foreach ( @$gene_objects ){
	    my $gene_biotype = $_->biotype();
	    next if ( $opt{ coding_genes_only } and ($gene_biotype ne 'protein_coding') );
	    push( @final_genes, $_ );
	}
	my $failed_ids = join(",",@$object_ids);
	if( scalar(@final_genes) < 1 ){
	    printMsg( 'w', "Input [$failed_ids] found but no protein_coding, so not included...", *STDOUT, $fh_log );
	    $failed{ no_protein_coding }{ $failed_ids } = 1;
	    next;
	}elsif( scalar(@final_genes) > 1 ){
	    printMsg( 'w', "Input [$failed_ids] had multiple ensembl gene hits, all are included...", *STDOUT, $fh_log );
	}
	
	foreach my $gene ( @$gene_objects ){
	    
	    my ($g_id, $chr) = qw( NA NA );
	    $g_id = $gene->stable_id if $gene;
	    $g_id = $gene->stable_id if $gene;
	    $g_nm = $gene->external_name if $gene->external_name;
	    $chr  = $gene->seq_region_name if $gene;
	    
	    ## fetch synonyms
	    my $synonym_string = getGeneSynonyms( $gene );
	    
	    if ( $seen_gene_ids{ $g_id } and $working_id !~ /^ENST|NM_/ ){; # only skip gene if working per gene
		printMsg( 'i', "...SKIPPING GENE:$g_nm ($counter of $total) is done already [$seen_gene_ids{ $g_id }]", *STDOUT );
		next;
	    }
	    $seen_gene_ids{ $g_id } = $g_nm;
		    
	    ## TRANSCRIPTS 
	    ## ==============================================
	    my $exon_printed = 0; # this variable is to keep track of (un)succesfull genes
	    
	    my @transcripts = ();
	    @transcripts = @{$gene->get_all_Transcripts};
	    my $trans_count = scalar( @transcripts );
	    
	    ## if not searching by exact transcript -> check filters
	    unless ( $working_id =~ /^(ENST|NM_|NR_)/ ){
	    
		## reduce transcript list to canonical only if requested
		if ( $opt{ canonical_only } ){
		    @transcripts = ($gene->canonical_transcript);
		}
		
		## reduce transcript list to certain coding by regex
		if ($opt{coding_only}){
		    my @selected_transcripts = ();   
		    removeNonCodingTranscripts( \@transcripts, \@selected_transcripts, $SKIP_REGEX );
		    @transcripts = @selected_transcripts;
		    if ( scalar(@selected_transcripts) == 0 ){
			printMsg( 'w', "No more transcripts for gene ($g_nm) after coding-filter", *STDOUT, $fh_log);
		    }
		}
		
		## reduce transcript list to one if longest requested
		if ($opt{longest_only}){
		    @transcripts = getLongestTranscript( \@transcripts );
		    my $is_canonical = $transcripts[0]->is_canonical();
		    print "[INFO] .....reduced to longest transcript\n";
		    print "[INFO] ........which is NOT CAMONICAL!\n" unless $is_canonical;
		}
		
		## reduce transcripts to XREF containing (CCDS etc)
		if ( $opt{ auto_filter } ){ # will not be used with canonical option at same time
		    my $has_xref = 0;
		    my @selected_transcripts = ();   
		    my @xref_check = ( @{$opt{ default_xref }}, @{$opt{ extra_xref }} ); # CCDS etc
		
		    foreach my $transcript ( @transcripts ){
			$has_xref += hasXref( $transcript, \@xref_check, \@selected_transcripts, $skip_type_regex );
		    }
		    if ( $has_xref ){ # if true at least one transcript had one of the xrefs and all these are selected
			@transcripts = @selected_transcripts;
		    }else{
			if ( $gene->canonical_transcript() ){
			    my $canonical_t = $gene->canonical_transcript();
			    @transcripts = ($canonical_t);
			}
		    }
		    print "[INFO] .....reduced to ".scalar(@transcripts)." transcript(s) by the auto_filter\n";
		}
		## end of transcript filters
	    }
	    
	    my $trans_count_final = scalar( @transcripts );
	    
	    
	    my $trans_count_print = 0;	    
	    foreach my $transcript ( @transcripts ){
		#my $t_id = $transcript->display_id;
		my $t_id = $transcript->stable_id;
		
		## if input was transcript -> make sure only this transcript is in output
		next if ( $working_id =~ /^ENST|NM_/ and ($working_id ne $t_id) );
		
		## for ensembl transcript ids the version must be added
		my $t_version = $transcript->version;
		my $t_id_version = $t_id;
		$t_id_version .= '.'.$t_version if (defined($t_version) and ($t_id !~ /\./));
		
		my $biotype = $transcript->biotype;
		my $xrefs = $transcript->get_all_xrefs;
		my @exons = @{$transcript->get_all_Exons};
		my $exon_count = scalar @exons;
		
		my @xref_fields = ("CCDS", "RefSeq_mRNA");
		my ($ccds, $refseq ) = getXrefInfoStrings( $transcript, \@xref_fields );
		
		## EXONS ==============================================
		
		my %exon_coor = ();
		foreach my $exon ( @exons ){
		    my ($start_change, $end_change) = (0,0);
		    
		    my $e_id     = $exon->stable_id || 'NA';
		    my $start    = $exon->start;
		    my $end      = $exon->end;
		    my $strand   = $exon->strand || 'NA';
		    my $coding_s = $exon->coding_region_start($transcript);
		    my $coding_e = $exon->coding_region_end($transcript);
		    $strand =~ s/-1/RV/;
		    $strand =~ s/1/FW/;
		    
		    ## DEBUG CODE
		    #if ( 1 ){
		    #if ( 0 and $e_id eq 'ENSE00001952634'){
			#print join( " ", 'ID:'.$e_id, 'S:'.$start, 'E:'.$end, 'STR:'.$strand, 'COD_S:'.$coding_s, 'COD_E:'.$coding_e)."\n";
			#<>;
		    #}
		    
		    ## in case of coding gene -> only continue with exon if coding region
		    next if ( !$coding_s and !$coding_e and ($gene->biotype eq 'protein_coding') );
		    
		    ## check if not whole exon is coding and shrink to coding if not
		    if ( $coding_s and $start < $coding_s ){ $start_change = $coding_s - $start; $start = $coding_s; }
		    if ( $coding_e and $end > $coding_e   ){ $end_change = $end - $coding_e; $end = $coding_e;  }
		    
		    ## exon ok, push to array
		    $exon_coor{ $start } = $end;
		    
		    ## determine uniq exon for later skipping
		    my $uniq = $e_id.$start.$end;
				    
		    #next unless $chr =~ /^(\d{1,2}|X|Y|MT|Mt)$/; 
	
		    # get probe average
		    my @covs = ();
		    foreach ( $start..$end ){
			my $val = 0;
			$val = $probe->{ $chr }{ $_ } if $probe->{ $chr }{ $_ };
			push( @covs, $val);
		    }
		    my $probe_av = arrayMean( \@covs );
		    
		    # if this particular genomic region has not been seen before: print its properties
		    my $non_coding_length = $start_change+$end_change;
		    my @out = ( $chr, $start - $opt{'flank'}, $end + $opt{'flank'}, $e_id );
		    
		    print $fh_unq join("\t", @out, $g_id, $g_nm, $probe_av )."\n" unless ( $seen_exons{ $uniq } );
		    print $fh_red join("\t", @out, $g_id, $g_nm, $probe_av, $strand, $t_id, $ccds, $refseq)."\n"; 
		    
		    # set to seen
		    $exon_printed = 1;
		    $seen_exons{ $uniq } = 1;
		    $genes_with_probe{ $g_nm } = 1 if $probe_av > $opt{ probe_lim };
		}
		## gather other transcript info
		
		my $NA_CHAR = 'NA';
		my ($na_leng, $aa_leng) = ($NA_CHAR, $NA_CHAR);
		$na_leng = $transcript->length() if $transcript->length();
		if ( $transcript->translate ){
		    $aa_leng = $transcript->translate->length() if $transcript->translate->length();
		}
		my $cds_sta = $transcript->coding_region_start() || $NA_CHAR;
		my $cds_end = $transcript->coding_region_end() || $NA_CHAR;
		
		my $is_canonical = $transcript->is_canonical;
		my $t_sta = $transcript->start() || $NA_CHAR;
		my $t_end = $transcript->end() || $NA_CHAR;
		my $strand = $transcript->strand() || $NA_CHAR;
		$biotype = $transcript->biotype() || $NA_CHAR;
		$strand =~ s/-1/RV/;
		$strand =~ s/1/FW/;
		
		my @starts = ();
		my @ends = ();
		foreach my $start ( sort {$a <=> $b} keys %exon_coor ){
		    push @starts, $start;
		    push @ends, $exon_coor{ $start };
		}
		my $starts = join( ",", @starts) || $NA_CHAR;
		my $ends = join( ",", @ends) || $NA_CHAR;
		my @names = (1..scalar(@starts));
		@names = reverse(@names) if $strand =~ /RV|\-/;
		my $names = join( ",", @names) || $NA_CHAR;
		my $count = scalar(@starts) || $NA_CHAR;
		
		# chr gene transcript strand ens_gene_id ens_tran_id ccds_id refseq_id cdna_start cdna_end cds_start cds_end exon_count exon_starts exon_ends exon_names
		my @out = ( $g_nm, $t_id, $strand, $g_id, $t_id_version, $is_canonical, $na_leng, $aa_leng, $biotype, $ccds, $refseq, $chr );
		push( @out, $t_sta, $t_end, $cds_sta, $cds_end, $count, $starts, $ends, $names, $synonym_string );
		print $fh_tra join( "\t", @out)."\n";
		#$print_tx_index++;
		$trans_count_print++;
	    }
	    
	    printMsg( 'i', ".....transcripts in gene visited=$trans_count, selected=$trans_count_final, output=$trans_count_print", *STDOUT );
	    ## check if we have data for gene and store reason if not
	    unless ( $exon_printed ){
		$failed{ no_exon_printed }{ $working_id } = 1;
		printMsg( 'w', "no exon printed for $working_id!", *STDOUT, $fh_log );
	    }
	}
	## end of one ensembl gene
    }
    print $fh_unq "#END\n";
    print $fh_red "#END\n";
    my $total_failed = 0;
    if ( scalar keys %failed == 0 ){
	printMsg( 'i', 'OK: All input ids/names are included in output!', *STDOUT, $fh_log );
    }
    else{
	foreach my $reason ( keys %failed ){
	    my $count = scalar keys %{$failed{ $reason }};
	    printMsg( 'w', "FAILED IDS for reason $reason ($count): ".join( " ", keys %{$failed{ $reason }} ), *STDOUT, $fh_log );
	}
    }
    
    my @no_probe = ();
    my %seen_gene_names = reverse %seen_gene_ids;
    foreach my $seen_gene ( keys %seen_gene_names ){
	push @no_probe, $seen_gene unless $genes_with_probe{ $seen_gene };
    }
    if ( scalar @no_probe and $opt{probes} ){
	my $probe_lim = $opt{probe_lim};
	print "[WARN] There are genes with too low probe coverage [limit = $probe_lim] foreach exon:\n";
	print "[WARN]   ".join( ", ", @no_probe)."\n";
    }
    
    if ( scalar keys %tran_skipped ){
	print "[WARN] Transcripts skipped per biotype:\n";
	print "[WARN]   $_: $tran_skipped{ $_ }\n" foreach keys %tran_skipped;
    }
    
    printMsg( 'i', '------------------', *STDOUT );
    printMsg( 'i', "Output files:", *STDOUT );
    printMsg( 'i', '------------------', *STDOUT );
    printMsg( 'i', " $out_unq", *STDOUT ); 
    printMsg( 'i', " $out_red", *STDOUT );
    printMsg( 'i', " $out_tra", *STDOUT );
    printMsg( 'i', " $out_log", *STDOUT );
}

sub hasXref{
    my ($t, $xref_fields, $selected_t, $skip_biotype_regex) = @_;
    my $t_xrefs = $t->get_all_xrefs();
    my $t_biotype = $t->biotype();
    my $t_id = $t->stable_id();
    return(0) unless $t_xrefs;
	    
    foreach my $xref ( @{$t_xrefs} ) {
	
	foreach my $xref_field ( @$xref_fields ){		    
	    next unless $xref->{dbname} eq $xref_field;
	    next unless $xref->primary_id;    
	    
	    ## skip transcript with certain biotype if coding filter is set
	    ## this is done here so we can undo if final result has no transcripts
	    if ( $t_biotype =~ /$SKIP_REGEX/ ){
		printMsg( 'i', "SKIPPED BY BIOTYPE transcript [$t_id] biotype: $t_biotype", *STDOUT);
		next;
	    }
	    push( @$selected_t, $t );
	    return(1);
	}
    }
    return(0);
}

sub getXrefInfoStrings{
    my ($t, $xref_fields) = @_;
    my %out = ();
    
    my @out = ();

    #my $xrefs = $t->get_all_xrefs();
    my $xrefs = $t->get_all_object_xrefs();
    return( map( 'NA', @$xref_fields) ) unless $xrefs;
        
    foreach my $xref_field ( @$xref_fields ){
	my $out = 'NA';
	foreach my $xref ( @{$xrefs} ) {
	    next unless $xref->{dbname} eq $xref_field;
	    next unless $xref->display_id;
	    my $tmp_out = $xref->display_id;
	    
	    ## retrieve identity scores if refseq
	    if ( $xref_field eq 'RefSeq_mRNA' ){
		my ($e_id,$x_id) = ('NA','NA');
		if ( $xref->{ ensembl_identity } ){
		    $e_id = $xref->{ ensembl_identity }.'%';
		}
		if ( $xref->{ xref_identity } ){
		    $x_id = $xref->{ xref_identity }.'%';
		}
		$tmp_out .= "($e_id/$x_id)";
	    }
	    push( @{$out{$xref_field}}, $tmp_out);
	    
	}
	if ( defined $out{$xref_field} ){
	    $out = join(',', @{$out{$xref_field}} ) if (scalar(@{$out{$xref_field}}));
	}
	push( @out, $out );
    }
    return( @out ); ## nr of items in @out same as nr in input @$xref_fields
}

sub getLongestTranscript{
    my ($transcripts) = @_;
    my $longest_tran;
    my $has_protein = 0;
    my $cur_length = 0;
    my $cur_aa_length = 0;
    
    foreach my $t ( @$transcripts ){
	my $length = $t->length(); # ensembl docs say this is the sum of all exons
	my $stable_id = $t->stable_id;
	#my $is_canonical = $t->is_canonical;
	if ($t->translate() ){
	    my $aa_length = $t->translate->length();
	    if ( $aa_length > $cur_aa_length ){
		$longest_tran = $t;
		$cur_aa_length = $aa_length;
	    } 
	    $has_protein = 1;       
	}
	elsif ( $length > $cur_length and not $has_protein ){
	    $longest_tran = $t;
	    $cur_length = $length;
	}
    }
    $longest_tran = $transcripts->[0] if (not defined $longest_tran);
    return ($longest_tran);
}

sub removeNonCodingTranscripts{
    my ($transcripts, $selected, $regex) = @_;
    foreach my $t ( @$transcripts ){
	my $biotype = $t->biotype();
	my $stable_id = $t->stable_id;
	unless ( $biotype =~ /$regex/ ){ # probably $SKIP_REGEX
	    push( @$selected, $t );
	}
    }
}

sub fetchGene{
    my ($gene_id_name) = @_;
    my @genes = ();
    
    if ( $gene_id_name =~ /^ENS(G|T)/ ){ # only one if id is known
	my $gene;
	if ( $gene_id_name =~ /^ENSG/ ){ # only one if id is known
	    $gene = $ga->fetch_by_stable_id( $gene_id_name )
    	    #push( @genes, $ga->fetch_by_stable_id( $gene_id_name ) );
    	}else{
	    $gene = $ga->fetch_by_transcript_stable_id( $gene_id_name )
    	    #push( @genes, $ga->fetch_by_transcript_stable_id( $gene_id_name ) );
    	}
        if (defined $gene){
    	    my $coor_sys = $gene->coord_system_name();
    	    my $chr_name = $gene->seq_region_name();
    	    ## unless correct location -> return no gene
    	    unless ( ($coor_sys eq "chromosome") and (grep { $CHRS[$_] eq $chr_name } 0..$#CHRS) ){    			
    		print "[WARN] Unable to find gene with input ($gene_id_name)\n";
    		return(undef);
    	    }
    	    push( @genes, $gene );
    	}
    }
    elsif( $gene_id_name =~ /^(NM_\d+\.)(\d)+/ ){
	my $nm = $1;
	my $version = $2;
	## get from other features gene set
	push( @genes, $ga_of->fetch_by_transcript_stable_id( $gene_id_name ) );
	## if this particular version failed, try 1 down or up
	unless ( scalar(@genes) ){
	    my $version_plus = $nm . ($version + 1);
	    print "[INFO] ...retry to find NM transcript with higher version ($version_plus)\n";
	    
	    push( @genes, $ga_of->fetch_by_transcript_stable_id( $version_plus ) );
	    print $fh_log "[INFO] Found  NM transcript with higher version ($version_plus)\n" if scalar(@genes);
	}
    }
    else{ # by name multiple might popup, choose fitting one
	my @unfiltered_genes = @{$ga->fetch_all_by_external_name( $gene_id_name )};
        foreach my $g ( @unfiltered_genes ){
    	    
    	    my $ext_name = $g->external_name();	    
    	    next unless $ext_name eq $gene_id_name;
    	    
    	    my $coor_sys = $g->coord_system_name();
    	    next unless $coor_sys eq "chromosome";
	    
	    my $stable_id = $g->stable_id();
    	    next unless $stable_id =~ /^ENSG/;
    	    
    	    my $chr_name = $g->seq_region_name();
    	    next unless grep { $CHRS[$_] eq $chr_name } 0..$#CHRS;

    	    ## debug code
    	    #print join( " ", "-----", $ext_name, $coor_sys)."\n";
    	    
    	    push( @genes, $g );
    	}
    }
    return( \@genes ); # when searching with gene-name (eg "CFB") there can be multiple ensembl genes with same name
}

sub printMsg{
    my ($type, $msg, @fhs) = @_;
    my $pre = '';
    if   ( $type eq 'w' ){ $pre = "[---WARNING---] "; }
    elsif( $type eq 'e' ){ $pre = "[----ERROR----] "; }
    elsif( $type eq 'i' ){ $pre = "[INFO] "; }
    else{ die "[printMsg] wrong type input\n"; }
    foreach ( @fhs ){
	print $_ $pre.$msg."\n";
    }
}

sub printHashInfo{
    my ($hash, $title) = @_;
    warn "--- $title ---\n";
    while ( my ($key,$val) = each( %{$hash} ) ){
	warn join("\t", $key, $val)."\n";
    }
}

sub parseGeneFile{
    my ( $info_hash, $file, $id_array ) = @_;
    my $too_many_msg = 0;

    open IN, $file or die " Cannot open file [ $file ] $!\n";
    while (<IN>) {
	next if /^#/;
	chomp;
	my @strings = split( "\t", $_ );
	
	map ( $_ =~ s/ $//, @strings ); # remove possible whitespace at end
	push @$id_array, \@strings;
	
	foreach ( @strings ){
	    die "[---ERROR---] input in genes file ($_) contains whitespace?\n" if $_ =~ /\s/;
	    die "[---ERROR---] input in genes file ($_) contains comma?\n" if $_ =~ /\,/;
	    die "[---ERROR---] input in genes file ($_) looks more like a region?\n" if $_ =~ /(chr)?.+:\d+\-\d+/;
	    if ( $_ =~ /NM_/ ){
		die "[---ERROR---] input in genes file ($_) refseq should be like (eg NM_123.1=<GENE_NAME>)\n" unless $_ =~ /^NM_\d+\.\d+=.+/;
	    }
	}
	
	if ( scalar @strings == 1 ){
	    my $id_one = $strings[0];
	    $id_one =~ s/ //; # remove possible whitespace 
	    $info_hash->{ $id_one } = 1;
	}
	elsif( scalar @strings > 1 ){
	    my $id_one = $strings[0];
	    my $id_two = $strings[1];
	    $id_one =~ s/ //; # remove possible whitespace 
	    $id_two =~ s/ //; # remove possible whitespace 
	    $info_hash->{ $id_one } = $id_two;
	    if ( scalar @strings > 2 and !$too_many_msg){
		print "[WARN] more than 2 gene identifiers not supported, only first 2 used (this msg is printed only once)\n";
		$too_many_msg = 1;
	    }
	}
    }
    close IN;
}

sub getGeneSynonyms{
    my ($gene) = @_;
    my $dbes = $gene->get_all_DBEntries('HGNC');
    foreach my $dbe ( @{$dbes} ) {
        if ( $dbe->dbname() eq 'HGNC' ){
	    return( join(',', @{$dbe->get_all_synonyms}) ) if scalar( @{$dbe->get_all_synonyms} );
        }
    }
    return( '.' );
}

sub parseProbeFile{
    my ( $info_hash, $file) = @_;
 
    open IN, $file or die " Cannot open file [ $file ] $!\n";
    while (<IN>) {
	chomp;
	next if /^#/;
	next if /^track/;
	next if /^browser/;
	next if $_ =~ /^\s$/;
	my @vals = split( "\t", $_ );
	my ($chr,$start,$end) = @vals[0,1,2];
	die "[readInProbes] end smaller than start???\n" if ($end < $start);
  
	$chr =~ s/chr//;
	#$info_hash->{$chr.'_'.$_}++ foreach ( $start..$end );
	$info_hash->{$chr}{$_}++ foreach ( $start..$end );
    }
    close IN;
}

sub arrayMean{
    my $array = shift;
    my $mean = sum(@$array)/@$array;
    return( sprintf("%.2f", $mean) );
}

sub loadEnsemblAdaptors{ 
    my ($serv, $user, $reg, $sa, $ga, $ga_of, $da) = @_;
    printMsg( 'i', "Will now try to connect to ensembl db at [$serv]", *STDOUT );
    my $species = 'homo_sapiens';
    $reg->load_registry_from_db( -host => $serv, -user => $user, -verbose => $opt{verbose}, -species => $species );
    $$ga  = $reg->get_adaptor( $species, 'core', 'Gene');
    $$sa  = $reg->get_adaptor( $species, 'core', 'slice' );
    $$ga_of  = $reg->get_adaptor( $species, 'otherfeatures', 'Gene');
    $$da  = $reg->get_adaptor( $species, 'core', 'dbentry');
}



