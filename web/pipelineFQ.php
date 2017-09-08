<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
	<head>
		<title>
			SAP42-DX-HPC - Sequence Alignment Pipeline
		</title>
		<link rel="stylesheet" type="text/css" href="style/style.css" />
	</head>
	<body>

<script type="text/javascript">
function CloneSelectbox(id, elementName)
{

// 	var id = document.getElementById(element);
	var selectedReference = id.selectedIndex;

	//alert(selectedReference);

	var counter = 1;
	for (i=0;i<=1000;i++)
	{
		counter++;
		var ref2id = elementName + '_' + counter;

		var ref2 = document.getElementById(ref2id);
		
		if (ref2 != null)
		{
// 			alert(ref2id);
			ref2.selectedIndex = selectedReference;
		}
		else
		{
// 			alert("BREAK: " + ref2id);
			break;
		}
	}

	var infoText = document.getElementById('info' + id.value).value;
	showReference(infoText);

}

function foldRun(id){
	var div = document.getElementById('runContainer' + id);
	var selectButton = document.getElementById('selectButton' + id);
	if (div.style.display=="block"){
		div.style.display="none";
		selectButton.style.display="none";
		document.getElementById('runNameContainer' + id).style.backgroundColor="white";
		document.getElementById('runName' + id).style.color="#106EC7";
		document.getElementById('runName' + id).style.fontWeight="normal";
	}else{
		div.style.display="block";
		selectButton.style.display="block";
		document.getElementById('runNameContainer' + id).style.backgroundColor="#106EC7";
		document.getElementById('runName' + id).style.color="white";
		document.getElementById('runName' + id).style.fontWeight="bold";

// 		var divs = div.getElementsByTagName('div');

 		var divs = div.childNodes;
		if (divs.length == 7){
			
		}

	}
}

function selectRun(id){
	var div = document.getElementById('runContainer' + id);
	var checkBoxes = div.getElementsByTagName('input');
	
	for (var x=0; x<checkBoxes.length; x++) {
		
		 if (checkBoxes[x].type.toLowerCase()=='checkbox'){
			checkBoxes[x].checked = true;
		}
	}
}

function selectSegment(id){
	var div = document.getElementById('segmentContainer' + id);
	var checkBoxes = div.getElementsByTagName('input');
	
	for (var x=0; x<checkBoxes.length; x++) {
		
		 if (checkBoxes[x].type.toLowerCase()=='checkbox'){
			checkBoxes[x].checked = true;
		}
	}
}

function changeActionOfForm(id){
	var selectedOption = id.selectedIndex;

	if (selectedOption == 1){
		document.getElementById("mapping_form").action="variants.php";
// 		alert("SNP caller activated");
	}else{
		document.getElementById("mapping_form").action="";
// 		alert("SNP caller disabled");
	}
}

function foldSegment(id){
	var div = document.getElementById('segmentContainer' + id);
	if (div.style.display=="block"){
		div.style.display="none";
		document.getElementById('segmentName' + id).style.fontStyle="normal";
	}else{
		div.style.display="block";
		document.getElementById('segmentName' + id).style.fontStyle="italic";
	}
}

function showReference(info){
	var infoDiv = document.getElementById('info');
	infoDiv.innerHTML="Selected reference: " + info;
}

</script>

<?php

// error_reporting(E_ALL);
// ini_set("display_errors", 1);


$page = '';

if (isset($_REQUEST['page'])) {$page= $_REQUEST['page'];}

$body = "";

$body .= "<div class=\"container\">\n";
$body .= "\t<div class=\"header\">\n";
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
	$mapSettings[0] = "BWA default";
	$mapSettings[1] = "-l 25 -k 2 -n 5";
	$mapSettings[2] = "-l 25 -k 1 -n 10";
	$mapSettings[3] = "-l 25 -k 1 -n 5";
// 	$mapSettings[4] = "-l 10 -k 2 -n 10";
// 	$mapSettings[5] = "-l 10 -k 2 -n 5";
// 	$mapSettings[6] = "-l 25 -k 3 -n 10";
// 	$mapSettings[7] = "-l 25 -k 3 -n 10";

	$alignmentTool = array();
	$alignmentTool[0] = 'BWA';


	$galaxy = '';
