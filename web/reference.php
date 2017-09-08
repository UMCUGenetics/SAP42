<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
	<head>
		<title>
			SAP42-DX-HPC Sequence Alignment Pipeline
		</title>
		<link rel="stylesheet" type="text/css" href="style/style.css" />
	</head>
	<body>

<?php

// error_reporting(E_ALL);
// ini_set("display_errors", 1);

# DO THIS SHIT: 

$page = '';

if (isset($_REQUEST['page'])) {$page= $_REQUEST['page'];}

$body = "";

$body .= "<div class=\"container\">\n";
$body .= "\t<div class=\"header\">\n";
	$body .= "\t\t<img class=\"logo\" src=\"img/LogoRGBlr.png\" alt=\"Hubrecht Institute Logo\" />\n\t\tSAP42\n";
// 	$body .= "\t\t<div class=\"sap42\">\n\t\t</div>\n";
	$body .= "\t\t<img class=\"versionlogo\" src=\"img/version.png\" alt=\"Hubrecht Institute Logo\" />\n";
$body .= "\t</div><!-- end of header div-->\n";
$body .= "\t<div class=\"headerline\">\n\t</div><!-- end of headerline div-->\n";

$body .= "\t<div class=\"menu\">\n";

$body .= "\t</div><!-- end of menu div-->\n";

$body .= "\t<div class=\"content\">\n";
$body .= content($page);
$body .= "\t</div><!-- end of content div-->\n";
$body .= "</div><!-- end of container div-->\n\n";


echo $body;

$page = '';

if (isset($_REQUEST['page'])) {$page= $_REQUEST['page'];}


function content($page)
{
	$content = '';

	$content .= "<div class='startmappingfloat'><a href='reference.php?page=add'>Add temporaly reference</a></div>";

	$content .= "<div class='startmappingfloat'><a href='reference.php?page=edit'>Change temporaly reference</a></div>";

	$content .= "<div class='startmappingfloat'><a href='reference.php?page=ignore'>Modify reference ignore list</a></div>";

	$content .= "<div class='startmapping'><a href='index.php'>Back</a></div>";

	switch ($page){
		case "add":
		$content = add();
		break;
		case "edit":
			$content = edit();
		break;
		case "save_add":
			$content = save();
		break;
		case "save_edit":
			$content = store();
		break;
		case "ignore":
			$content = ignore();
		break;
		case "save_ignore":
			$content = save_ignore();
		break;

		default:

// 		$content = selectExperiments($galaxy);
	}

	return $content;
}

function ignore(){
	if (!file_exists("reference.ignore.txt")){
		$file = fopen("reference.ignore.txt", "w");
		close($file);
	}

	$file = fopen("reference.ignore.txt", "r") or exit("Unable to open file!");

	$ref_ignore = array();

	while(!feof($file))
	{
		$line = fgets($file);
		$line = chop($line);
		$ref_ignore[$line] = 1;
	}

	fclose($file);

	$content .= "<form acton='' method='post'>\n";

	$content .= "<input type='hidden' name='page' value='save_ignore'>\n";

	$file = fopen("reference.txt", "r") or exit("Unable to open file!");

	$content .= "<table>\n";

	$content .= "<tr><th>\n";

	$content .= "Name\n";

	$content .= "</th><th>\n";

	$content .= "Path\n";

	$content .= "</th><th>\n";

	$content .= "Ignore\n";

	$content .= "</th></tr>\n";

	while(!feof($file))
	{

		$content .= "<tr><td>\n";

		$line = fgets($file);
		$line = chop($line);

		$currentLine = split("\t", $line);

		if (count($currentLine) < 2){
			continue;
		}

		$content .= $currentLine[1];

		$content .= "</td><td>\n";

		$content .= $currentLine[2];

		$content .= "</td><td>\n";

		if (array_key_exists($currentLine[2],$ref_ignore)){
			$content .= "<input type=\"checkbox\" name=\"ignore[ ]\" value=\"$currentLine[2]\" checked=\"yes\" />";
		}else{
			$content .= "<input type=\"checkbox\" name=\"ignore[ ]\" value=\"$currentLine[2]\" />";
		}

		$content .= "</td></tr>\n";
	}

	$content .= "</table>\n";

	$content .= "<input type='submit' />\n";

	$content .= "</form>\n";

	fclose($file);

	return $content;
}

