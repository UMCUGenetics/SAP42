<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
	<head>
		<title>
			VAP42-DX-HPC Variant Analysis Pipeline
		</title>
		<link rel="stylesheet" type="text/css" href="style/style.css" />
	</head>
	<body>

<script type="text/javascript">

function fileBrowser(dir, file, div)
{
var xmlhttp;
if (window.XMLHttpRequest)
  {// code for IE7+, Firefox, Chrome, Opera, Safari
  xmlhttp=new XMLHttpRequest();
  }
else
  {// code for IE6, IE5
  xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
  }
xmlhttp.onreadystatechange=function()
  {
  if (xmlhttp.readyState==4 && xmlhttp.status==200)
    {
    document.body.style.cursor = "default";
    document.getElementById(div).innerHTML=xmlhttp.responseText;
    }
  }
document.body.style.cursor = "wait";
xmlhttp.open("GET","/cgi-bin/file.cgi?dir=" + dir + "&file=" + file,true);
xmlhttp.send();
}

function VariantSettings (selectbox){

	var settingsArray = selectbox.value.split(' ');

	for (i=0;i<=settingsArray.length;i=i+2){

		var settingname = settingsArray[i].substring(1);
		var settingbox = document.getElementsByName(settingname);

		if ((settingsArray[i+1] == "yes") || (settingsArray[i+1] == "Yes")){
			settingbox[0].selectedIndex = 0;
		}

		if ((settingsArray[i+1] == "no") || (settingsArray[i+1] == "No")){
			settingbox[0].selectedIndex = 1;
		}


		settingbox[0].value = settingsArray[i+1];
	}
}

function open_or_close_folder (div){

	var father = div.parentNode;
	father = father.parentNode;
	var children = father.childNodes;

	for(var i = 0 ; i < children.length;i++){
		if (children[i].id == "folder"){

			if (children[i].style.display == "inline"){
				children[i].style.display = "none";
			}else{
				children[i].style.display = "inline";

			}
		}
	}
}

function select_all (div){

	var father = div.parentNode;
	father = father.parentNode;
	

	var children = father.getElementsByTagName('input');

	for(var i = 0 ; i < children.length;i++){
// 		if (children[i].id == "folder"){

// 		alert(children[i].checked);

		children[i].checked = true;


// 		}
	}


}

function expand_all (div){

	var father = div.parentNode;
	father = father.parentNode;
	

	var children = father.getElementsByTagName('div');

	for(var i = 0 ; i < children.length;i++){
		if (children[i].id == "folder"){


		children[i].style.display = "inline";

		}
	}
}



</script>

<?php

// error_reporting(E_ALL);
// ini_set("display_errors", 1);

# DO THIS SHIT: 

$page = '';

if (isset($_REQUEST['page'])) {$page= $_REQUEST['page'];}

$body = '';

$body .= "<div class=\"container\">\n";
$body .= "\t<div class=\"header\">\n";
	$body .= "\t\t<img class=\"logo\" src=\"img/LogoRGBlr.png\" alt=\"Hubrecht Institute Logo\" />\n\t\tVAP42\n";
// 	$body .= "\t\t<div class=\"sap42\">\n\t\t</div>\n";
	$body .= "\t\t<img class=\"versionlogo\" src=\"img/version.png\" alt=\"Hubrecht Institute Logo\" />\n";
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
// 	$mapSettings[4] = "-c -l 10 -k 2 -n 10";
// 	$mapSettings[5] = "-c -l 10 -k 2 -n 5";
// 	$mapSettings[6] = "-c -l 25 -k 3 -n 10";
// 	$mapSettings[7] = "-c -l 25 -k 3 -n 10";

	$alignmentTool = array();
	$alignmentTool[0] = 'BWA';

	$galaxy = '';
	
	if (isset($_REQUEST['GALAXY_URL'])) {$galaxy= $_REQUEST['GALAXY_URL'];}

	$content = '';

	switch ($page){
                        case "new":
                                $content = "";
                        break;
                        case "selectBams":
                                $content = selectBams($galaxy);
                        break;
                        case "settings":
                                $content = settings($galaxy);
                        break;
// 			case "mapping":
// 				$content = mapping($mapSettings, $alignmentTool, $galaxy);
// 			break;
			case "saving":
				$content = settings($galaxy);
			break;
			case "really_saving":
				$content = saving($mapSettings, $alignmentTool, $galaxy);
			break;
                        default:

			$content = selectBams($galaxy);
	}

	return $content;
}

