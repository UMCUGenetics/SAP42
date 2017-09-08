#!/usr/bin/perl -w 

package postmap_plotter;

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
#  	my ($project, $bam) = split("__", $self->{_toplot}->{'name'});


 	my ($run, $sample, $lib, $tag) = split(/\^/, $self->{_toplot}->{'name'});
	print $self->{_toplot}->{'name'} . "\n";
	$self->{_toplot}->{'name'}  =~ s/\^/_/g;
	print $self->{_toplot}->{'name'} . "\n";

#     	my $run= join('_', @idParts[0..scalar(@idParts)-4]);
# 	my $sample = $idParts[4];
#     	my $lib = $idParts[5];
#     	my $tag = $idParts[6];




	$self->{'pdf'} .= "pdf('".$self->{_toplot}->{'pdfpath'}."/Post_".$self->{_toplot}->{'name'}.".pdf', paper='a4', width=0,height=0);";
	$self->{'pdf'} .= "par(oma=c(0,0,10,0));";
	$self->{'pdf'} .= "layout(matrix(c(1,1,1,2,3,3,3,4,5,5,5,6), 3,4, byrow = TRUE));";
	
	

	if(exists($self->{_toplot}->{'mapping'})){
		$r_exec .= $self->getMapGraph($self->{_toplot}->{'mapping'});
# 		$self->{'pdf'} .= "plot.new();"
	}

	$self->{'pdf'} .= "mtext('Post-mapping analysis results', side=3, outer=TRUE, line=8, cex=2);";
	$self->{'pdf'} .= "mtext('Run: $run', side=3, outer=TRUE, line=6.5, cex=0.8);";
	$self->{'pdf'} .= "mtext('Sample: $sample', side=3, outer=TRUE, line=5.5, cex=0.8);";
	$self->{'pdf'} .= "mtext('Library: $lib', side=3, outer=TRUE, line=4.5, cex=0.8);";
	$self->{'pdf'} .= "mtext('Tag: $tag', side=3, outer=TRUE, line=3.5, cex=0.8);";
	$self->{'pdf'} .= "mtext('Total reads: ".$self->{_toplot}->{'totalreads'}."', side=3, outer=TRUE, line=2.5, cex=0.8);";
	$self->{'pdf'} .= "mtext('Reference size/Design: ".$self->{_toplot}->{'reference'}."', side=3, outer=TRUE, line=1.5, cex=0.8);";


	if(exists($self->{_toplot}->{'ambiguity'})){
		$r_exec .= $self->getAmbGraph($self->{_toplot}->{'ambiguity'});

		$self->{'pdf'} .= "plot.new();";
	}

	if(exists($self->{_toplot}->{'mapping_qualities'})){
		$r_exec .= $self->getMqGraph($self->{_toplot}->{'mapping_qualities'});
		$self->{'pdf'} .= "plot.new();"
	}


	if(exists($self->{_toplot}->{'read_mismatches'})){
		$r_exec .= $self->getRmmGraph($self->{_toplot}->{'read_mismatches'});
		$self->{'pdf'} .= "plot.new();";
	}
	
	if(exists($self->{_toplot}->{'pos_mismatches'})){
# 		print "it exists\n";
		$r_exec .= $self->getPmmGraph($self->{_toplot}->{'pos_mismatches'});
		$self->{'pdf'} .= "plot.new();";
	}

	if(exists($self->{_toplot}->{'on_target/flanks'})){
		$r_exec .= $self->getOtaGraph($self->{_toplot}->{'on_target/flanks'});
# 		$self->{'pdf'} .= "plot.new();";
	}

	if(exists($self->{_toplot}->{'coverage'})){
		$r_exec .= $self->getTcoGraph($self->{_toplot}->{'coverage'});
		$self->{'pdf'} .= "plot.new();";
	}

	
	if(exists($self->{_toplot}->{'clonality'})){
		$r_exec .= $self->getPclonGraph($self->{_toplot}->{'clonality'});
	}
	
	if(exists($self->{_toplot}->{'complexity'})){
		$r_exec .= $self->getComGraph($self->{_toplot}->{'complexity'});
	}


	$self->{'pdf'} .= "dev.off();";
	open (REX, ">rex.R") or die "Couldn't write to file, $!";
	print REX $r_exec;
	print REX $self->{'pdf'};
	close REX;

	system($self->{_toplot}->{'rpath'}." CMD BATCH --vanilla --no-save --slave rex.R");
	
	
 	#unlink("rex.R");
  	#unlink("rex.Rout");
  	unlink("Rplots.pdf");

}