function add()
{
	$content = '';

	if (!file_exists("reference.tmp.txt")){
		touch("reference.tmp.txt");
	}

	$file = fopen("reference.tmp.txt", "r") or exit("Unable to open file!");

	$ref = array();

	$content .= "<form acton='' method='post'>\n";

	$content .= "<input type='hidden' name='page' value='save_add'>\n";

	$content .= "<table>\n";

	$last_id = 'a';

		$content .= "<tr><th>\n";

		$content .= "Name\n";

		$content .= "</th><th>\n";

		$content .= "Path\n";

		$content .= "</th></tr>\n";


	while(!feof($file))
	{

		$content .= "<tr><td>\n";

		$line = fgets($file);
		$line = chop($line);
		$currentLine = split("\t", $line);

		if (count($currentLine) < 2){
			continue;
		}

		$last_id = $currentLine[0];

		$content .= $currentLine[1];

		$content .= "</td><td>\n";

		$content .= $currentLine[2];

		$content .= "</td></tr>\n";

	}

		$new_id = ++$last_id;

		$content .= "<input type='hidden' name='id[ ]' value='$new_id'>\n";

		$content .= "<tr><td>\n";

		$content .= "<input type='text' name='name[ ]'/>\n";

		$content .= "</td><td>\n";

		$content .= "<input type='text' name='path[ ] ' size='100' />\n";

		$content .= "</td></tr>\n";


	$content .= "</table>\n";

	$content .= "<input type='submit' />\n";

	$content .= "</form>\n";

	fclose($file);


	return $content;

}

function edit()
{
	$content = '';

	if (!file_exists("reference.tmp.txt")){
		touch("reference.tmp.txt");
	}

	$file = fopen("reference.tmp.txt", "r") or exit("Unable to open file!");

	$ref = array();

	$content .= "<form acton='' method='post'>\n";

	$content .= "<input type='hidden' name='page' value='save_edit'>\n";

	$content .= "<table>\n";

	$last_id = 'a';

		$content .= "<tr><th>\n";

		$content .= "Name\n";

		$content .= "</th><th>\n";

		$content .= "Path\n";

		$content .= "</th></tr>\n";


	while(!feof($file))
	{

		$content .= "<tr><td>\n";

		$line = fgets($file);
		$line = chop($line);
		$currentLine = split("\t", $line);

		if (count($currentLine) < 2){
			continue;
		}

		$content .= "</td><td>\n";

		$content .= "<input type='hidden' name='id[ ]' value='" . $currentLine[0] . "'/>\n";

		$content .= "<tr><td>\n";

		$content .= "<input type='text' name='name[ ]' value='" . $currentLine[1] . "'/>\n";

		$content .= "</td><td>\n";

		$content .= "<input type='text' name='path[ ]' value='" . $currentLine[2] . "' size='100' />\n";

		$content .= "</td></tr>\n";

	}

	$content .= "</table>\n";

	$content .= "<input type='submit' />\n";

	$content .= "</form>\n";

	fclose($file);


	return $content;

}

function save_ignore() 
{
	$content = '';

	$ignore_list = $_POST['ignore'];

	$file = fopen("reference.ignore.txt", "w") or exit("Unable to save to file!");

	$content .= "The following references will be ignored:<br /><br />";

	foreach($ignore_list as $value) {
		fwrite($file, $value . "\n");

		$content .= "$value<br />";
	}

	$content .= "<div class='startmapping'><a href='index.php'>Back</a></div>";

	return $content;
}

function save()
{
	$content = '';

	$file = fopen("reference.tmp.txt", "a") or exit("Unable to save to file!");

	$aid = $_POST['id'];
	$aname = $_POST['name'];
	$apath = $_POST['path'];

	for($i=0;$i<count($aid);$i++){


		fwrite($file, $aid[$i] . "\t" . $aname[$i] . "\t" . $apath[$i] .  "\n");

	}

	$content .= "Saving done <br /><br />";

	$content .= "<div class='startmapping'><a href='index.php'>Back</a></div>";

	return $content;
}

function store()
{
	$content = '';

	$file = fopen("reference.tmp.txt", "w") or exit("Unable to save to file!");

	$aid = $_POST['id'];
	$aname = $_POST['name'];
	$apath = $_POST['path'];

	for($i=0;$i<count($aid);$i++){


		fwrite($file, $aid[$i] . "\t" . $aname[$i] . "\t" . $apath[$i] .  "\n");

	}

	$content .= "Saving done <br /><br />";

	$content .= "<div class='startmapping'><a href='index.php'>Back</a></div>";

	return $content;
}





?>

</body>
</html>