function settings($galaxy)
{

// 	echo $_POST['pwd'];

	$content = '';

	$content .= "<form>\n";
	$content .= "Prestored variantsettings: <select id='variantsettings' OnChange=\"javascript:VariantSettings(this);\">";

	$content .= "<option value='Select'>Select</option>\n";

	$file = fopen("variantsettings.txt", "r") or exit("Unable to open file!");

	while(!feof($file))
	{
		$line = fgets($file);
		$line = chop($line);

		$splitLine = split("\t", $line);

		$content .= "<option value='" . $splitLine[2] . "'>" . $splitLine[1] . "</option>\n";

	}

	$content .= "</select>\n";
	$content .= "</form>\n";

	$aData = $_POST['data'];
	$aBam = $_POST['bam'];

	$platform = '';

	if (isset($_POST['platform'])){
		$platform = $_POST['platform'];
	}

// 	$content = $aData;
// 	echo $aData;

	$csfasta = array(array());

	if (strcmp($galaxy,'') != 0){
		$content .= "<form id=\"mapping_form\" action=\"$galaxy\" method=\"POST\">\n";
		$galaxy_tool_id = $_REQUEST['tool_id'];
		$content .= "<input type=\"hidden\" name=\"tool_id\" value=\"$galaxy_tool_id\" />\n\n";
		echo "GALAXY\n";
	}else{
		$content .= "<form action=\"variants.php\" method=\"POST\">\n";
// 		echo "NO GALAXY\n";
	}

	$content .= "<input type=\"hidden\" name=\"page\" value=\"really_saving\" />\n";
	$content .= "<input type=\"hidden\" name=\"platform\" value=\"$platform\" />\n";

	$datafile = 'data.txt';

	if ($platform === '5500'){
		$datafile = 'data5500.txt';
	}


	$file = fopen($datafile, "r") or exit("Unable to open file!");
	while(!feof($file))
	{
		$line = fgets($file);

		$currentLine = split("\t", $line);

		$csfasta[$currentLine[0]][0] = $currentLine[1];
		$csfasta[$currentLine[0]][1] = $currentLine[2];
		$csfasta[$currentLine[0]][2] = $currentLine[3];
		$csfasta[$currentLine[0]][3] = $currentLine[4];

	}

	fclose($file);

	$file = fopen("reference.txt", "r") or exit("Unable to open file!");
	//Output a line of the file until the end is reached

	$ref = array();

	while(!feof($file))
	{
		$line = fgets($file);
		$currentLine = split("\t", $line);

		$ref[$currentLine[0]] = $currentLine[1];

	}
	fclose($file);

	$file = fopen("reference.tmp.txt", "r") or exit("Unable to open file!");

	while(!feof($file))
	{
		$line = fgets($file);
		$currentLine = split("\t", $line);

		$ref[$currentLine[0]] = $currentLine[1];

	}
	fclose($file);

	$selected_reference = $_POST["ref_" . $aData[0]];

	if (isset ($_REQUEST['reffy'])){
		$selected_reference = $_REQUEST['reffy']; 
// 		$content .= "Reference:$selected_reference";
		$content .= "<input type=\"hidden\" name=\"reffy\" value=\"$selected_reference\" />";
	}
	
	if (isset ($_REQUEST['SPRE'])) {$content .= "<input type=\"hidden\" name=\"SPRE\" value=\"yes\" />";}
	if (isset ($_REQUEST['SPOST'])) {$content .= "<input type=\"hidden\" name=\"SPOST\" value=\"yes\" />";}

	$content .= "<input type=\"hidden\" name=\"pwd\" value=\"" . $_REQUEST['pwd'] . "\" />";
	$content .= "<input type=\"hidden\" name=\"design\" value=\"" . $_REQUEST['design'] . "\" />";
	$content .= "<input type=\"hidden\" name=\"email\" value=\"" . $_REQUEST['email'] . "\" />";
	$content .= "<input type=\"hidden\" name=\"priority\" value=\"" . $_REQUEST['priority'] . "\" />";
	$content .= "<input type=\"hidden\" name=\"responible\" value=\"" . $_REQUEST['responible'] . "\" />";

	$bamCounter = -1;

	foreach($aBam as $value) {

		$bamCounter = $bamCounter + 1;

		if (strcmp($galaxy,'') != 0){
			$content .= "<input type=\"hidden\" name=\"bam_$bamCounter\" value=\"$value\">\n";
		}else{
			$content .= "<input type=\"hidden\" name=\"bam[ ]\" value=\"$value\">\n";
		}
		$content .= "<input type=\"hidden\" name=\"n_$value\" value=\"$selected_name\">\n";
		$content .= "<input type=\"hidden\" name=\"ref_$value\" value=\"$selected_reference\">\n";
		$content .= "<input type=\"hidden\" name=\"t_$value\" value=\"$selected_tool\">\n";
		$content .= "<input type=\"hidden\" name=\"s_$value\" value=\"$selected_settings\">\n";
	}

	foreach($aData as $value) {
		$selected_reference = $_POST["ref_$value"];
		$selected_tool = $_POST["t_$value"];
		$selected_settings = $_POST["s_$value"];
		$selected_name = $_POST["n_$value"];

		if (strcmp($galaxy,'') != 0){
			$content .= "<input type=\"hidden\" name=\"data_$value\" value=\"$value\">\n";
		}else{
			$content .= "<input type=\"hidden\" name=\"data[ ]\" value=\"$value\">\n";
		}
		$content .= "<input type=\"hidden\" name=\"n_$value\" value=\"$selected_name\">\n";
		$content .= "<input type=\"hidden\" name=\"ref_$value\" value=\"$selected_reference\">\n";
		$content .= "<input type=\"hidden\" name=\"t_$value\" value=\"$selected_tool\">\n";
		$content .= "<input type=\"hidden\" name=\"s_$value\" value=\"$selected_settings\">\n";
	}

	$content .= "<input type=\"hidden\" name=\"name\" value=\"" . $_REQUEST['name'] . "\">\n";

	$content .= "<table>";

	$content .= "<tr>";
	$content .= "<td colspan=\"2\">";
	$content .= "<hr />";
	$content .= "<b>General</b>";
	$content .= "</td>";
	$content .= "</tr>";

	$content .= "<tr>";
	$content .= "<td>";
	$content .= "Overwrite previous results (if any)";
	$content .= "</td>";
	$content .= "<td>";
	$content .= "<select name=\"force\">";
	$content .= "<option value=\"Yes\">Yes</option>";
	$content .= "<option value=\"No\">No</option>";
	$content .= "</select>";
	$content .= "</td>";
	$content .= "</tr>";

	$content .= "<tr>";
	$content .= "<td>";
	$content .= "Call SNPs";
	$content .= "</td>";
	$content .= "<td>";
	$content .= "<select name=\"snps\">";
	$content .= "<option value=\"Yes\">Yes</option>";
	$content .= "<option value=\"No\">No</option>";
	$content .= "</select>";
	$content .= "</td>";
	$content .= "</tr>";

	$content .= "<tr>";
	$content .= "<td>";
	$content .= "Call indels";
	$content .= "</td>";
	$content .= "<td>";
	$content .= "<select name=\"indels\">";
	$content .= "<option value=\"Yes\">Yes</option>";
	$content .= "<option value=\"No\">No</option>";
	$content .= "</select>";
	$content .= "</td>";
	$content .= "</tr>";

	$content .= "<tr>";
	$content .= "<td>";
	$content .= "Download pileups";
	$content .= "</td>";
	$content .= "<td>";
	$content .= "<select name=\"pileup\">";
	$content .= "<option value=\"Yes\">Yes</option>";
	$content .= "<option value=\"No\" selected=\"selected\">No</option>";
	$content .= "</select>";
	$content .= "</td>";
	$content .= "</tr>";

	$content .= "<tr>";
	$content .= "<td>";
	$content .= "Full pileups";
	$content .= "</td>";
	$content .= "<td>";
	$content .= "<select name=\"fullpileup\">";
	$content .= "<option value=\"Yes\">Yes</option>";
	$content .= "<option value=\"No\" selected=\"selected\">No</option>";
	$content .= "</select>";
	$content .= "</td>";
	$content .= "</tr>";

	$content .= "<tr>";
	$content .= "<td>";
	$content .= "Species";
	$content .= "</td>";
	$content .= "<td>";
	$content .= "<select name=\"species\">";

	$content .= "<option value=\"Rattus_norvegicus\">Rat (R.Novegicus)</option>";
	$content .= "<option value=\"Danio_rerio\">Zebrafish (D.rerio)</option>";
	
	$content .= "<option value=\"Bos_taurus\">Cow (B.taurus)</option>";
	$content .= "<option value=\"Canis_familiaris\">Dog (C.familiaris)</option>";
	$content .= "<option value=\"Homo_sapiens\">Human (H.sapiens)</option>";
	$content .= "<option value=\"Mus_musculus\">Mouse (M.musculus)</option>";
	
	$content .= "<option value=\"Drosphila_melanogaster\">Fruitfly (D.melanogaster)</option>";
	$content .= "<option value=\"Equus_caballus\">Horse (E.caballus)</option>";
	$content .= "<option value=\"Felis_catus\">Cat (F.cattus)</option>";
	$content .= "<option value=\"Gallus_gallus\">Chicken (G.gallus)</option>";
	$content .= "<option value=\"Monodelphis_domestica\">Opossum (M.domestica)</option>";
	$content .= "<option value=\"Ornithorhynchus_anatinus\">Platypus (O.anatinus)</option>";
	$content .= "<option value=\"Pan_troglodites\">Chimpanzee (P.troglodytes)</option>";
	$content .= "<option value=\"Pongo_pygmaesu\">Orangutan (P.pygmaesu)</option>";
	$content .= "<option value=\"Saccharomyces_cerevisiae\">Saccharomyces cerevisiae</option>";
	$content .= "<option value=\"Sus_scrofa\">Pig (S.scofa)</option>";
	$content .= "<option value=\"Taeniopygia_guttata\">Zebra Finch (F.gutta)</option>";
	$content .= "<option value=\"Tetraodon_nigroviridis\">Tetradon (T.nigroviridis)</option>";

	$content .= "</select>";
	$content .= "</td>";
	$content .= "</tr>";

	$content .= "<tr>";
	$content .= "<td>";
	$content .= "Predict effects";
	$content .= "</td>";
	$content .= "<td>";
	$content .= "<select name=\"effects\">";
	$content .= "<option value=\"Yes\">Yes</option>";
	$content .= "<option value=\"No\">No</option>";
	$content .= "</select>";
	$content .= "</td>";
	$content .= "</tr>";

	$content .= "<tr>";
	$content .= "<td colspan=\"2\">";
	$content .= "<hr />";
	$content .= "<b>Pooperscooper</b>";
	$content .= "</td>";
	$content .= "</tr>";

	$content .= "<tr>";
	$content .= "<td>";
	$content .= "miminum coverage";
	$content .= "</td>";
	$content .= "<td>";
	$content .= "<input type=\"text\" name=\"c\" value=\"20\">";
	$content .= "</td>";
	$content .= "</tr>";

	$content .= "<tr>";
	$content .= "<td>";
	$content .= "maximum coverage";
	$content .= "</td>";
	$content .= "<td>";
	$content .= "<input type=\"text\" name=\"mc\" value=\"2000\">";
	$content .= "</td>";
	$content .= "</tr>";

	$content .= "<tr>";
	$content .= "<td colspan=\"2\">";
	$content .= "<hr />";
	$content .= "<b>Call Filtering</b>";
	$content .= "</td>";
	$content .= "</tr>";

	$content .= "<tr>";
	$content .= "<td>";
	$content .= "remove low quality calls";
	$content .= "</td>";
	$content .= "<td>";
	$content .= "<select name=\"rlq\">";
	$content .= "<option value=\"Yes\">Yes</option>";
	$content .= "<option value=\"No\">No</option>";
	$content .= "</select>";
	$content .= "</td>";
	$content .= "</tr>";

	$content .= "<tr>";
	$content .= "<td>";
	$content .= "remove call with quality equal or lower";
	$content .= "</td>";
	$content .= "<td>";
	$content .= "<input type=\"text\" name=\"q\" value=\"10\">";
	$content .= "</td>";
	$content .= "</tr>";

	$content .= "<tr>";
	$content .= "<td>";
	$content .= "Only unique calls";
	$content .= "</td>";
	$content .= "<td>";
	$content .= "<select name=\"ouc\">";
	$content .= "<option value=\"Yes\">Yes</option>";
	$content .= "<option value=\"No\">No</option>";
	$content .= "</select>";
	$content .= "</td>";
	$content .= "</tr>";

// 	$content .= "<tr>";
// 	$content .= "<td>";
// 	$content .= "remove clonal calls";
// 	$content .= "</td>";
// 	$content .= "<td>";
// 	$content .= "<select name=\"rc\">";
// 	$content .= "<option value=\"Yes\">Yes</option>";
// 	$content .= "<option value=\"No\">No</option>";
// 	$content .= "</select>";
// 	$content .= "</td>";
// 	$content .= "</tr>";

	$content .= "<tr>";
	$content .= "<td>";
	$content .= "Clonality level, remove calls that are above clonality level";
	$content .= "</td>";
	$content .= "<td>";
	$content .= "<input type=\"text\" name=\"cl\" value=\"5\">";
	$content .= "</td>";
	$content .= "</tr>";

	$content .= "<tr>";
	$content .= "<td colspan=\"2\">";
	$content .= "<hr />";
	$content .= "<b>Allele selection</b>";
	$content .= "</td>";
	$content .= "</tr>";

	$content .= "<tr>";
	$content .= "<td>";
	$content .= "Strand balance, 0 to disable";
	$content .= "</td>";
	$content .= "<td>";
	$content .= "<input type=\"text\" name=\"sb\" value=\"0.1\">";
	$content .= "</td>";
	$content .= "</tr>";

	$content .= "<tr>";
	$content .= "<td>";
	$content .= "Number of seed calls supporting the variant";
	$content .= "</td>";
	$content .= "<td>";
	$content .= "<input type=\"text\" name=\"seed\" value=\"4\">";
	$content .= "</td>";
	$content .= "</tr>";

	$content .= "<tr>";
	$content .= "<td>";
	$content .= "Noise level: calls with lower than this number of coverage will be removed";
	$content .= "</td>";
	$content .= "<td>";
	$content .= "<input type=\"text\" name=\"d\" value=\"3\">";
	$content .= "</td>";
	$content .= "</tr>";

	$content .= "<tr>";
	$content .= "<td>";
	$content .= "Minimum independend start sites. Remove allele if not supported by this number of start sites";
	$content .= "</td>";
	$content .= "<td>";
	$content .= "<input type=\"text\" name=\"ss\" value=\"3\">";
	$content .= "</td>";
	$content .= "</tr>";

	$content .= "<tr>";
	$content .= "<td>";
	$content .= "mininal percentage non reference";
	$content .= "</td>";
	$content .= "<td>";
	$content .= "<input type=\"text\" name=\"pnr\" value=\"20\">";
	$content .= "</td>";
	$content .= "</tr>";

	$content .= "<tr>";
	$content .= "<td>";
	$content .= "mininal percentage reference";
	$content .= "</td>";
	$content .= "<td>";
	$content .= "<input type=\"text\" name=\"pr\" value=\"0\">";
	$content .= "</td>";
	$content .= "</tr>";

	$content .= "<tr>";
	$content .= "<td>";
	$content .= "Minimal percentage non reference when call is considered homozygous";
	$content .= "</td>";
	$content .= "<td>";
	$content .= "<input type=\"text\" name=\"hom\" value=\"75\">";
	$content .= "</td>";
	$content .= "</tr>";

	$content .= "<tr>";
	$content .= "<td>";
	$content .= "Maximum number of alleles";
	$content .= "</td>";
	$content .= "<td>";
	$content .= "<input type=\"text\" name=\"mac\" value=\"4\">";
	$content .= "</td>";
	$content .= "</tr>";

	$content .= "<tr>";
	$content .= "<td colspan=\"2\">";
	$content .= "<hr />";
	$content .= "</td>";
	$content .= "</tr>";

	$content .= "</table>";
	$content .= "<input type=\"submit\" value=\"Submit\">";

	$content .= "</form>";


	return $content;
}

