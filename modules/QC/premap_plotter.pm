#!/usr/bin/perl -w 

package premap_plotter;

use strict;

sub new{
	my ($class, $toplot) = @_;
	my $self = {};

	$self->{_toplot} = $toplot;


	my @timeData = localtime(time);
        my $currentYear = 1900 + $timeData[5];
        my $month = $timeData[4]+1;
        my $day = $timeData[3];
        my $hours = $timeData[2];
        my $minutes = $timeData[1];
	
        $self->{_timeStamp} = "_".$currentYear."_".$month."_".$day."_".$hours."_".$minutes;

	bless $self, $class;
	return $self;

}

sub start{
	my $self = shift;
	
	my $r_exec = "";
	$self->{'pdf'} = "";
	my $toplot = $self->{_toplot};

	$self->{'pdf'} .= "pdf('".$self->{_toplot}->{'pdfpath'}."/Pre_".$self->{_toplot}->{'name'}.".pdf', paper='a4', width=0,height=0);";
	$self->{'pdf'} .= "par(oma=c(0,0,10,0));";
	$self->{'pdf'} .= "layout(matrix(c(1,1,1,2,3,3,3,4,5,5,5,5), 3,4, byrow = TRUE));";

	if(exists($self->{_toplot}->{'dotCount'})){
		$r_exec.= $self->getDotGraph($self->{_toplot}->{'dotCount'});
	}

	if(exists($self->{_toplot}->{'qualityMeans'})){
		$r_exec.= $self->getMQRGraph($self->{_toplot}->{'qualityMeans'});
	}

	if(exists($self->{_toplot}->{'positionQualities'})){
		$r_exec.= $self->getMQPGraph($self->{_toplot}->{'positionQualities'})."\n\n";
	}

	#my ($run, $sample, $library, $tag) = split("_", $self->{_toplot}->{'name'});
	my @idParts = split("_", $self->{_toplot}->{'name'});
	my $run = join('_', @idParts[0..scalar(@idParts)-4]);
	my $sample = $idParts[4];
	my $library = $idParts[5];
	my $tag = $idParts[6];

	$self->{'pdf'} .= "mtext('Pre-mapping analysis results', side=3, outer=TRUE, line=8, cex=2);";
	$self->{'pdf'} .= "mtext('Run: $run', side=3, outer=TRUE, line=6.5, cex=0.8);";
	$self->{'pdf'} .= "mtext('Sample: $sample', side=3, outer=TRUE, line=5.5, cex=0.8);";
	$self->{'pdf'} .= "mtext('Library: $library', side=3, outer=TRUE, line=4.5, cex=0.8);";
	if($tag){
		$self->{'pdf'} .= "mtext('Tag: $tag', side=3, outer=TRUE, line=3.5, cex=0.8);";
		$self->{'pdf'} .= "mtext('Total reads: ".$self->{_toplot}->{'totalreads'}."', side=3, outer=TRUE, line=2.5, cex=0.8);";
	}else{
		$self->{'pdf'} .= "mtext('Total reads: ".$self->{_toplot}->{'totalreads'}."', side=3, outer=TRUE, line=3.5, cex=0.8);";
	}
	

	


	$self->{'pdf'} .= "dev.off();";
	open (REX, ">rex.R") or die "Couldn't write to file, $!";
	print REX $r_exec;
	print REX $self->{'pdf'};
	close REX;

	system($self->{_toplot}->{'rpath'}." CMD BATCH --vanilla --no-save --slave rex.R");

		
#  	unlink("rex.R");
#   	unlink("rex.Rout");
  	unlink("Rplots.pdf");

}

