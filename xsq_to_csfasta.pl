#!/usr/bin/perl 

use warnings;
use strict;

use Getopt::Long;

my $t = 1; #threads
my $d = '/backup/solid_data/5500xl_HU01'; #datafolder
my $x = '/data/fp/XSQ_Tools/'; #XSQ_Tools install folder
my $e = 0;
my $help = 0;

my $usage = "perl xsq_to_csfasta.pl [OPTIONS]
\t-t\tNumber of threads [Default: $t]
\t-d\tMain datafolder [Defaul: $d]
\t-x\tXSQ_Tools install path [Default: $x]
\t-e\tDo not only check, also execute the convertions [Default: disabled]
\t-h (--help)\tPrints this help, then exits
";

GetOptions ("t=i" =>\$t, "d=s" =>\$d, "x=s" =>\$x, "e" =>\$e, "help|h" => \$help);

if ($help){
	die $usage . "\n";
}

my $xsqConverterPath = $x;
chdir($xsqConverterPath);

my @to_convert = ();

while(my $run=<$d/*>){
	print "\n" . $run . "\n";
	convert_folder($run, \@to_convert);
}

print "\n" . 'There are ' . scalar(@to_convert) . " XSQ files to be converted\n\n";

if ($e){

	my $max_procs = 4;
	
	my @childs;
	
	my $running = 0;
	
	foreach my $job (@to_convert){
	
		if($running >= $max_procs){
			wait();
			$running --;
		}
		my $pid = fork();
		if($pid){
			$running++;
		}elsif($pid == 0){
			print "Running: $job\n\n";
			system($job);
			exit(0);
		}else{
			die "Error occured during processing of jobs\n";
		}
	}
	
	while($running){
		wait();
		$running--;
	}

}

sub convert_folder {
	my $folder = shift;
	my $conversions = shift;

	while (my $lane=<$folder/result/lane*>){
		if (-d "$lane/Libraries"){
			# already analyzed
		}else{

			while (my $xsqFile=<$lane/*.xsq>){

				print "\t" . $xsqFile . "\n";
				my $convertString = "./convertFromXSQ.sh -c $xsqFile -o $lane";
				push(@{$conversions}, $convertString);
			}
		}
	}
}
