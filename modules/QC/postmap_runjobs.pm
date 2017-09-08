#!/usr/bin/perl -w 

package postmap_runjobs;

use strict;

sub new{
	my ($class) = @_;
  	my $self = {};

  	bless $self, $class;
  
  	return $self;
}


sub init{
	my ($self, $jobs, $proc) = @_;

	$self->{'jobs'} = $jobs;
	$self->{'proc'} = $proc;
 	$self->{'running'} = [];
	
}

sub run{
	my $self = shift;

	die "Missing list of jobs and/or maximum number of processes running at the same time\n" if (!exists($self->{'jobs'}) or !exists($self->{'proc'}));
	my @jobs = @{$self->{'jobs'}};
 	my @running = ();
	my $nr = 0;

	while(my $job = shift(@jobs)){

		while($self->checkCPUload > 90 or $self->checkMEMload > 90){
			print "Waiting for system recourses (CPU / MEM)\n";
			
			sleep(10);
		}

		#If maximum nr of running jobs equals max wait for at least one job to finish
  		if($nr >= $self->{'proc'}){
			wait();
			$nr --;


  		}
		
  		my $pid = fork();
  		if($pid){
			$nr++;
  		}elsif($pid == 0){
    			print "Running:\n $job\n\n";
			`$job`;
			exit(0);

  		}else{
    			die "Error occured during processing of jobs\n";
  		}

	}
	#Wait for and clean up last remaining jobs
	while($nr != 0){
		wait();
		$nr--;
	}
}

#Uses 'sar' linux command to extract the current % cpu load
sub checkCPUload{
	return 100-(int((split(/\s/, `sar -u 1 1`))[-1]));
}

#Uses 'free' linux command to extract the used an available memory
sub checkMEMload{
	my ($used, $free) = `free -m` =~ m/buffers\/cache:\s+(\d+)\s+(\d+)/;
	return int(($used / ($used + $free)) * 100);
}


1;