sub getDotGraph{
	my ($self, $data) = @_;
	my $loc = $self->{_toplot}->{'imgpath'};
	my $name = "dot_".$self->{_toplot}->{'name'}.$self->{_timeStamp};

	my $rString="frame<-data.frame(); ";	
 
	my %data = %{$data};

	$rString.="frame<- cbind(c(";
	$rString.= $data->{'0'}.",";
	$rString.= $data->{'1'}.",";
	$rString.= $data->{'2'}."));";

	$rString .= "rownames(frame) <- c('0','1','1+');";

	$rString .= "pframe<- round(frame/sum(frame)*100, 1);";
	$rString .= "lbs <- paste(as.matrix(pframe), \"%\", sep=\"\");";
	$rString .= "colors<-colorRampPalette(c(\"darkgreen\",\"yellow\",\"orange\" ,\"red\"));";
	$self->{'pdf'} .= $rString;
 	$rString .= "par(fig=c(0,1.0,0,1.0), new=TRUE);";

	$rString .= "jpeg(filename=\"".$loc."/".$name.".jpeg\" ,bg='white',width=1300, height=600);";

	$rString .= "pie(as.matrix(pframe), main=\"Percentage of reads with (n) dots\",ps =1, labels=lbs, col = colors(length(pframe)), cex=2.0,cex.main=3.0, radius = 0.9);";
	$self->{'pdf'} .= "pie(as.matrix(pframe), main=\"Percentage of reads with (n) dots\",ps =1, labels=lbs, col = colors(length(pframe)));";
	$rString .= "legend(\"topleft\", paste(rownames(pframe),  apply(frame, 1, function(x) formatC(x, big.mark=\",\",format=\"fg\")), sep=\" \"), fil=colors(length(pframe)), cex=2.0);";
	$self->{'pdf'} .= "legend(\"topleft\", paste(rownames(pframe),  apply(frame, 1, function(x) formatC(x, big.mark=\",\",format=\"fg\")), sep=\" \"), fil=colors(length(pframe)));";
	$rString .= "par(fig=c(0.75,0.85,0.05,0.95), new=TRUE);";

	$rString .= "barplot(as.matrix(pframe), ps =1, col = colors(nrow(pframe)), horiz=FALSE, axisnames=FALSE, cex.axis=2.0,las=1);";
	$self->{'pdf'} .= "barplot(as.matrix(pframe), ps =1, col = colors(nrow(pframe)), horiz=FALSE, axisnames=FALSE);\n";
	$rString .= "graphics.off();\n\n";
	
	return $rString;

}

sub getMQRGraph{
	my ($self, $data) = @_;
	my $loc = $self->{_toplot}->{'imgpath'};
	my $name = "mqr_".$self->{_toplot}->{'name'}.$self->{_timeStamp};
    
	my $rString="frame<-data.frame(); ";	
 
	my %data = %{$data};
	$rString.="frame<- cbind(c(";
	my $colnames = "rownames(frame) <- c(";
	
# 	foreach my $key(keys %data){
# 		print $key."\t".$data->{$key}."\n";
# 	}	

	if(exists($data->{'0-5'})){
		$rString.= $data->{'0-5'}.",";
		$colnames.="'0-5',";
	}
	if(exists($data->{'5-10'})){
		$rString.= $data->{'5-10'}.",";
		$colnames.="'5-10',";
	}
	if(exists($data->{'10-15'})){
		$rString.= $data->{'10-15'}.",";
		$colnames.="'10-15',";
	}
	if(exists($data->{'15-20'})){
		$rString.= $data->{'15-20'}.",";
		$colnames.="'15-20',";
	}
	if(exists($data->{'20-25'})){
		$rString.= $data->{'20-25'}.",";
		$colnames.="'20-25',";
	}
	if(exists($data->{'25-30'})){
		$rString.= $data->{'25-30'}.",";
		$colnames.="'25-30',";
	}
	if(exists($data->{'30-35'})){
		$rString.= $data->{'30-35'}.",";
		$colnames.="'30-35',";
	}
	if(exists($data->{'35-40'})){
		$rString.= $data->{'35-40'}.",";
		$colnames.="'35-40',";
	}	
	chop $colnames;
	$colnames.= ");";
	chop $rString;
	$rString.="));";
	$rString .= $colnames;

	$rString .= "pframe<- round(frame/sum(frame)*100, 1);";
	$rString .= "lbs <- paste(as.matrix(pframe), \"%\", sep=\"\");";

	$rString .= "colors<-colorRampPalette(c(\"red\",\"orange\",\"yellow\" ,\"darkgreen\"));";
	$self->{'pdf'} .= $rString;
	$rString .= "jpeg(filename=\"".$loc."/".$name.".jpeg\", bg='white',width=1300, height=600);";
 	$rString .= "par(fig=c(0,1.0,0,1.0), new=TRUE);";
	
	$rString .= "pie(as.matrix(pframe), main=\"Mean quality score distribution among reads\",ps =1, labels=lbs, col = colors(length(pframe)), cex=2.0, radius = 0.9, cex.main=3.0);";
	$self->{'pdf'} .= "pie(as.matrix(pframe), main=\"Mean quality score distribution among reads\",ps =1, labels=lbs, col = colors(length(pframe)));";
	$rString .= "legend(\"topleft\", paste(rownames(pframe),  apply(frame, 1, function(x) formatC(x, big.mark=\",\",format=\"fg\")), sep=\" \"), fil=colors(length(pframe)), cex=2.0);";
	$self->{'pdf'} .= "legend(\"topleft\", paste(rownames(pframe),  apply(frame, 1, function(x) formatC(x, big.mark=\",\",format=\"fg\")), sep=\" \"), fil=colors(length(pframe)));";
	$rString .= "par(fig=c(0.75,0.85,0.05,0.95), new=TRUE);";
	
	$rString .= "barplot(as.matrix(pframe), ps =1, col = colors(nrow(pframe)), horiz=FALSE, axisnames=FALSE, cex.axis=2.0,las=1);";
	$self->{'pdf'} .= "barplot(as.matrix(pframe), ps =1, col = colors(nrow(pframe)), horiz=FALSE, axisnames=FALSE);\n";
	$rString .= "graphics.off();\n\n";

	return $rString;
}