function selectBams($galaxy)
{
	$content = '';
// 	$file = fopen("bams.txt", "r") or exit("Unable to open file!");

	$content .= "<br />";
	$content .= "<br />";

	$content .= "<hr />";
	$content .= "<form action=\"\" method=\"POST\">\n";
	$content .= "<input type=\"hidden\" name=\"page\" value=\"settings\">";
	$content .= "BAM file location:<br />";
	$content .= "<input name=\"bam[ ]\" type=\"text\">";

	$content .= "<div class='otherinfo'>";

	$content .= "<hr />";

	$content .= "Email adress:<br />";

	$content .= "<input type=\"text\" name=\"email\" value=\"\"><br /><br />";

	$reference = '';

	$content .= "<hr />";

	$content .= "Reference:<br />";


	$file = fopen("reference.ignore.txt", "r") or exit("Unable to open file!");

	$ref_ignore = array();

	while(!feof($file))
	{
		$line = fgets($file);
		$line = chop($line);
		$ref_ignore[$line] = 1;
	}

	$file = fopen("reference.txt", "r") or exit("Unable to open file!");
	//Output a line of the file until the end is reached

	$content .= "<div id =\"info\" class=\"info\"></div>";

	$hidden_content = "";

	while(!feof($file))
	{
		$line = fgets($file);
		$line = chop($line);
		$currentLine = split("\t", $line);

		#ignore ignored references
		if (array_key_exists($currentLine[2],$ref_ignore)){
			continue;
		}


// 		if (($reference_id === $currentLine[1]) && (strlen($reference_id) > 0)){
			
// 			$reference .= "<option selected=\"selected\" value=\"" . $currentLine[0] . "\">" . $currentLine[1] . "</option>\n";
// 		}else{
			$reference .= "<option value=\"" . $currentLine[0] . "\">" . $currentLine[1] . "</option>\n";
// 			$hidden_content .= "<input type=\"hidden\" id=\"info" . $currentLine[0] . "\" value=\"" . $currentLine[2] . "\">\n";
// 		}
	}
	fclose($file);

	$file = fopen("reference.tmp.txt", "r") or exit("Unable to open file!");

	while(!feof($file))
	{
		$line = fgets($file);
		$currentLine = split("\t", $line);
// 		if (($reference_id === $currentLine[1]) && (strlen($reference_id) > 0)){
			
// 			$reference .= "<option selected=\"selected\" value=\"" . $currentLine[0] . "\">" . $currentLine[1] . "</option>\n";
// 		}else{
			$reference .= "<option value=\"" . $currentLine[0] . "\">" . $currentLine[1] . "</option>\n";
// 			$hidden_content .= "<input type=\"hidden\" id=\"info" . $currentLine[0] . "\" value=\"" . $currentLine[2] . "\">\n";
// 		}
	}
	fclose($file);


	$content .= "</td><td><select name=\"reffy\" id=\"reference\">$reference</select></td><br />";

	$content .= "<hr />";

	$content .= "Priority:<br />";
	
	$content .= "<select name=\"priority\">";
	$content .= "<option value=\"-200\">Extreme Low (-200)</option>";
	$content .= "<option value=\"-100\">Low (-100)</option>";
	$content .= "<option value=\"0\" selected=\"selected\">Normal (0)</option>";
	$content .= "<option value=\"100\">High (100)</option>";
	$content .= "<option value=\"200\">Extreme High (200)</option>";
	$content .= "</select>";

	$content .= "<hr />";

	$content .= "<input type=\"submit\" value=\"Go\">";

	$content .= "<input type=\"reset\" value=\"Clear\">";

	$content .= "</div>";

	$content .= "</form>";

	return $content;
}