//	if (isset($_REQUEST['GALAXY_URL'])) {$galaxy= $_REQUEST['GALAXY_URL'];}

	$content = '';

	switch ($page){
                        case "new":
                                $content = "";
                        break;
                        case "selectExperiments":
                                $content = selectExperiments($galaxy);
                        break;
                        case "preMapping":
                                $content = preMapping($mapSettings, $alignmentTool, $galaxy);
                        break;
			case "mapping":
				$content = mapping($mapSettings, $alignmentTool, $galaxy);
			break;
			case "saving":
				$content = saving($mapSettings, $alignmentTool, $galaxy);
			break;
                        default:
				$content = selectExperiments($galaxy);
	}
	return $content;
}

function selectExperiments($galaxy)
{
	$content = '';

	$file = fopen("dataFQ.txt", "r") or exit("Unable to open file!");
	//Output a line of the file until the end is reached

	$content .= "<form action=\"\" method=\"POST\">\n";
	$content .= "<input type=\"hidden\" name=\"page\" value=\"preMapping\" />\n";
	$content .= "<input type=\"hidden\" name=\"illumina_type\" value=\"fastq\">\n";
	if (strcmp($galaxy,'') != 0){
		$content .= "<input type=\"hidden\" name=\"GALAXY_URL\" value=\"$galaxy\">\n";
		$_tool_id = $_REQUEST['tool_id'];
		$content .= "<input type=\"hidden\" name=\"tool_id\" value=\"$_tool_id\">\n";
	}

	$content .= "<input type=\"checkbox\" checked=\"checked\" name=\"samplename\" \> Include samplenames in projectnames.";
	$previousRun = '';
	$prefiousSegment = '';

	while(!feof($file))
	{
		$line = fgets($file);
		$line = chop($line);
		
		if (strlen($line) > 3){
			$data = split("\t", $line);
			$id = $data[0];
			$run = $data[1];
			$segment = $data[2];
			$library = $data[3];
			$location = $data[4];
	
			if ($previousRun != $run){
				#new run

				if ($previousRun != ''){
// 					$tmp_content .= "<input type=\"submit\"><input type=\"reset\">";
					$tmp_content .= "\t\t</div><!-- End of segmentContainer div -->\n";
					$tmp_content .= "\t</div><!-- End of runContainer div -->\n";
				}
				
				$tmp_content .= "\t<div id =\"runNameContainer$id\" class=\"runNameContainer\">\n";
				$tmp_content .= "\t\t<div id =\"runName$id\" class=\"runName\" onclick=\"foldRun('$id');\" onMouseOver=\"this.style.cursor='pointer'\" >\n";
				$tmp_content .= "\t\t\t$run\n";
				$tmp_content .= "\t\t</div><!-- End of runName div -->\n";
				$tmp_content .= "\t\t<div id=\"selectButton$id\" class=\"selectAllRun\" onclick=\"selectRun($id);\" onMouseOver=\"this.style.cursor='pointer'\" >select all</div>\n";
				$tmp_content .= "\t</div><!-- End of runNameContainer div -->\n";
				$tmp_content .= "\t<div id=\"runContainer$id\" class=\"runContainer\">\n";
				
				$tmp_content .= "\t\t<div class=\"segmentNameContainer\">\n";
				$tmp_content .= "\t\t\t<div id=\"segmentName$id\" class=\"segmentName\" onclick=\"foldSegment('$id');\" onMouseOver=\"this.style.cursor='pointer'\" >\n\t\t\t\t$segment\n\t\t\t</div>\n";
				$tmp_content .= "\t\t\t<div id=\"selectButton$id\" class=\"selectAllSegment\" onclick=\"selectSegment($id);\" onMouseOver=\"this.style.cursor='pointer'\" >select segment</div>\n";
				$tmp_content .= "\t\t</div><!-- End of segmentNameContainer div -->\n";
				$tmp_content .= "\t\t<div id=\"segmentContainer$id\" class=\"segmentContainer\">\n";
			}else{
				#still in the same run
				if ($prefiousSegment != $segment){
					$tmp_content .= "\t\t</div><!-- End of segmentContainer div -->\n";
					$tmp_content .= "\t\t<div class=\"segmentNameContainer\">\n";
					$tmp_content .= "\t\t\t<div id=\"segmentName$id\" class=\"segmentName\" onclick=\"foldSegment('$id');\" onMouseOver=\"this.style.cursor='pointer'\" >\n\t\t\t\t$segment\n\t\t\t</div>\n";
					$tmp_content .= "\t\t\t<div id=\"selectButton$id\" class=\"selectAllSegment\" onclick=\"selectSegment($id);\" onMouseOver=\"this.style.cursor='pointer'\" >select segment</div>\n";
					$tmp_content .= "\t\t</div><!-- End of segmentNameContainer div -->\n";
					$tmp_content .= "\t\t<div id=\"segmentContainer$id\" class=\"segmentContainer\">\n";
				}
			}
			$tmp_content .= "\t\t\t<div class=\"libraryContainer\">\n";
			$tmp_content .= "\t\t\t\t<div class=\"checkbox\"><input type=\"checkbox\" name=\"data[ ]\" value=\"$id\" />\n\t\t\t\t</div>";
			$tmp_content .=  "\n\t\t\t\t<div class=\"libraryName\" onclick=\"alert('$data[4]');\">\n\t\t\t\t\t$library\n\t\t\t\t</div>\n";
			$tmp_content .= "\t\t\t</div><!-- end of libraryContainer-->\n\n";
			$previousRun = $run;
			$prefiousSegment = $segment;
		}
	}


	$file = fopen("dataFQ.tmp.txt", "r") or exit("Unable to open file!");

	while(!feof($file))
	{
		$line = fgets($file);
		$line = chop($line);
		
		if (strlen($line) > 3){
		
			$data = split("\t", $line);
			$id = $data[0];
			$run = $data[1];
			$segment = $data[2];
			$library = $data[3];
			$location = $data[4];
	
			if ($previousRun != $run){
				#new run

				if ($previousRun != ''){
// 					$tmp_content .= "<input type=\"submit\"><input type=\"reset\">";
					$tmp_content .= "\t\t</div><!-- End of segmentContainer div -->\n";
					$tmp_content .= "\t</div><!-- End of runContainer div -->\n";
				}
				
				$tmp_content .= "\t<div id =\"runNameContainer$id\" class=\"runNameContainer\">\n";
				$tmp_content .= "\t\t<div id =\"runName$id\" class=\"runName\" onclick=\"foldRun('$id');\" onMouseOver=\"this.style.cursor='pointer'\" >\n";
				$tmp_content .= "\t\t\t$run\n";
				$tmp_content .= "\t\t</div><!-- End of runName div -->\n";
				$tmp_content .= "\t\t<div id=\"selectButton$id\" class=\"selectAllRun\" onclick=\"selectRun($id);\" onMouseOver=\"this.style.cursor='pointer'\" >select all</div>\n";
				$tmp_content .= "\t</div><!-- End of runNameContainer div -->\n";
				$tmp_content .= "\t<div id=\"runContainer$id\" class=\"runContainer\">\n";
				$tmp_content .= "\t\t<div class=\"segmentNameContainer\">\n";
				$tmp_content .= "\t\t\t<div id=\"segmentName$id\" class=\"segmentName\" onclick=\"foldSegment('$id');\" onMouseOver=\"this.style.cursor='pointer'\" >\n\t\t\t\t$segment\n\t\t\t</div>\n";
				$tmp_content .= "\t\t\t<div id=\"selectButton$id\" class=\"selectAllSegment\" onclick=\"selectSegment($id);\" onMouseOver=\"this.style.cursor='pointer'\" >select segment</div>\n";
				$tmp_content .= "\t\t</div><!-- End of segmentNameContainer div -->\n";
				$tmp_content .= "\t\t<div id=\"segmentContainer$id\" class=\"segmentContainer\">\n";
			}else{
				#still in the same run

				if ($prefiousSegment != $segment){
					$tmp_content .= "\t\t</div><!-- End of segmentContainer div -->\n";
					$tmp_content .= "\t\t<div class=\"segmentNameContainer\">\n";
					$tmp_content .= "\t\t\t<div id=\"segmentName$id\" class=\"segmentName\" onclick=\"foldSegment('$id');\" onMouseOver=\"this.style.cursor='pointer'\" >\n\t\t\t\t$segment\n\t\t\t</div>\n";
					$tmp_content .= "\t\t\t<div id=\"selectButton$id\" class=\"selectAllSegment\" onclick=\"selectSegment($id);\" onMouseOver=\"this.style.cursor='pointer'\" >select segment</div>\n";
					$tmp_content .= "\t\t</div><!-- End of segmentNameContainer div -->\n";
					$tmp_content .= "\t\t<div id=\"segmentContainer$id\" class=\"segmentContainer\">\n";
				}
			}
			$tmp_content .= "\t\t\t<div class=\"libraryContainer\">\n";
			$tmp_content .= "\t\t\t\t<div class=\"checkbox\"><input type=\"checkbox\" name=\"data[ ]\" value=\"$id\" />\n\t\t\t\t</div>";
			$tmp_content .=  "\n\t\t\t\t<div class=\"libraryName\" onclick=\"alert('$data[4]');\">\n\t\t\t\t\t$library\n\t\t\t\t</div>\n";
			$tmp_content .= "\t\t\t</div><!-- end of libraryContainer-->\n\n";
	
			$previousRun = $run;
			$prefiousSegment = $segment;
		}
	}
	
	$tmp_content .= "\t\t</div><!-- End of segmentContainer div -->\n";
	$tmp_content .= "\t</div><!-- End of runContainer div -->\n";
	$tmp_content .= "\t<div class=\"ButtonsContainer\">";
	$tmp_content .= "<input type=\"submit\" /><input type=\"reset\" />";
	$tmp_content .= "\t</div><!-- End of ButtonsContainer div -->\n";
	
	fclose($file);
	
	$content .= "<br />\n";
	$content .= "<br />\n";
	$content .= $tmp_content;
	$content .= "</form>";
	return $content;
}