sub getMQPGraph{
	my ($self, $data) = @_;
	my $loc = $self->{_toplot}->{'imgpath'};
	my $name = "mqp_".$self->{_toplot}->{'name'}.$self->{_timeStamp};
	my $total =$self->{_toplot}->{'totalreads'};
#	my $mm
	my $rString="l <- list();";	
	$rString.= 'l$stats <- matrix(c(';
	my $rString2 = 'l$n<-c(';

	my %data = %{$data};


	my $lb=($total/2)/2;
	my $me=$total/2;
	my $ub=($total + $total/2)/2;

	my $pos = 1;
	foreach my $row(sort{$a <=> $b} keys %data){
		my $_a=0;
		my $_b=0;
		my $_c=0;
		my $_d=0;
		my $_e=0;
		my $count=0;

		$rString2 .= "$total,";
		foreach my $col(sort{$a <=> $b}keys %{$data{$row}}){
			$count+= $data{$row}->{$col};

			if($_b==0 && $count >= $lb){$_b = $col}
			if($_c==0 && $count >= $me){$_c = $col}
			if($_d==0 && $count >= $ub){$_d = $col}
# 			print $col."\n";
		}
		$count=0;
		my $up = $_d+(1.5*($_d - $_b));
		my $low = $_b-(1.5*($_d - $_b));
		
		foreach my $col(sort{$a <=> $b}keys %{$data{$row}}){
			if ($col <= $up){$_a = $col}		
			if ($_e==0 && $col >= $low){$_e = $col}
		}
		$pos++;
		$rString.= "$_a,$_b,$_c,$_d,$_e,";
	}
	chop($rString);
	$rString .="), nrow=5); \n";

	chop($rString2);
	$rString2 .=");\n";	

	$rString .= $rString2;
	$self->{'pdf'} .= $rString;
	$rString .= "jpeg(filename=\"".$loc."/".$name.".jpeg\", bg='white',width=1300, height=600);";
	$rString.="par(mar=c(5,6,4,6));";
	
	$rString .= "bxp(l, ylim=c(0,40),xlab=\"Read position\", ylab=\"Quality\",main=\"Distribution of quality scores per readposition\", boxfill=c(\"blue4\",\"steelblue1\",\"orange\",\"bisque1\",\"green\"), las=1, cex.lab=1.8, cex.axis=1.5,cex.main=3.0);";
	$self->{'pdf'} .= "bxp(l, ylim=c(0,40),xlab=\"Read position\", ylab=\"Quality\",main=\"Distribution of quality scores per readposition\", boxfill=c(\"blue4\",\"steelblue1\",\"orange\",\"bisque1\",\"green\"), las=1);";
	$rString .= "graphics.off();";

	return $rString;

}



1;