sub getMapGraph{
	my ($self, $data) = @_;
	my $loc = $self->{_toplot}->{'imgpath'};
	my $name = $self->{_toplot}->{'name'}.$self->{_timeStamp};


	my $rString="frame<-data.frame(); ";	
 	
# 	my %data = %{$data};

	
	$rString.="frame<- cbind(c(".$data->{'FORWARD'}.",".$data->{'REVERSE'}.",".$data->{'UNMAPPED'}."));";
	$rString.="rownames(frame) <- c('Forward','Reverse','Unmapped');";

	my $totmapped = (($data->{'FORWARD'}+$data->{'REVERSE'})/($data->{'FORWARD'}+$data->{'REVERSE'}+$data->{'UNMAPPED'}))*100;
	$totmapped = sprintf("%.2f", $totmapped);


	$rString .= "pframe<- round(frame/sum(frame)*100, 1);";
	$rString .= "lbs <- paste(as.matrix(pframe), \"%\", sep=\"\");";
	$rString .= "colors<-colorRampPalette(c(\"darkgreen\",\"yellow\",\"orange\" ,\"red\"));";
	$self->{'pdf'} .= $rString;
	$rString .= "jpeg(filename=\"".$loc."/map_".$name.".jpeg\" ,bg='white',width=1300, height=600);";
	
  	$rString .= "par(fig=c(0,1.0,0,1.0), new=TRUE);";
	$rString .= "pie(as.matrix(pframe), main=\"Mapping overview of reads\",ps =1,ps =1, labels=lbs, col = colors(nrow(pframe)), cex=2.0,cex.main=3.0, radius = 0.9);";
	$self->{'pdf'} .= "pie(as.matrix(pframe), main=\"Mapping overview of reads\",ps =1,ps =1, labels=lbs, col = colors(nrow(pframe)));";
	$rString .= "legend(\"topleft\", paste(rownames(pframe), apply(frame, 1, function(x) formatC(x, big.mark=\",\",format=\"fg\")), sep=\" \"), fil=colors(nrow(pframe)), cex=2.0);";
	$self->{'pdf'} .= "legend(\"topleft\", paste(rownames(pframe), apply(frame, 1, function(x) formatC(x, big.mark=\",\",format=\"fg\")), sep=\" \"), fil=colors(nrow(pframe)));";
	$rString .= "par(fig=c(0.75,0.85,0.05,0.95), new=TRUE);";
	$rString .= "barplot(as.matrix(pframe), ps =1, col = colors(nrow(pframe)), horiz=FALSE, axisnames=FALSE, cex.axis=2.0,las=1);";
	$self->{'pdf'} .= "barplot(as.matrix(pframe), ps =1, col = colors(nrow(pframe)), horiz=FALSE, axisnames=FALSE);\n";
	$rString .= "mtext(\"Total mapped: ".$totmapped."%\", side=1,line=1,cex=1.8);";
	$self->{'pdf'} .= "mtext(\"Total mapped: ".$totmapped."%\", side=1,line=1);";
	$rString .= "graphics.off();\n\n";

	return $rString;
}

