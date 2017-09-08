<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
	<head>
		<title>
			SAP42-DX-HPC - Sequence Alignment Pipeline
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
#	$body .= "\t\t<img class=\"logo\" src=\"img/LogoRGBlr.png\" alt=\"Hubrecht Institute Logo\" />\n\t\tSAP42\n";
// 	$body .= "\t\t<div class=\"sap42\">\n\t\t</div>\n";
#	$body .= "\t\t<img class=\"versionlogo\" src=\"img/version.png\" alt=\"Hubrecht Institute Logo\" />\n";
$body .= "\t</div><!-- end of header div-->\n";
$body .= "\t<div class=\"headerline\">\n\t</div><!-- end of headerline div-->\n";

$body .= "\t<div class=\"menu\">\n";

// 	$body .= "<table>";
// 		$body .= "<tr>";
// 			$body .= "<td>";
// 			$body .= $page;
// 			$body .= "<td>";
// 		$body .= "</tr>";
// 	$body .= "</table>";

$body .= "\t</div><!-- end of menu div-->\n";

$body .= "\t<div class=\"content\">\n";
$body .= content($page);
$body .= "\t</div><!-- end of content div-->\n";
$body .= "</div><!-- end of container div-->\n\n";


echo $body;


function content($page)
{
	$content = '';

	$content .= "<div class='startmappingfloat'><a href='pipelineFQ.php'>Start mapping Illumina data here</a></div>";

	$content .= "<div class='startmappingfloat'><a href='pipeline5500.php'>Start mapping 5500 data here</a></div>";

	$content .= "<div class='startmappingfloat'><a href='pipelineXSQ.php'>Start mapping from XSQ here</a></div>";

	$content .= "<div class='startmapping'><a href='variants.php'>Start variant (BAM selection) calling here</a></div>";

	$content .= "<div class='startmappingfloat'><a href='variantsLine.php'>Start variant calling here</a></div>";

	$content .= "<div class='startmappingfloat'><a href='variantsettings.php'>Variant caller settings</a></div>";

	$content .= "<div class='startmapping'><a href='design.php'>Manage design files</a></div>";

	$content .= "<div class='startmappingfloat'><a href='reference.php'>Manage references</a></div>";

	$content .= "<div class='startmappingfloat'><a href='external.php'>Manage external datasets</a></div>";

	return $content;
}



?>

</body>
</html>