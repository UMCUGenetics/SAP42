package settings;

# loadConfiguration (String fileName)
# opens and reads a file with the name fileName

sub loadConfiguration {

	my %configuration;

	my $fileName = shift;
	open (CONF, "<$fileName") or die "Can not open $fileName\n";

	while (<CONF>){
		chomp;

		next if m/^#/;
		next if m/^$/;

		my ($argument, $value) = split("\t");

		$configuration{uc($argument)} = $value;
	}

	return \%configuration;

}

1;