sub getAmbGraph{
	my ($self, $data) = @_;
	my $loc = $self->{_toplot}->{'imgpath'};
	my $name = $self->{_toplot}->{'name'}.$self->{_timeStamp};

  
# 	my %data = %{$data};
# 
	my $rString="frame<-data.frame(); ";	
 	my $rownames = "rownames(frame) <- c(";
# 
 	$rString.="frame<- cbind(c(";
# 
	foreach my $key (sort {$a <=> $b} keys %{$data}){
		if($key != 10){
			$rString.= $data->{$key}.",";
			$rownames.= "'".$key."',";
		}
		else{
			$rString.= $data->{$key}.",";
			$rownames.= "'>9',";
		}
	}

	chop $rString;
	chop $rownames;
	$rString.="));";
	$rownames.=");";
	$rString.=$rownames;

		

	$rString .= "pframe<- round(frame/sum(frame)*100, 1);";
	$rString .= "lbs <- paste(rownames(pframe), \"\", sep=\"\");";
	$rString .= "colors<-colorRampPalette(c(\"darkgreen\",\"yellow\",\"orange\" ,\"red\"));";
	$self->{'pdf'} .= $rString;

	$rString .= "jpeg(filename=\"".$loc."/uni_".$name.".jpeg\" ,bg='white',width=1300, height=600);";
  	$rString .= "par(fig=c(0,0.95,0,1.0), new=TRUE);";
# 	
	$rString .= "barplot(as.matrix(pframe), main=\"Mapping ambiguity (1-10+)\",ps =1, col =colors(length(pframe)), beside=TRUE, names.arg=lbs, cex.lab=1.8,cex.axis=1.5,cex.names=1.5,las=1, cex.main=3.0,ylim=c(0,100), ylab=\"Percentage of all reads\", xlab=\"Mapping ambiguity\");";
	$self->{'pdf'} .= "barplot(as.matrix(pframe), main=\"Mapping ambiguity (1-10+)\",ps =1, col =colors(length(pframe)), beside=TRUE, names.arg=lbs, ylim=c(0,100), ylab=\"Percentage of all reads\", xlab=\"Mapping ambiguity\");";
  	$rString .= "graphics.off();\n\n";
	
	return $rString;


}

sub getMqGraph{
	my ($self, $data) = @_;
	my $loc = $self->{_toplot}->{'imgpath'};
	my $name = $self->{_toplot}->{'name'}.$self->{_timeStamp};


	my $rString="frame<-data.frame(); ";	
	$rString .= "frame<- rbind(frame, c(";
 	my $colnames = "colnames(frame) <- c(";

	#my %data = %$data;

	foreach my $row(sort{$a <=> $b} keys %{$data}){
# 		print "$row\t".$data->{$row}."\n";
		$rString.= $data->{$row}.",";
		$colnames .= "'$row',";	
	}
	
	chop($colnames);
	chop($rString);
	$rString.="));";
	$colnames .= ");";
	$rString .= $colnames;

	$rString .= "colors<-colorRampPalette(c(\"red\",\"orange\" ,\"yellow\", \"darkgreen\"));";
	my $color = "colors(length(frame))";
	$self->{'pdf'} .= $rString;
	$rString.="jpeg(filename=\"".$loc."/mq_".$name.".jpeg\" ,bg='white',width=1300, height=600);";
	$rString .= "par(fig=c(0,0.95,0,1.0), new=TRUE);";
	$rString .= "barplot(as.matrix(frame), ylim=c(0,100), main=\"Mapping quality distribution of all reads\", col=$color, xlab=\"Mapping Quality\", ylab=\"Percentage of all reads\", cex.lab=1.8, cex.axis=1.5,cex.main=3.0, beside=TRUE, las=1,cex.names=1.5);graphics.off();";
	$self->{'pdf'} .= "barplot(as.matrix(frame), ylim=c(0,100), main=\"Mapping quality distribution of all reads\", col=$color, xlab=\"Mapping Quality\", ylab=\"Percentage of all reads\", beside=TRUE);";
	return $rString;

}

