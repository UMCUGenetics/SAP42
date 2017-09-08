package config;

# loadConfiguration (String fileName)
# opens and reads a file with the name fileName

sub loadConfiguration {

	my $configuration;

	my $fileName = shift;
	open (CONF, "<$fileName") or die "Can not open $fileName\n";

	my $max_conf_nummer = 0;

	while (<CONF>){
		chomp;

		my $conf_nr = 0;

		next if m/^\s*?#/;

		my ($argument, $value) = split("\t");

		while (defined($configuration->[$conf_nr]->{uc($argument)})){
			$conf_nr++;

			$max_conf_nummer = $conf_nr if ($conf_nr > $max_conf_nummer);
		}

		$configuration->[$conf_nr]->{uc($argument)} = $value;
	}

	close (CONF);

	return ($configuration, $max_conf_nummer);

}

sub checkConfiguration {
	
}

sub derive_run_name_xsq {
	my $conf = shift;

	my $run_name = 'X';
	my $segment_name = 'X';
	my $library_name = 'X';
	my $tag_name = 'X';


	if($conf->{XSQ} =~ m/\/.*\/(.*?)\/(L\d{2})\/result\/.*\.xsq$/){#wildfire
		$run_name = $1;
		$segment_name = $2;
	}elsif($conf->{XSQ} =~ m/\/.*\/(.*?)\/result\/(lane\d{1})\/.*\.xsq$/){
		$run_name = $1;
		$segment_name = $2;
	}

	($library_name, $tag_name) = (split("_",$conf->{NAME}))[1,2];

	return ($run_name, $segment_name, $library_name, $tag_name);

# 	lane1_CBk27ac_F3_20120612

}


sub derive_run_name_csfasta {
	my $csfasta = shift;

	my $run_name = 'X';
	my $segment_name = 'X';
	my $library_name = 'X';
	my $tag_name = 'X';

	if ($csfasta =~ m/.+\/(.+?)\/result\/(lane\d)\/Libraries\/(.+?)\/(.+?)\/reads\/.+?\.csfasta/){
		$run_name = $1;
		$library_name = $3;
		$segment_name = $2;
		$tag_name = $4;

	}else{

		if ($csfasta =~ m/(solid\d+.+?)\//){
			$run_name = $1;
		}
		
		if ($csfasta =~ m/$run_name\/(.+?)\//){
			$segment_name = $1;
			$library_name = $segment_name;
			if ($csfasta =~ m/_F3/){
				$tag_name = "F3";
			}elsif ($csfasta =~ m/_F5-P2/){
				$tag_name = "F5-P2";
			}elsif ($csfasta =~ m/_R3/){
				$tag_name = "R3";
			}
		}
	
		if ($csfasta =~ m/\/libraries\/(.+?)\/primary/){
			$library_name = $1;
		}

	}

	return ($run_name, $segment_name, $library_name, $tag_name);
}