function selectBams_old($galaxy)
{
	$content = '';

	$content .= "<form action=\"\" method=\"POST\">\n";
	$content .= "<input type=\"text\" name=\"filter\" value=\"\">\n";
	$content .= "<input type=\"submit\" name=\"page\" value=\"Search\">\n";

	$file = fopen("bams.txt", "r") or exit("Unable to open file!");

	$content .= "<br />";
	$content .= "<br />";

	$filter = '';

	if (isset($_REQUEST['filter'])) {$filter= $_REQUEST['filter'];}

	$content .= "</form>";

	$content .= "<form action=\"\" method=\"POST\">";

	$content .= "<input type=\"hidden\" name=\"page\" value=\"settings\">";

	while(!feof($file))
	{
		$line = fgets($file);
		$line = chop($line);

		$splitLine = split("\t", $line);

		$path = $splitLine[1];
		$id = $splitLine[0];

		if ($filter !== ''){
	
			if(strpos($path, $filter) !== false  ){
	
				$content .= "<input type=\"checkbox\" name=\"data[ ]\" value=\"$id\" />";
	
				$content .= $path;
				$content .= "<br />";
			}

		}else{
				$content .= "<input type=\"checkbox\" name=\"data[ ]\" value=\"$id\" />";
	
				$content .= $path;
				$content .= "<br />";
		}

	}

	$content .= "<input type=\"submit\" value=\"Go\">";

// 	$content .= "<div id =\"info\" class=\"info\"></div>";

	$content .= "</form>";

	return $content;
}