sub getRmmGraph{
	my ($self, $data) = @_;
	my $loc = $self->{_toplot}->{'imgpath'};
	my $name = $self->{_toplot}->{'name'}.$self->{_timeStamp};

	my $rString="frame<-data.frame(); ";	
	my $colnames = "rownames(frame) <- c(";

	#my %data = %{$data};

	$rString.="frame<- cbind( c(";
	foreach my $key (sort{$a <=> $b}keys %{$data}){
		$rString.= $data->{$key}.",";
		$colnames.= "'".$key."',";
	}
	
	chop $rString;
	chop $colnames;
	$rString.="));";
	$colnames.=");";
	$rString.=$colnames;

	$rString .= "pframe<- round(frame/sum(frame)*100, 1);";
	$rString .= "lbs <- paste(rownames(pframe), \"\", sep=\"\");";
	$rString .= "colors<-colorRampPalette(c(\"darkgreen\",\"yellow\",\"orange\" ,\"red\"));";
	$self->{'pdf'} .= $rString;
	$rString .= "jpeg(filename=\"".$loc."/rmm_".$name.".jpeg\" ,bg='white',width=1300, height=600);";
	$rString .= "par(fig=c(0,0.95,0,1.0), new=TRUE);";
	$rString .= "barplot(as.matrix(pframe), main=\"Distribution of reads with 0-10 mismatch(es)\",ps =1, col =colors(length(pframe)), beside=TRUE, names.arg=lbs, cex.lab=1.8,cex.axis=1.5,cex.names=1.5,las=1, cex.main=3.0,ylim=c(0,50), ylab=\"Percentage of all reads\", xlab=\"Number of mismatches\");";
	$self->{'pdf'} .= "barplot(as.matrix(pframe), main=\"Distribution of reads with 0-10 mismatch(es)\",ps =1, col =colors(length(pframe)), beside=TRUE, names.arg=lbs, ylim=c(0,50), ylab=\"Percentage of all reads\", xlab=\"Number of mismatches\");";
	$rString .= "graphics.off();\n\n";
	
	return $rString;

}

sub getPmmGraph{
	my ($self, $data) = @_;
	my $loc = $self->{_toplot}->{'imgpath'};
	my $name = $self->{_toplot}->{'name'}.$self->{_timeStamp};

	my $rString="frame<-data.frame(); ";	
	my $colnames = "colnames(frame) <- c(";

#	my %data = %{$data};

	$rString.="frame<- rbind( c(";
	foreach my $key (sort{$a <=> $b}keys %{$data}){
# 		print $key."\t".$data->{$key}."\n";
		$rString.= $data->{$key}.",";
		$colnames.= "'".$key."',";
	}
	
	chop $rString;
	chop $colnames;
	$rString.="));";
	$colnames.=");";
	$rString.=$colnames;



	$self->{'pdf'} .= $rString;
	my $color = "c(\"blue4\",\"steelblue1\",\"orange\",\"bisque1\",\"green\")";
	
	$rString.="jpeg(filename=\"".$loc."/pmm_".$name.".jpeg\" ,bg='white',width=1300, height=600);";
	$rString .= "par(fig=c(0.05,0.95,0,1.0), new=TRUE);";
	$rString .= "barplot(as.matrix(frame), main=\"Percentage of mismatches per readposition\", col=$color, xlab=\"Position in read\", ylab=\"Percentage of all reads\", cex.lab=1.8, cex.axis=1.5,cex.main=3.0, beside=TRUE, las=1,cex.names=1.5, ylim=c(0,20));graphics.off();";
	$self->{'pdf'} .= "barplot(as.matrix(frame), main=\"Percentage of mismatches per readposition\", col=$color, xlab=\"Position in read\", ylab=\"Percentage of all reads\", beside=TRUE, ylim=c(0,20));";




	return $rString;


}