function preMapping($mapSettings, $alignmentTool, $galaxy)
{
	$reference_id = 1;
	$content = '';
	$includeSampleName = false;
	if (isset($_POST['samplename'])){
		$includeSampleName = true;
	}

	$aData = $_POST['data'];
// 	$content = $aData;
	$csfasta = array(array());
	$content .= "<form action=\"\" method=\"POST\">";
	if (strcmp($galaxy,'') != 0){
		$content .= "<input type=\"hidden\" name=\"GALAXY_URL\" value=\"$galaxy\">";
		$galaxy_tool_id = $_REQUEST['tool_id'];
		$content .= "<input type=\"hidden\" name=\"tool_id\" value=\"$galaxy_tool_id\">";
	}


	$file = fopen("dataFQ.txt", "r") or exit("Unable to open file!");
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

	$file = fopen("dataFQ.tmp.txt", "r") or exit("Unable to open file!");
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


	$file = fopen("reference.ignore.txt", "r") or exit("Unable to open file!");

	$ref_ignore = array();

	while(!feof($file))
	{
		$line = fgets($file);
		$line = chop($line);
		$ref_ignore[$line] = 1;
	}

	$reference = '';

	$file = fopen("reference.txt", "r") or exit("Unable to open file!");
	//Output a line of the file until the end is reached
	$content .= "<input type=\"hidden\" name=\"page\" value=\"mapping\">";
	$content .= "<input type=\"hidden\" name=\"illumina_type\" value=\"fastq\">\n";
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


		if (($reference_id === $currentLine[1]) && (strlen($reference_id) > 0)){
			
			$reference .= "<option selected=\"selected\" value=\"" . $currentLine[0] . "\">" . $currentLine[1] . "</option>\n";
		}else{
			$reference .= "<option value=\"" . $currentLine[0] . "\">" . $currentLine[1] . "</option>\n";
			$hidden_content .= "<input type=\"hidden\" id=\"info" . $currentLine[0] . "\" value=\"" . $currentLine[2] . "\">\n";
		}
	}

	fclose($file);
	$file = fopen("reference.tmp.txt", "r") or exit("Unable to open file!");

	while(!feof($file))
	{
		$line = fgets($file);
		$currentLine = split("\t", $line);
		if (($reference_id === $currentLine[1]) && (strlen($reference_id) > 0)){
			
			$reference .= "<option selected=\"selected\" value=\"" . $currentLine[0] . "\">" . $currentLine[1] . "</option>\n";
		}else{
			$reference .= "<option value=\"" . $currentLine[0] . "\">" . $currentLine[1] . "</option>\n";
			$hidden_content .= "<input type=\"hidden\" id=\"info" . $currentLine[0] . "\" value=\"" . $currentLine[2] . "\">\n";
		}
	}


	$content .= $hidden_content;

	$tool = '';

	foreach($alignmentTool as $key => $value) {
		$tool .= "<option value=\"$key\">" . $value . "</option>";
	}


	$select = '';

	foreach($mapSettings as $key => $value) {
		$select .= "<option value=\"$key\">" . $value . "</option>";
	}

	$content .= '<table>';

	$nruns = 0;

	$previousRunName = '';

	foreach($aData as $value) {
		$nruns++;
		$runName = $csfasta[$value][0];

		if ($runName == $previousRunName){
			$content .= "<tr><td>" . $csfasta[$value][1] . "</td><td>" . $csfasta[$value][2] . "</td>";
		}else{
			$content .= "<tr><th colspan=\"6\">" . $runName . "</th></tr>";
			$content .= '<tr class="h"><td>Sample</td><td>Library</td><td>Reference</td><td>Tool</td><td>Settings</td><td>Project Name</td></tr>';
			$content .= "<tr><td>" . $csfasta[$value][1] . "</td><td>" . $csfasta[$value][2] . "</td>";
		}
		
		if ($nruns == 1){
			$content .= "</td><td><select name=\"ref_$value\" id=\"reference_$nruns\" onchange=\"javascript:CloneSelectbox(this, 'reference');\">$reference</select></td>";
			$content .= "<td><select name=\"t_$value\" id=\"tool_$nruns\" onchange=\"javascript:CloneSelectbox(this, 'tool');\">$tool</select></td>";
			$content .= "<td><select name=\"s_$value\" id=\"settings_$nruns\" onchange=\"javascript:CloneSelectbox(this, 'settings');\">$select</select></td>";
		}else{
			$content .= "</td><td><select name=\"ref_$value\" id=\"reference_$nruns\">$reference</select></td>";
			$content .= "<td><select name=\"t_$value\" id=\"tool_$nruns\">$tool</select></td>";
			$content .= "<td><select name=\"s_$value\" id=\"settings_$nruns\">$select</select></td>";
		}

		$pregname = $csfasta[$value][2];

		if ($csfasta[$value][2] == "Full Slide Fragment"){
			if (preg_match("/\d{8}_*.+?_(.+)_/", $csfasta[$value][0], $matches)) {
				$pregname = $matches[1];
			}else{
				$pregname = $csfasta[$value][0];
			}
		}

		if (preg_match("/\d{6}/", $csfasta[$value][0], $matches)) { #get date out of runname
			$pregname .= '_' . $matches[0];
		}

		if ($includeSampleName){
			$pregname = $csfasta[$value][1] . "_" . $pregname;
		}

// 		$pregname

		$content .= "<td><input type=\"text\" name=\"n_$value\" value=\"$pregname\" size=\"60\"/></td></tr>";

		$content .= "<input type=\"hidden\" name=\"data[ ]\" value=\"$value\">";

		$previousRunName = $runName;
	}

	$content .= '</table>';
	$content .= "<input type=\"hidden\" name=\"nruns\" value=\"$nruns\">";
	$content .= "<input type=\"submit\">";
	$content .= "</form>";

	return $content;
}

