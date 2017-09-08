<?php

// error_reporting(E_ALL);
// ini_set("display_errors", 1);

# DO THIS SHIT: 

$page = '';

if (isset($_REQUEST['page'])) {$page= $_REQUEST['page'];}


echo content($page);



// function menu()
// {
// 	
// }
// /*
function content($page)
{

	$mapSettings = array();
	$mapSettings[0] = "-c -l 25 -k 2 -n 10";
	$mapSettings[1] = "-c -l 25 -k 2 -n 5";
	$mapSettings[2] = "-c -l 25 -k 1 -n 10";
	$mapSettings[3] = "-c -l 25 -k 1 -n 5";
	$mapSettings[4] = "-c -l 10 -k 2 -n 10";
	$mapSettings[5] = "-c -l 10 -k 2 -n 5";

	$alignmentTool = array();
	$alignmentTool[0] = 'BWA';

	$galaxy = '';
	
	if (isset($_REQUEST['GALAXY_URL'])) {$galaxy= $_REQUEST['GALAXY_URL'];}

	$content = '';


	switch ($page){
			case "saving":
				$content = saving($mapSettings, $alignmentTool, $galaxy);
			break;
	}


	return $content;
}

function saving($mapSettings, $alignmentTool, $galaxy)
{

	$content = '';

	$tmpFolder = tempnam('/tmp', 'SAP42');

	$pwd = $_POST["pwd"];
	$email = $_POST["userEmail"];

	$file = fopen("data.txt", "r") or exit("Unable to open file!");

	$selected_datasets = array();

	while(!feof($file))
	{
		$line = fgets($file);
		$line = chop($line);

		$currentLine = split("\t", $line);

		$csfasta[$currentLine[0]][0] = $currentLine[1];
		$csfasta[$currentLine[0]][1] = $currentLine[2];
		$csfasta[$currentLine[0]][2] = $currentLine[3];
		$csfasta[$currentLine[0]][3] = $currentLine[4];

		if(isset($_POST['data_' . $currentLine[0]])){
			array_push($selected_datasets, $currentLine[0]);
		}

	}
	fclose($file);

	$file = fopen("reference.txt", "r") or exit("Unable to open file!");
	//Output a line of the file until the end is reached

	$ref = array();

	while(!feof($file))
	{
		$line = fgets($file);
		$line = chop($line);
		$currentLine = split("\t", $line);

		$ref[$currentLine[0]] = $currentLine[2];

	}
	fclose($file);

	system("rm -f $tmpFolder");
	system("mkdir $tmpFolder");
	system("chmod 777 $tmpFolder");

	$aData = $_POST['data'];

// 	$fp = fopen("$tmpFolder/command.sh", 'w');
// 	fwrite( $fp, "#!/bin/sh\n\n" );

	$info = '';

	foreach($selected_datasets as $value) {


		$selected_reference = $_POST["ref_$value"];
		$selected_tool = $_POST["t_$value"];
		$selected_settings = $_POST["s_$value"];
		$selected_name = $_POST["n_$value"];

		$quality = str_replace(".csfasta", ".qual", $csfasta[$value][3]);

		$quality = preg_replace("/^(.+)_F3/", "$1_F3_QV", $quality);

		$mapSettings[$selected_settings] = str_replace(" ", ",", $mapSettings[$selected_settings]);

		$command = "perl SAP42_create.pl -A "  . $alignmentTool[$selected_tool] . " ";
		$command .= " -p $selected_name -r $selected_reference -f $pwd/" . $selected_name . " -o $tmpFolder ";
		$command .= " -q $quality -c ". $csfasta[$value][3];
		$command .= " -a '" . $mapSettings[$selected_settings] . "' ";

		
		$command .= " -e $email ";

// 		fwrite( $fp, "$command >> command.out 2> command.log\n\n\n" );
		
		$info .= "#SAP42 configuration\n";
		
			$info .= "#general information\n";
			$info .= "NAME\t" . $selected_name . "\n\n";
			
			$info .= "#location of the csfasta and quality files\n";
			$info .= "CSFASTA\t" . $csfasta[$value][3] . "\n";
			$info .= "QUAL\t" . $quality . "\n\n";
		
			$info .= "READS\tX\n\n";
			
			$info .= "#working directory\n";
			$info .= "PWD\t$pwd/$selected_name/\n\n";
			
			$info .= "#splitting\n";
			$info .= "SPLITS\t0\n\n";
			
			$info .= "#reference genome\n";
			$info .= "REFERENCE\t" . $ref[$selected_reference] . "\n\n";
			
			$info .= "#aligment program\n";
			$info .= "ALNPROM\t" . $alignmentTool[$selected_tool] . "\n";
			$info .= "ALNARG\t" . $mapSettings[$selected_settings] . "\n\n";
		
			$info .= "EMAIL\t" . $email . "\n\n";
			
			$info .= "#make logfile with status...\n\n";
		
			$info .= "SVN\tX\n\n";


		$output = system("$command > /dev/null");

// 		$content .=  "<pre>" . $output . "</pre>\n";

// 		$content .= "<br />$command\n\n<br /><br /><br />";
// 		$content .=  system("touch $tmpFolder/test.txt");

	}
	fclose($fp);
// 	$content .= "Configuration files have been stored to <h4>$tmpFolder</h4>";

// 	$content .= "Execute the following command on fedor8:";

	$code = str_replace("/tmp/", "", $tmpFolder);

	$content .= $info;


	return $content;
}



?>