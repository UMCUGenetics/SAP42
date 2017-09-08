#!/usr/bin/perl -w

use strict;
use CGI;

my $q = CGI->new;

print $q->header();

my $dir = '/data';
my $filetype = '';

if ($q->param('dir')){
	$dir = $q->param('dir');
}

if ($q->param('file')){
	$filetype = $q->param('file');
}

my @files = ();
my @folders = ();

while (<$dir/*>){
	my $entry = $_;

	if (-d $entry){
		push(@folders, $entry);
	}else{
		if ($filetype){
			if ($entry =~ m/$filetype$/){
				push(@files, $entry);
			}
		}else{
			push(@files, $entry);
		}
	}

}

#fileBrowser('/data/', 'txt', 'selectFile')

print "<img src=\"img/folder_open.png\" \> <input type=\"text\" value=\"$dir\" \>";

my $parentFolder = $dir;
$parentFolder =~ s/\/.+?$//;

print "<div id=\"folderName\" onclick=\"fileBrowser('$parentFolder', '$filetype', 'selectFile');\"><img src=\"img/generic_folder.png\" \> ..</div>\n";

foreach my $folder (@folders){

	my $name = $folder;
	$name =~ s/$dir//;
	$name =~ s/\///;

	print "<div id=\"folderName\" onclick=\"fileBrowser('$folder', '$filetype', 'selectFile');\"><img src=\"img/generic_folder.png\" \> $name</div>\n";
}

foreach my $file (@files){

	my $name = $file;
	$name =~ s/$dir//;
	$name =~ s/\///;

	print "<input type=\"radio\" name=\"pwd\" value=\"$file\" />$name<br />\n";
}