function mapping($mapSettings, $alignmentTool, $galaxy)
{
	$content = '';
	$configuration = readConfiguration();

	$aData = $_POST['data'];
// 	$content = $aData;
// 	echo $aData;

	$csfasta = array(array());

	if (strcmp($galaxy,'') != 0){
		$content .= "<form id=\"mapping_form\" action=\"$galaxy\" method=\"POST\">";
		$galaxy_tool_id = $_REQUEST['tool_id'];
		$content .= "<input type=\"hidden\" name=\"tool_id\" value=\"$galaxy_tool_id\">";
	}else{
		$content .= "<form id=\"mapping_form\" action=\"\" method=\"POST\">";
	}

	$content .= "<input type=\"hidden\" name=\"page\" value=\"saving\">";
	$content .= "<input type=\"hidden\" name=\"illumina_type\" value=\"fastq\">\n";
	$file = fopen("dataFQ.txt", "r") or exit("Unable to open file!");
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

	$file = fopen("dataFQ.tmp.txt", "r") or exit("Unable to open file!");
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

	$type = 'unknown';
	$organism = 'organism';
	$responsible = "nobody";

	
	if (preg_match("/FRAG/i", $csfasta[$aData[0]][0])){
		$type = 'fragment';
	}
	if (preg_match("/chip/i", $csfasta[$aData[0]][0])){
		$type = 'CHiP';
	}
	if (preg_match("/rnaseq/i", $csfasta[$aData[0]][0])){
		$type = 'transcriptome';
	}
	if (preg_match("/transcriptome/i", $csfasta[$aData[0]][0])){
		$type = 'transcriptome';
	}
	if (preg_match("/transcriptome/i", $csfasta[$aData[0]][0])){
		$type = 'transcriptome';
	}
	if (preg_match("/rat/i", $ref[$selected_reference])){
		$organism = 'rat';
	}
	if (preg_match("/human/i", $ref[$selected_reference])){
		$organism = 'human';
	}
	if (preg_match("/fish/i", $ref[$selected_reference])){
		$organism = 'zfish';
	}
	if (preg_match("/mouse/i", $ref[$selected_reference])){
		$organism = 'mouse';
	}
//	if (preg_match("/.+_(.+?)$/", $csfasta[$aData[0]][0], $matches)){
//		$responsible = $matches[1];
//	}

	$content .= "<h3>Statistics</h3>\n";
	$content .= "\n";
	$content .= "<input type=\"checkbox\" name=\"SPRE\" value=\"yes\" checked=\"checked\" /> Premapping";
	$content .= "<br />\n";
	$content .= "<input type=\"checkbox\" name=\"SPOST\" value=\"yes\" checked=\"checked\" /> Postmapping";
	$content .= "<br />\n";
	$content .= "<h5>Activate SNP caller:</h5>";
	$content .= "<select name=\"vap42\"  onchange=\"javascript:changeActionOfForm(this);\">";
	$content .= "<option value=\"No\">No</option>";
	$content .= "<option value=\"Yes\">Yes</option>";
	$content .= "</select>";
	$content .= "<input type=\"hidden\" name=\"platform\" value=\"illumina\">";
	$content .= "<h3>Path to working directory on " . $configuration['SUBMITNODE'] . ":</h3>\n";
	$content .= "<input type=\"text\" name=\"pwd\" size=50 value=\"/hpc/cog_bioinf/data/mapping/illumina/\">";

	//DESIGNFILE
	$content .= "<h3>File with arraydesign (bed-file) on " . $configuration['SUBMITNODE'] . ":</h3> <select name='design' id='design'>";
	$content .= "<option value=''>Select</option>\n";

	$file = fopen("design.txt", "r") or exit("Unable to open file!");

	while(!feof($file))
	{
		$line = fgets($file);
		$line = chop($line);
		$splitLine = split("\t", $line);
		$content .= "<option value='" . $splitLine[2] . "'>" . $splitLine[1] . "</option>\n";
	}

	$content .= "</select>\n";


	if (strcmp($galaxy,'') != 0){
		$content .= "<input type=\"hidden\" name=\"email\" value=\"XX\">";
	}else{
		$content .= "<h3>Email address:</h3>\n";
		$content .= "<input type=\"text\" name=\"email\">";
		$content .= "<h3>Responisble person:</h3>\n";
		$content .= "<input type=\"text\" name=\"responsible\" value=\"$responsible\">";
		$content .= "<h3>Priority:</h3>\n";
		$content .= "<select name=\"priority\">";
		$content .= "<option value=\"-200\">Extreme Low (-200)</option>";
		$content .= "<option value=\"-100\">Low (-100)</option>";
		$content .= "<option value=\"0\" selected=\"selected\">Normal (0)</option>";
		$content .= "<option value=\"100\">High (100)</option>";
		$content .= "<option value=\"200\">Extreme High (200)</option>";
		$content .= "</select>";
		$content .= "<br />\n";
		$content .= "<br />\n";
	}

	$content .= "<table>";

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

	$content .= "</table>\n\n";

	$content .= "<input type=\"hidden\" name=\"name\" value=\"$type $organism\">\n";

	if (strcmp($galaxy,'') != 0){
		$content .= "<input value=\"Send to Galaxy\"type=\"submit\">";
	}else{
		$content .= "<input type=\"submit\">";
	}
	$content .= "</form>\n";

	return $content;
}