sub print_configuration {
	my $c = shift;
	my $fileName = shift;

	print "\nConfig will be saved to: $fileName\n\n";

	if(exists($c->{CSFASTA})){
		($c->{RUNNAME}, $c->{SAMPLENAME}, $c->{LIBRARYNAME}, $c->{LIBTAG}) = derive_run_name_csfasta($c->{CSFASTA})
	}elsif(exists($c->{XSQ})){
		($c->{RUNNAME}, $c->{SAMPLENAME}, $c->{LIBRARYNAME}, $c->{LIBTAG}) = derive_run_name_xsq($c)
	}else{
		die "No CSFASTA or XSQ file found in configuration\n";
	}


	use Data::Dumper;
	print Dumper($c) . "\n";

	print "Saving file to $fileName\n\n" if $verbose;

	open (OUT, ">$fileName") or die "Can not save to $fileName: $!\n\n";

	print OUT "#general information\n";
	print OUT "NAME\t" . $c->{NAME} . "\n\n";

	print OUT "PROJECT\t" . $c->{NAME} . "\n\n";
	print OUT "PLATFORM\t" . $c->{PLATFORM} . "\n\n";

	print OUT "RUNNAME\t" . $c->{RUNNAME} . "\n";
	print OUT "SAMPLENAME\t" . $c->{SAMPLENAME} . "\n";
	print OUT "LIBRARYNAME\t" . $c->{LIBRARYNAME} . "\n\n";
	print OUT "LIBTAG\t" . $c->{LIBTAG} . "\n\n";

	print OUT "#SGE priority\n";

	if (defined($c->{PRIORITY})){
		print OUT "PRIORITY\t" . $c->{PRIORITY} . "\n\n";
	}else{
		print OUT "PRIORITY\t" . 0 . "\n\n";
	}

	print OUT "DESIGN\t" . $c->{DESIGN} . "\n" if defined($c->{DESIGN});
	
	print OUT "#location of the csfasta & quality file or xsq file\n";
	print OUT "CSFASTA\t" . $c->{CSFASTA} . "\n" if exists($c->{CSFASTA});
	print OUT "QUAL\t" . $c->{QUAL} . "\n\n" if exists($c->{QUAL});
	print OUT "XSQ\t" . $c->{XSQ} . "\n\n" if exists($c->{XSQ});

	print OUT "READS\t" . $c->{READS} . "\n\n" if defined ($c->{READS});
	
	print OUT "#working directory\n";

	$c->{PWD} =~ s/\/{2,}/\//;
	$c->{PWD} =~ s/\/+$/\//;

	print OUT "PWD\t" . $c->{PWD} . "/\n\n";
	
	print OUT "#splitting\n";
	print OUT "SPLITS\t" . $c->{SPLITS} . "\n\n" if exists($c->{SPLITS});
	
	print OUT "#reference genome\n";
	print OUT "REFERENCE\t" . $c->{REFERENCE} . "\n\n";
	
	print OUT "#aligment program\n";
	print OUT "ALNPROM\tbwa\n";
	$c->{ALNARG} = join(' ', split(',', $c->{ALNARG})) if exists($c->{ALNARG});
	print OUT "ALNARG\t" . $c->{ALNARG} . "\n\n" if exists($c->{ALNARG});

	if (defined($c->{EMAIL})){
		print OUT "EMAIL\t" . join(', ', split(',', $c->{EMAIL})) . "\n\n";
	}

	print OUT "PRESTATS\t" . $c->{PRESTATS} . "\n" if defined($c->{PRESTATS});
	print OUT "POSTSTATS\t" . $c->{POSTSTATS} . "\n\n" if defined($c->{POSTSTATS});
	
	print OUT "#SNP call stuff\n\n";
	print OUT "VARIANTCALLER\t" . $c->{VARIANTCALLER} . "\n" if defined($c->{VARIANTCALLER});
	$c->{VARIANTSETTINGS} = join(' ', split(',', $c->{VARIANTSETTINGS})) if defined($c->{VARIANTSETTINGS});
	print OUT "VARIANTSETTINGS\t" . $c->{VARIANTSETTINGS} . "\n\n" if defined($c->{VARIANTSETTINGS});
	
	print OUT "VARIANTSPECIES\t" . $c->{VARIANTSPECIES} . "\n" if defined($c->{VARIANTSPECIES});
	
	print OUT "VARIANTEFFECTS\t" . $c->{VARIANTEFFECTS} . "\n" if defined($c->{VARIANTEFFECTS});
	
	print OUT "VARIANTFORCE\t" . $c->{VARIANTFORCE} . "\n\n" if defined($c->{VARIANTFORCE});

	print OUT "PILEUP\t" . $c->{PILEUP} . "\n" if defined($c->{PILEUP});

	print OUT "FULLPILEUP\t" . $c->{FULLPILEUP} . "\n\n" if defined($c->{FULLPILEUP});

	print OUT "CALLSNPS\t" . $c->{CALLSNPS} . "\n" if defined($c->{FULLPILEUP});

	print OUT "CALLINDELS\t" . $c->{CALLINDELS} . "\n" if defined($c->{FULLPILEUP});
	
	print OUT "#make logfile with status...\n\n";

	print OUT "SUBVERSION\t" . $c->{SUBVERSION} . "\n\n";

	print OUT "RELEASE\t" . $c->{RELEASE} . "\n\n" if exists($c->{RELEASE});

	close(OUT);

	return $fileName;
}


################Function that executes SAP_run using a pipeline configuration file (.conf)#############
#$execute = 0|1 (off/on) 
#$verbose = 0|1 (off/on)
#$fileName = string (name of configfile)
#$scriptRoot = string (location of SAP42 main scripts)
sub execute {

	my ($execute,$verbose, $fileName, $scriptRoot) = @_;

	if ($execute){
		my $command = "perl $scriptRoot/SAP42_run $fileName";


# 		if (!$verbose){
# 			$command .= " > /dev/null 2> /dev/null";
# 		}

		print "Executing...$execute\n\n" if $verbose;
		print $command."\n";


		system("$command > submit.log 2> submit.err &");
	}else{
		print "Not executing...$execute\n\n" if $verbose;
	}
}

sub get_svn_revision {

	my $scriptroot = shift;

	my $svn = `svn info $scriptroot`;

	foreach my $line (split("\n", $svn)){
		if ($line =~ m/Revision\:.(\d+)/){
			return $1;
		}
	}
	
	return "X";

}

1;