function saving($mapSettings, $alignmentTool, $galaxy)
{
	$content = '';

	$configuration = readConfiguration();
	#WHOHOOOO HET WERKT!!!!!!!!!!!!!!!!!!!!!!!!!!!
	
	#making temeraly file in /tmp
	$tmpFile = tempnam('/tmp', 'SAP42');
	#changeing premissions for all to read and write
	system("chmod a+rw $tmpFile");

	$config = fopen("$tmpFile", "w") or exit("Unable to open file!");

	$platform = '';
	if (isset($_POST['platform'])){
		$platform = $_POST['platform'];
	}

	$pwd = $_REQUEST["pwd"];
	$design = $_POST["design"];
	$email = $_REQUEST["email"];
	$priority = $_REQUEST["priority"];

	$preStatistics = '';
	if (isset($_POST["SPRE"])){
		$preStatistics = $_POST["SPRE"];
	}

	$postStatistics = '';
	if (isset($_POST["SPOST"])){
		$postStatistics = $_POST["SPOST"];
	}


// 	########## SNP CALL SETTINGS ################
	
// 	$rc = $_REQUEST["rc"];
	$cl = $_REQUEST["cl"];
	$ss = $_REQUEST["ss"];
	$seed = $_REQUEST["seed"];
	$rlq = $_REQUEST["rlq"];
	$q = $_REQUEST["q"];
	$c = $_REQUEST["c"];
	$mc = $_REQUEST["mc"];
	$d = $_REQUEST["d"];
	$sb = $_REQUEST["sb"];
	
	$pnr = $_REQUEST["pnr"];
	$pr = $_REQUEST["pr"];
	$mac = $_REQUEST["mac"];
	$hom = $_REQUEST["hom"];
	$ouc = $_REQUEST["ouc"];
	$snps = $_REQUEST["snps"];
	$indels = $_REQUEST["indels"];

	$pileup = $_REQUEST["pileup"];
	$fullpileup = $_REQUEST["fullpileup"];
	
	$force = $_REQUEST["force"];
	$species = $_REQUEST["species"];
	$effects = $_REQUEST["effects"];

	if (strtolower($fullpileup) === 'no'){
		if ($pr > 0){
			$fullpileup = 'normal';
		}
	}

	$SNPsettings = "-cl,$cl,-ss,$ss,-seed,$seed,-rlq,$rlq,-q,$q,-c,$c,-mc,$mc,-d,$d,-sb,$sb,-pnr,$pnr,-pr,$pr,-mac,$mac,-hom,$hom,-ouc,$ouc,-snps,$snps,-indels,$indels";


	$datafile = 'data.txt';

	if ($platform === '5500'){
		$datafile = 'data5500.txt';
	}


	$file = fopen($datafile, "r") or exit("Unable to open file!");
	while(!feof($file))
	{
		$line = fgets($file);
		$line = chop($line);

		$currentLine = split("\t", $line);

		$csfasta[$currentLine[0]][0] = $currentLine[1];
		$csfasta[$currentLine[0]][1] = $currentLine[2];
		$csfasta[$currentLine[0]][2] = $currentLine[3];
		$csfasta[$currentLine[0]][3] = $currentLine[4];

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

	$file = fopen("reference.tmp.txt", "r") or exit("Unable to open file!");

	while(!feof($file))
	{
		$line = fgets($file);
		$line = chop($line);
		$currentLine = split("\t", $line);

		$ref[$currentLine[0]] = $currentLine[2];

	}
	fclose($file);


	$aData = $_REQUEST['data'];
	$aBam = $_REQUEST['bam'];

	$platform = '';

	if (isset($_POST['platform'])){
		$platform = $_POST['platform'];
	}

// 	$fp = fopen("$tmpFolder/command.sh", 'w');
// 	fwrite( $fp, "#!/bin/sh\n\n" );

	if (isset ($aData)){

	
		foreach($aData as $value) {
	
			fwrite($config, "#SAP42 configuration\n");
	
			$selected_reference = $_REQUEST["ref_$value"];
			$selected_tool = $_REQUEST["t_$value"];
			$selected_settings = $_REQUEST["s_$value"];
			$selected_name = $_REQUEST["n_$value"];
	
			$quality = str_replace(".csfasta", ".qual", $csfasta[$value][3]);
			
	// 		$content .= "$quality";
			echo $platform . "\n";

			if ($platform === '5500'){

				if(strpos($quality, '_R3') !== false  ){
					$quality = preg_replace("/^(.+)_R3/", "$1_R3.QV", $quality);
		// 			echo "R3<br />";
				}elseif(strpos($quality, '_F5-BC') !== false  ){
					$quality = preg_replace("/^(.+)_F5-BC/", "$1_F5-BC.QV", $quality);
				}elseif(strpos($quality, '_F5-P2') !== false  ){
					$quality = preg_replace("/^(.+)_F5-P2/", "$1_F5-P2.QV", $quality);
		// 			echo "F5-P2<br />";
				}elseif (strpos($quality, '_F3') !== false  ){
					$quality = preg_replace("/^(.+)_F3/", "$1_F3.QV", $quality);
		// 			echo "F3<br />";
				}elseif (strpos($quality, '_F5-RNA') !== false  ){
					$quality = preg_replace("/^(.+)_F5-RNA/", "$1_F5-RNA.QV", $quality);
		// 			echo "F3<br />";
				}

			}else{
		
				if(strpos($quality, '_R3') !== false  ){
					$quality = preg_replace("/^(.+)_R3/", "$1_R3_QV", $quality);
		// 			echo "R3<br />";
				}elseif(strpos($quality, '_F5-P2') !== false  ){
					$quality = preg_replace("/^(.+)_F5-P2/", "$1_F5-P2_QV", $quality);
		// 			echo "F5-P2<br />";
				}elseif (strpos($quality, '_F3') !== false  ){
					$quality = preg_replace("/^(.+)_F3/", "$1_F3_QV", $quality);
		// 			echo "F3<br />";
				}

			}
	
	// 		$content .= "$quality";
	
			$mapSettings[$selected_settings] = str_replace(" ", ",", $mapSettings[$selected_settings]);
	
			fwrite($config, "PLATFORM\t$platform\n");
			fwrite($config, "NAME\t$selected_name\n");
			fwrite($config, "CSFASTA\t". $csfasta[$value][3] . "\n");
			fwrite($config, "QUAL\t$quality\n");
			fwrite($config, "PWD\t$pwd/" . $selected_name . "\n");
			fwrite($config, "REFERENCE\t" . $ref[$selected_reference] . "\n");
			fwrite($config, "ALNPROM\t"  . $alignmentTool[$selected_tool] . "\n");
			fwrite($config, "ALNARG\t" . $mapSettings[$selected_settings] . "\n");
			fwrite($config, "EMAIL\t$email\n");
			fwrite($config, "PRIORITY\t$priority\n");
			fwrite($config, "VARIANTSETTINGS\t$SNPsettings\n");
	
			fwrite($config, "VARIANTSPECIES\t$species\n");
			fwrite($config, "VARIANTEFFECTS\t$effects\n");
			fwrite($config, "VARIANTFORCE\t$force\n");
	
			fwrite($config, "PILEUP\t$pileup\n");
			fwrite($config, "FULLPILEUP\t$fullpileup\n");
	
			fwrite($config, "CALLSNPS\t$snps\n");
			fwrite($config, "CALLINDELS\t$indels\n");
	
			if (strlen($design) > 0){
				fwrite($config, "DESIGN\t$design\n");
			}
			if ($postStatistics !== ""){
				fwrite($config, "PRESTATS\t$postStatistics\n");	
			}
			if ($preStatistics !== ""){
				fwrite($config, "POSTSTATS\t$preStatistics\n");
			}
			fwrite($config, "\t\n");
		}

		if ($configuration['RELEASE'] === 'stable'){
			$content .= "Execute the following command on " . $configuration['SUBMITNODE'] . ":";
			$code = str_replace("/tmp/", "", $tmpFile);
			$content .= "<h4>SAP42 create -vE -C $code</h4>";
		}else{
			$content .= "Execute the following command on " . $configuration['SUBMITNODE'] . ":";
			$code = str_replace("/tmp/", "", $tmpFile);
			$content .= "<h4>" . $configuration['SCRIPTROOT'] . "/SAP42_create -vE -C $code</h4>";
		}

	}elseif (isset($aBam)){


		foreach($aBam as $value) {

			$bam_base = '';
			$name = '';
			$pwd = '';
	
			if (preg_match("/(.+)\/(.+?)\/(.+?)\.bam/",$value, $matches)){
				$pwd = $matches[1];
				$name = $matches[2];
				$bam_base = $matches[3];
	// 			print_r($matches);
			}
	
			if (isset ($_REQUEST['reffy'])){
				$selected_reference = $_REQUEST['reffy']; 
		
			}
	
			if ($name === $bam_base){

				fwrite($config, "#SAP42 configuration\n");
				fwrite($config, "PLATFORM\t$platform\n");
				fwrite($config, "NAME\t$name\n");
				fwrite($config, "CSFASTA\tX\n");
				fwrite($config, "QUAL\tX\n");
				fwrite($config, "PWD\t$pwd/$name/\n");
				fwrite($config, "REFERENCE\t" . $ref[$selected_reference] . "\n");
	
				fwrite($config, "EMAIL\t$email\n");
				fwrite($config, "PRIORITY\t$priority\n");
			
				$SNPsettings = str_replace(',',' ',$SNPsettings);
				$SNPsettings = strtolower($SNPsettings);
	
				fwrite($config, "VARIANTSETTINGS\t$SNPsettings\n");
		
				fwrite($config, "VARIANTSPECIES\t$species\n");
				fwrite($config, "VARIANTEFFECTS\t$effects\n");
				fwrite($config, "VARIANTFORCE\t$force\n");
		
				fwrite($config, "PILEUP\t$pileup\n");
				fwrite($config, "FULLPILEUP\t$fullpileup\n");
		
				fwrite($config, "CALLSNPS\t$snps\n");
				fwrite($config, "CALLINDELS\t$indels\n");
	
			}else{
				return "$pwd<br />Folder and BAM should be the same!";
			}

			fwrite($config, "\t\n");
		}

		if ($configuration['RELEASE'] === 'stable'){
			$content .= "Execute the following command on " . $configuration['SUBMITNODE'] . ":";
			$code = str_replace("/tmp/", "", $tmpFile);
			$content .= "<h4>SAP42 run_variants /tmp/$code</h4>";
		}else{
			$content .= "Execute the following command on " . $configuration['SUBMITNODE'] . ":";
			$code = str_replace("/tmp/", "", $tmpFile);
			$content .= "<h4>" . $configuration['SCRIPTROOT'] . "/SAP42_run_variants /tmp/$code</h4>";
		}

	}else{

		$bam_base = '';
		$name = '';

		if (preg_match("/(.+)\/(.+?)\/(.+?)\.bam/",$pwd, $matches)){
			$pwd = $matches[1];
			$name = $matches[2];
			$bam_base = $matches[3];
// 			print_r($matches);
		}

	if (isset ($_REQUEST['reffy'])){
		$selected_reference = $_REQUEST['reffy']; 

	}

		if ($name === $bam_base){

			fwrite($config, "NAME\t$name\n");
			fwrite($config, "CSFASTA\tX\n");
			fwrite($config, "QUAL\tX\n");
			fwrite($config, "PWD\t$pwd/$name/\n");
			fwrite($config, "REFERENCE\t" . $ref[$selected_reference] . "\n");

			fwrite($config, "EMAIL\t$email\n");
			fwrite($config, "PRIORITY\t$priority\n");
		
			$SNPsettings = str_replace(',',' ',$SNPsettings);
			$SNPsettings = strtolower($SNPsettings);

			fwrite($config, "VARIANTSETTINGS\t$SNPsettings\n");
	
			fwrite($config, "VARIANTSPECIES\t$species\n");
			fwrite($config, "VARIANTEFFECTS\t$effects\n");
			fwrite($config, "VARIANTFORCE\t$force\n");
	
			fwrite($config, "PILEUP\t$pileup\n");
			fwrite($config, "FULLPILEUP\t$fullpileup\n");
	
			fwrite($config, "CALLSNPS\t$snps\n");
			fwrite($config, "CALLINDELS\t$indels\n");

		}else{
			return "$pwd<br />Folder and BAM should be the same!";
		}

		if ($configuration['RELEASE'] === 'stable'){
			$content .= "Execute the following command on " . $configuration['SUBMITNODE'] . ":";
			$code = str_replace("/tmp/", "", $tmpFile);
			$content .= "<h4>SAP42 run_variants /tmp/$code</h4>";
		}else{
			$content .= "Execute the following command on " . $configuration['SUBMITNODE'] . ":";
			$code = str_replace("/tmp/", "", $tmpFile);
			$content .= "<h4>" . $configuration['SCRIPTROOT'] . "/SAP42_run_variants /tmp/$code</h4>";

		}
	}

// 	fclose($fp);
// 	$content .= "Configuration files have been stored to <h4>$tmpFolder</h4>";

	return $content;
}

function readConfiguration() {
	$configuration = array();

	$file = fopen("sap42.ini", "r") or exit("Unable to open file!");

	while(!feof($file))
	{
		$line = fgets($file);
		$line = chop($line);

		$splitLine = split("\t", $line);

		if ((count($splitLine) < 2) || (substr($line,0,1) == "#")){
			# wrong line..
		}else{
			$configuration[strtoupper($splitLine[0])] = $splitLine[1];
		}

	}

	return $configuration;
}

?>

</body>
</html>