function saving($mapSettings, $alignmentTool, $galaxy)
{

	$content = '';
	$forward = '';

	$configuration = readConfiguration();
	
	#making temp file in /tmp
	$tmpFile = tempnam('/tmp', 'SAP42');
	#changeing premissions for all to read and write
	system("chmod a+rw $tmpFile");

	$config = fopen("$tmpFile", "w") or exit("Unable to open file!");

	$pwd = $_POST["pwd"];
	$forward .= "pwd=$pwd";

	$design = $_POST["design"];
	$forward .= "&design=$design";

	$email = $_POST["email"];
	$forward .= "&email=$email";

	$call_sps = '';
	if (isset($_POST["vap42"])){
		$call_sps = $_POST["vap42"];
	}

	$priority = 0;
	if (isset($_POST["priority"])){
		$priority = $_POST["priority"];
	}


	$preStatistics = '';
	if (isset($_POST["SPRE"])){
		$preStatistics = $_POST["SPRE"];
		$forward .= "&SPRE=$preStatistics";
	}

	$postStatistics = '';
	if (isset($_POST["SPOST"])){
		$postStatistics = $_POST["SPOST"];
		$forward .= "&SPOST=$postStatistics";
	}


	$file = fopen("dataFQ.txt", "r") or exit("Unable to open file!");
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

	$file = fopen("dataFQ.tmp.txt", "r") or exit("Unable to open file!");
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

	$aData = $_POST['data'];

	print_r($aData);
// 	$fp = fopen("$tmpFolder/command.sh", 'w');
// 	fwrite( $fp, "#!/bin/sh\n\n" );


	$platform = '';

	if (isset($_POST['platform'])){
		$platform = $_POST['platform'];
	}

	foreach($aData as $value) {
		$forward .= "&data[+]=$value";
		fwrite($config, "#SAP42 configuration\n");
		
		$selected_reference = $_POST["ref_$value"];
		$forward .= "&ref_$value=$selected_reference";
		
		$selected_tool = $_POST["t_$value"];
		$forward .= "&t_$value=$selected_tool";

		$selected_settings = $_POST["s_$value"];
		$forward .= "&s_$value=$selected_settings";

		$selected_name = $_POST["n_$value"];
		$forward .= "&n_$value=$selected_name";

		$quality = str_replace(".csfasta", ".qual", $csfasta[$value][3]);
		
		if(strpos($quality, '_R3') !== false  ){
			$quality = preg_replace("/^(.+)_R3/", "$1_R3.QV", $quality);
		}elseif(strpos($quality, '_F5-BC') !== false  ){
			$quality = preg_replace("/^(.+)_F5-BC/", "$1_F5-BC.QV", $quality);
		}elseif(strpos($quality, '_F5-P2') !== false  ){
			$quality = preg_replace("/^(.+)_F5-P2/", "$1_F5-P2.QV", $quality);
		}elseif (strpos($quality, '_F3') !== false  ){
			$quality = preg_replace("/^(.+)_F3/", "$1_F3.QV", $quality);
		}elseif (strpos($quality, '_F5-RNA') !== false  ){
			$quality = preg_replace("/^(.+)_F5-RNA/", "$1_F5-RNA.QV", $quality);
		}

		$mapSettings[$selected_settings] = str_replace(" ", ",", $mapSettings[$selected_settings]);

		fwrite($config, "PLATFORM\t$platform\n");
		fwrite($config, "NAME\t$selected_name\n");
		fwrite($config, "FASTQ\t". $csfasta[$value][3] . "\n");
		$wd = basename($csfasta[$value][3], ".xsq");
		fwrite($config, "PWD\t$pwd/\n");
		fwrite($config, "REFERENCE\t" . $ref[$selected_reference] . "\n");
		fwrite($config, "ALNPROM\t"  . $alignmentTool[$selected_tool] . "\n");
		fwrite($config, "ALNARG\t" . $mapSettings[$selected_settings] . "\n");
		fwrite($config, "EMAIL\t$email\n");
		fwrite($config, "PRIORITY\t$priority\n");
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

// 	fclose($fp);

	if ($configuration['RELEASE'] === 'stable'){
		$content .= "Execute the following command on " . $configuration['SUBMITNODE'] . ":";
		$code = str_replace("/tmp/", "", $tmpFile);
		$content .= "<h4>SAP42 create -vE -F $code</h4>";
	}else{
		$content .= "Execute the following command on " . $configuration['SUBMITNODE'] . ":";
		$code = str_replace("/tmp/", "", $tmpFile);
		$content .= "<h4>" . $configuration['SCRIPTROOT'] . "/SAP42_create -vE -F $code</h4>";
	}

	$content .= "<div class='startmapping'><a href='index.php'>Back</a></div>";

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