sub getOtaGraph{
	my ($self, $data) = @_;
	my $loc = $self->{_toplot}->{'imgpath'};
	my $name = $self->{_toplot}->{'name'}.$self->{_timeStamp};

	my $rString="frame<-data.frame(); ";	
 
# 	my %data = %{$data};

	$rString.="frame<- cbind(c(";
	$rString.= $data->{'Bases in targets'}.",";
	$rString.= $data->{'Bases in flanks'}.",";
	$rString.= $data->{'Bases outside flanks/targets'}.",";	


	chop $rString;
	
	$rString.="));";


	$rString .= "rownames(frame) <- c('Bases in targets','Bases in flanks','Bases off-target');";

	$rString .= "pframe<- round(frame/sum(frame)*100, 1);";
	$rString .= "lbs <- paste(as.matrix(pframe), \"%\", sep=\"\");";
	$rString .= "colors<-colorRampPalette(c(\"darkgreen\",\"yellow\",\"orange\" ,\"red\"));";
	$self->{'pdf'} .= $rString;
	$rString .= "jpeg(filename=\"".$loc."/ota_".$name.".jpeg\" ,bg='white',width=1300, height=600);";
	$rString .= "par(fig=c(0,0.95,0,1.0), new=TRUE);";
	$rString .= "pie(as.matrix(pframe), main=\"Enrichment efficiency (on target bases)\",ps =1, labels=lbs, col = colors(length(pframe)), cex=2.0,cex.main=3.0, radius = 0.9);";
	$self->{'pdf'} .= "pie(as.matrix(pframe), main=\"Enrichment efficiency (on target bases)\",ps =1, labels=lbs, col = colors(length(pframe)));";
	$rString .= "legend(\"topleft\", paste(rownames(pframe), apply(frame, 1, function(x) formatC(x, big.mark=\",\",format=\"fg\")), sep=\" \"), fil=colors(length(pframe)));";
	$self->{'pdf'} .= "legend(\"topleft\", paste(rownames(pframe), apply(frame, 1, function(x) formatC(x, big.mark=\",\",format=\"fg\")), sep=\" \"), fil=colors(length(pframe)));";
	$rString .= "par(fig=c(0.75,0.85,0.05,0.95), new=TRUE);";
	$rString .= "barplot(as.matrix(pframe), ps =1, col = colors(nrow(pframe)), horiz=FALSE, axisnames=FALSE, cex.axis=2.0,las=1);";
	$self->{'pdf'} .= "barplot(as.matrix(pframe), ps =1, col = colors(nrow(pframe)), horiz=FALSE, axisnames=FALSE);";
  	$rString .= "graphics.off();\n\n";
	
	return $rString;
}

sub getTcoGraph{
	my ($self, $data) = @_;
	my $loc = $self->{_toplot}->{'imgpath'};
	my $name = $self->{_toplot}->{'name'}.$self->{_timeStamp};


	my ($data_file,$avg, $mdn, $evn, $unc) = @{$data};

	my $rString = "frame<-read.table(file=\"".$data_file."\", row.names=1, header=TRUE);";
	$self->{'pdf'} .= $rString;
	$rString .= "jpeg(filename=\"".$loc."/tco_".$name.".jpeg\" ,bg='white',width=1300, height=600);";
	$rString.= " meanCov <- round(".$avg.",0);";
	$self->{'pdf'} .= "meanCov <- round(".$avg.",0);";
	$rString .= "xmax=5;";
	$self->{'pdf'} .= "xmax=5;";
	$rString .= "if(meanCov > 1){xmax = meanCov * 5};";
	$self->{'pdf'} .= "if(meanCov > 1){xmax = meanCov * 5};";
	


	$rString .= "par(fig=c(0.05,0.9,0,1.0), new=TRUE);";
	
	#coverage
	$rString.="plot(row.names(frame),as.matrix(frame[,1]),col='black', ylim=c(0,10), xlim=c(0,xmax),xlab=\"Coverage\", ylab=\"\",las=1, type = \"l\", main=\"Enrichment efficiency (target coverage)\",cex.lab=1.8, cex.axis=1.5,cex.main=3.0,lwd=2.0);";
	#$rString.="axis(side=2, col.ticks='red', col='black', col.axis='black', las=1, cex.axis=1.5, );";
	$rString.= "mtext(\"Percentage of all target bases\",side=2,line=3,col='black',cex=1.8);";
	
	
	$self->{'pdf'} .= "plot(row.names(frame),as.matrix(frame[,1]),ylim=c(0,10) , col='black',xlim=c(0,xmax),xlab=\"Coverage\", ylab=\"\",las=1, type = \"l\", main=\"Enrichment efficiency (target coverage)\");";
	#$self->{'pdf'} .="axis(side=2, col.ticks='black',col='black', col.axis='black', las=1);";
	$self->{'pdf'}.= "mtext(\"Percentage of all target bases\",side=2,line=3,col='black',cex=0.7);";
	
		
	#cum target coverage
	$rString .= "par(new=TRUE);";
	$rString.="plot(row.names(frame),as.matrix(frame[,2]),ylim=c(0,100),yaxt='n', xlim=c(0,xmax),xaxt='n',xlab=\"\",ylab=\"\",col=4, type = \"l\", lwd=2.0, cex.axis=1.5);";
	$rString.="axis(side=4, col.ticks=4, col=4, col.axis=4, las=1, cex.axis=1.5);";
	$rString.="mtext(\"Percentage of whole target covered\",side=4,line=4,col=4,cex=1.8);";

	$self->{'pdf'} .= "par(new=TRUE);";
	$self->{'pdf'} .= "plot(row.names(frame),as.matrix(frame[,2]),ylim=c(0,100),yaxt='n', xaxt='n', xlim=c(0,xmax),xlab=\"\",ylab=\"\",col=4, type = \"l\");";
	$self->{'pdf'} .= "axis(side=4, col.ticks=4, col=4, col.axis=4, las=1);";
	$self->{'pdf'} .= "mtext(\"Percentage of whole target covered\",side=4,line=4,col=4,cex=0.7);";
		
	
	# text labels
	$rString.="text(0,50,paste(\"Mean coverage:\", meanCov) ,cex=1.8, pos=4);";
	$rString.="text(0,40,\"Median coverage: ".$mdn."\" ,cex=1.8, pos=4);";
	$rString.="text(0,30,paste(\"Uncovered bases:\",round(".$unc.",2),\"%\" ),cex=1.8, pos=4);";
	$rString.="text(0,20,paste(\"Evenness:\",round(".$evn.",2),\"%\" ),cex=1.8, pos=4);";

	$self->{'pdf'} .="text(0,50,paste(\"Mean coverage:\", meanCov) ,cex=0.8, pos=4);";
	$self->{'pdf'} .= "text(0,40,\"Median coverage: ".$mdn."\" ,cex=0.8, pos=4);";
	$self->{'pdf'} .= "text(0,30,paste(\"Uncovered bases:\",round(".$unc.",2),\"%\" ),cex=0.8, pos=4);";
	$self->{'pdf'} .= "text(0,20,paste(\"Evenness:\",round(".$evn.",2),\"%\" ), pos=4 ,cex=0.8);";
# 	$self->{'pdf'} .= "";
# 	$self->{'pdf'} .= "mtext(paste(\"Evenness:\",round(".$evn.",2),\"%\" ), side=3, outer=TRUE, line=4.5, cex=0.8);";
 	$rString .= "graphics.off();\n\n";
	return $rString;


}

sub getPclonGraph{
	my ($self, $data) = @_;
	my $loc = $self->{_toplot}->{'imgpath'};
	my $name = $self->{_toplot}->{'name'}.$self->{_timeStamp};


 	my $rString="frame<-data.frame(); ";
	$rString .= "frame<- cbind(c(".join(",", $data->{'1'},$data->{'2-<10'},$data->{'10-<100'},$data->{'100-<1000'},$data->{'1000-<10000'},$data->{'10000+'})."));";
	$rString .= "rownames(frame)<- c('1','2-<10','10-<100','100-<1000','1000-<10000','10000+');";
	$rString .= "pframe<- round(frame/sum(frame)*100, 1);";
	$rString .= "lbs <- paste(as.matrix(pframe), \"%\", sep=\"\");";
	$rString .= "colors<-colorRampPalette(c(\"darkgreen\",\"yellow\",\"orange\" ,\"red\"));";
	$self->{'pdf'} .= $rString;
	$rString .= "jpeg(filename=\"".$loc."/pclon_".$name.".jpeg\",bg='white',width=1300, height=600);";
	$rString .= "par(fig=c(0,1,0,1.0), new=TRUE);";
	$rString .= "pie(as.matrix(pframe), main=\"Post-mapping distribution of clonal reads\",ps =1, labels=lbs, col = colors(length(pframe)), cex=2.0, radius = 0.9,cex.main=3.0);";
	$self->{'pdf'} .= "pie(as.matrix(pframe), main=\"Post-mapping distribution of clonal reads\",ps =1, labels=lbs, col = colors(length(pframe)));";
	$rString .= "legend(\"topleft\", paste(rownames(pframe), apply(frame, 1, function(x) formatC(x, big.mark=\",\",format=\"fg\")), sep=\" \"), fil=colors(length(pframe)), cex=2.0);";
	$self->{'pdf'} .= "legend(\"topleft\", paste(rownames(pframe), apply(frame, 1, function(x) formatC(x, big.mark=\",\",format=\"fg\")), sep=\" \"), fil=colors(length(pframe)));";
	$rString .= "par(fig=c(0.75,0.85,0.05,0.95), new=TRUE);";
	$rString .= "barplot(as.matrix(pframe), ps =1, col = colors(nrow(pframe)), horiz=FALSE, axisnames=FALSE, cex.axis=2.0,las=1);";
	$self->{'pdf'} .= "barplot(as.matrix(pframe), ps =1, col = colors(nrow(pframe)), horiz=FALSE, axisnames=FALSE);";
	$rString .= "graphics.off();";
	
	return $rString;

}

sub getComGraph{
	my ($self, $data) = @_;
	my $loc = $self->{_toplot}->{'imgpath'};
	my $name = $self->{_toplot}->{'name'}.$self->{_timeStamp};

	my ($fw_file, $rv_file, $fw_compl, $rv_compl) = @{$data};

	my $rString = "fw <- as.matrix(read.table(file=\"".$fw_file."\",row.names=1,header=TRUE));";
	$rString .= "rv <- as.matrix(read.table(file=\"".$rv_file."\",row.names=1,header=TRUE));";

 	$rString.= " fw_compl <- round(".$fw_compl.",2);";
	$rString.= " rv_compl <- round(".$rv_compl.",2);";
	$self->{'pdf'} .= $rString;
	
	$rString .= "jpeg(filename=\"".$loc."/com_".$name.".jpeg\" ,bg='white',width=1300, height=600);";
	
	$rString .= "par(fig=c(0.05,0.9,0,1.0), new=TRUE);";

	$rString.="plot(fw,col='red', xlab=\"Read starts per reference position\",type='l', ylab=\"Nr. reference bases / Total mapped reads\",log=\"xy\", ylim=c(0.000001,1), main=\"Reference coverage by read starts\",cex.lab=1.8, cex.axis=1.5,cex.main=3.0,lwd=2.0);";
	$rString.="par(new=TRUE);";
	$rString.="plot(rv,col='blue',  yaxt='n',xaxt='n',ylab='',xlab='', type='l', log=\"xy\", ylim=c(0.000001,1));";
	$rString.="legend(\"topright\", c(paste('Forward strand, complexity: ',fw_compl),paste('Reverse strand, complexity: ',rv_compl)), cex=2.0, col=c('red','blue'), fill=c('red','blue'));";
# 	$rString.="text(1,1,paste('Complexity fw strand: ', fw_compl), cex=1.8,pos=4);";
# 	$rString.="text(1,2,paste('Complexity rv strand: ', rv_compl), cex=1.8,pos=4);";

	$self->{'pdf'} .= "plot(fw,col='red', xlab=\"Read starts per reference position\",type='l' ,ylim=c(0.000001,1), ylab=\"Nr. reference bases / Total mapped reads\",log=\"xy\", main=\"Reference coverage by read starts\",lwd=2.0);";
	$self->{'pdf'} .="par(new=TRUE);";
	$self->{'pdf'} .="plot(rv,col='blue', yaxt='n',xaxt='n',ylab='',xlab='', type='l', log=\"xy\",ylim=c(0.000001,1));";
	$self->{'pdf'} .="legend(\"topright\", c(paste('Forward strand, complexity: ',fw_compl),paste('Reverse strand, complexity: ',rv_compl)), cex=1.0, col=c('red','blue'), fill=c('red','blue'));";
# 	$self->{'pdf'} .="text(1,1,paste('Complexity fw strand: ', fw_compl), cex=0.8,pos=4);";
# 	$self->{'pdf'} .="text(1,2,paste('Complexity rv strand: ', rv_compl), cex=0.8,pos=4);";
 	
	$rString.="graphics.off();\n\n";

	return $rString;


}



1;
