#! /usr/bin/env python
import sys,os,re
import commands
import getopt
import datetime

# AUTHOR:       M.G. Elferink
# DATE:         26-10-2012
# This script is made to merge refiltered files, convert them to vcf, calculate FN/FP stats for control samples, and determine the sex of all samples
# Note: Script must be runned in home folder (MERGED-folder)


#################
#################
### FUNCTIONS ###
#################
#################

###########################################
## Filter and merge controls or  samples ##
###########################################

def merge_files():
	lib2=[]
	dic={}
	lib = os.walk('.').next()[1]
	for item in lib:
		if "CONTR" not in item.upper():
			path2 = path+str(item)
			lib3 = os.listdir(path2)
			#action2="cat "
			merge_action= str(converter)+" "
			x=0
			for file in lib3:
				if "refiltered_reference" in file or "refiltered_snps" in file or "refiltered_indels" in file:
					if  "vcf" not in file and "snps_indels" not in file and "target" not in file:
				       		key = file.split("_")[0]
						value= file.split("_")[3].split(".")[0]
						dic[key]=value
						if runid== "off":
							#action2+= path2+"/"+ file+" "
							merge_action+= "-i "+ str(path2)+"/"+str(file)+" "
							x+=1
						else: 
							if runid in file:
								#action2+= path2+"/"+ file+" "
								merge_action+= "-i "+str(path2)+"/"+ str(file)+" "
       		                		                x+=1

			if x > 0 and x < 4: ## Note: will not run in directories in which variants has been called more than once, or (in case of multiple snp callings) when a specific runID has not been given!
                                merged_file = item.split("_")[1].upper().replace(opt.design.upper(),"") +"_"+ item.split("_")[3] ## Trim design name from sample
                                merge_action+= "-name "+str(merged_file)+ " -o "+ str(merged_file)+".vcf"
				print merge_action
				os.system(merge_action)									## excecute merge via new vcf converter
				lib2+=[str(merged_file)+".vcf.gz"]
			else:
				pass

	action7 = str(vcftools)+" -t "     ## merge control file with samples
	for item in lib2:
		action7=action7+" "+str(item)
	pwd= commands.getoutput("pwd")
	action7= action7+" > "+ str(pwd.split("/")[-1])+ "_samples_full.vcf 2>> "+str(log_dir)+"/log_vcfmerge_samples_"+str(date_run)+".log"
	print action7
	os.system(action7)	
	os.system("cat "+str(pwd.split("/")[-1])+ "_samples_full.vcf | egrep \'(0/1|1/0|1/1|0/2|1/2|2/2|0/3|1/3|2/3|#)\' > " + str(pwd.split("/")[-1])+ "_samples_variants.vcf")  ## filter only true variants in multisample vcf file
	os.system("bgzip -f "+ str(pwd.split("/")[-1])+ "_samples_full.vcf") 	## bgzip
	os.system("tabix -p vcf "+str(pwd.split("/")[-1])+ "_samples_full.vcf.gz")## index vcf.gz
	os.system("mv "+str(pwd.split("/")[-1])+ "_samples_full.vcf.gz* " +str(sample_dir))

	return(lib2)

def merge_controls():
        lib2=[]
        dic={}
	lib = os.walk('.').next()[1]
        for item in lib:
		if "CONTR" in item.upper():
			path2 = path+str(item)
	                lib3 = os.listdir(path2)
	                #action2="cat "
			merge_action= str(converter)+" "
	                x=0
	                for file in lib3:
	                        if "refiltered_reference" in file or "refiltered_snps" in file or "refiltered_indels" in file:
	                                if  "vcf" not in file and "snps_indels" not in file and "target" not in file:
						key = file.split("_")[0]
                                        	value= file.split("_")[3].split(".")[0]
                                        	dic[key]=value
                                        	if runid== "off":
                                        	        #action2+= path2+"/"+ file+" "
							merge_action+= "-i "+ str(path2)+"/"+str(file)+" "
                                        	        x+=1
                                        	else:
                                        	        if runid in file:
                                        	                #action2+= path2+"/"+ file+" "
								merge_action+= "-i "+ str(path2)+"/"+str(file)+" "
                                        	                x+=1

	                if x > 0 and x < 4: ## Note: will not run in directories in which variants has been called more than once, or (in case of multiple snp callings) when a specific runID has not been given!
				#action2 += " > "+item.split("_")[1]+"_"+item.split("_")[3] ## first 10 characters of samples name only!
				merged_file = item.split("_")[1]+"_"+item.split("_")[3]	
                                merge_action+= "-name "+str(merged_file)+ " -o "+ str(merged_file)+".vcf"
				#print action2
				#os.system(action2)                                                                      ## Merge SNP, Indel, Referece refiltered files
                       		#os.system(str(converter)+" -i "+str(merged_file)+ " -o "+str(merged_file)+".vcf 2> "+str(log_dir)+"/log_merge_controls_"+str(date_run)+".log")       ## convert merged file to vcf   
				#os.system("rm " +str(merged_file))                                                      ## remove merged file
				#os.system("bgzip -f "+str(merged_file)+".vcf")                                             ## zip merged vcf file
                        	#os.system("tabix -f -p vcf "+str(merged_file)+".vcf.gz")                                ## index merged vcf file
				print merge_action
                                os.system(merge_action)                                                                 ## excecute merge via new vcf converter
                        	lib2+=[str(merged_file)+".vcf.gz"]
	
        action7 = str(vcftools)+" -t "+str(control_sample_dir)+"control_samples_"+str(design)+".vcf.gz"     ## merge control file with samples
	for item in lib2:
		action7=action7+" "+str(item)
	pwd= commands.getoutput("pwd")
	action7= action7+" > "+str(control_dir)+"/"+ str(pwd.split("/")[-1])+ "_controls.vcf 2> "+str(log_dir)+"/log_vcfmerge_controls_"+str(date_run)+".log"
	print action7
	os.system(action7)
	action8= "cat "+ str(control_dir)+"/"+str(pwd.split("/")[-1])+ "_controls.vcf | awk '( $10 != \".\""
	x=0
	while x< int(opt.controls)-1:
		action8+="|| $"+str(11+x)+" != \".\""
		x+=1
	action8+=")' > "+str(control_dir)+"/"+ str(pwd.split("/")[-1])+ "_controls_sort.vcf"
	os.system(action8)
	
	os.system("bgzip -f "+str(control_dir)+"/"+str(pwd.split("/")[-1])+ "_controls.vcf")		## bgzip full control file 
	os.system("tabix -p vcf "+str(control_dir)+"/"+str(pwd.split("/")[-1])+ "_controls.vcf.gz")	## tabix full control file
        

	write_file=open("ID.txt","w")                                           ## make ID.txt file
	for item in lib2:
		for file in control_list:
			if str(file.upper()) in str(item.upper()):
				write_file.write(str(file)+"\t"+str(item.split(".")[0])+"\n")

	write_file.close()

       	#os.system("mv "+ +str(control_dir))

	return(lib2)



###################################################
## Determine Sex of all samples in the directory ##
###################################################

def determine_sex():
        os.system(str(filter_file)+" "+str(design_path))       ## filter throught with specific design
	write_file2=open(str(outputfile),"w")                         
	lib = os.listdir(path)
	files=[]
	for item in lib:
		try:
			lib3=os.listdir(path+item)
			for file in lib3:
				if "refiltered_snps.in_targets" in file and "vcf" not in file:
					files+=[path+item+"/"+file]
					action1= str(converter)+" -i " + str(path+item)+"/"+str(file) + " -o "+str(str(path+item+"/"+file)+"_converted2vcf.vcf" + " -no_zip -name "+str(file))
					print action1
					os.system(action1)
		except:
			pass

	for file in files:
		in_file=open(str(file+"_converted2vcf.vcf"),"r")
		lines=in_file.readlines()	
		ind_list=[]
		x_list=[]
		for line in lines:
			if "##" not in line:
				if "#" in line:
					individuals=len(line.split())-9
					x=0
					while x < len(line.split())-9:
						ind_list+=[line.split()[9+x]]
						x+=1
				else: 
					if line.split()[0] == "X":
						if int(line.split()[1]) > 60001 and int(line.split()[1]) <2699520: 		## PAR1
							pass
						elif int(line.split()[1]) > 154931044 and int(line.split()[1]) < 155260560: 	## PAR2
							pass
						elif int(line.split()[1]) in removed_x_markers:
							pass
						else:
							x_list+=[line.split()[9:9+individuals]]
	
		x=0
		for sample in ind_list:
			het=0
			hom=0
			for item in x_list:
				try:
					geno= item[x].split(":")[0]
				except:
					geno= item[x]
				if geno== "0/1" or geno== "1/0":
					het+=1
				if geno == "1/1":
					hom+=1
			total=het+hom
			perc_hom=float((float(hom)/float(total))*100)
			sample=str(sample.split("_")[1])+"_"+str(sample.split("_")[3])+"_"+str(sample.split("_")[4].split(".")[0])
			if perc_hom >=male_cut and total >= min_markers: 
				write_file2.write(str(sample)+"\t" +"MALE"+ "\t"+ "het = "+ str(het)+"\t"+ "hom= "+str(hom)+"\t"+"perc_hom "+ str("%.0f" %(perc_hom))+"\n")
			elif perc_hom >=female_cut and total > min_markers: 
				write_file2.write(str(sample)+"\t" +"possibly MALE"+ "\t"+ "het = "+ str(het)+"\t"+ "hom= "+str(hom)+"\t"+"perc_hom "+ str("%.0f" %(perc_hom))+"\n")
			elif perc_hom < female_cut and total >min_markers:	
				write_file2.write(str(sample)+"\t" +"FEMALE"+ "\t"+ "het = "+ str(het)+"\t"+ "hom= "+str(hom)+"\t"+"perc_hom "+ str("%.0f" %(perc_hom))+"\n")
			else:
				write_file2.write(str(sample)+"\t" +"UNKNOWN"+ "\t"+ "het = "+ str(het)+"\t"+ "hom= "+str(hom)+"\t"+"perc_hom "+ str("%.0f" %(perc_hom))+"\n")
	
			x+=1	
	
	write_file2.close()



##############################
## Calculate run statistics ##
##############################
def calc_stats():
        pwd= commands.getoutput("pwd")
	name=str(pwd.split("/")[-1])+ "_controls_sort.vcf"	
	file=open(str(str(control_dir)+"/"+name),"r")
	try: 
		file2= open("ID.txt","r")
		lines2= file2.readlines()
		ID='off'
	except:
	        print "Automatic ID search enabled. Please check your IDs!"
		ID='on'
	line= file.readline()
	
	while "#" in line:
		if "CHROM" in line:					## make list of all samples within the vcf file
			sample_list=line.split()[9:]
			lines=file.readlines()
			line=[]
		else:
			line= file.readline()

	x=0
	for item in sample_list:
		y=0
		for item2 in sample_list:
			if item==item2 and y!=x:
				print "Warning: "+str(item)+" is present more than once in your vcf"
				sys.exit("Script terminated: fix it!"+"\n"+"bye bye")	
			y+=1
		x+=1

	if ID=='off':							## make dictionary based on input file
		dic={}
		for item in lines2:
	        	splititem=item.split()
       			list=[]
       		 	for item2 in splititem:
       			       	y=0
        	        	for sample in sample_list:
       		                 	if sample == item2:
       		                  	       list+=[y]
                	        	y+=1
        		try:
				dic[list[1]]=list[0]
			except:
				print "Error in sample or control ID;"+str(splititem[0])+" or "+str(splititem[1]) +" does not excist in vcf"
	else:								## make dictionary on automatic sample detection. (->assumes that control_ID is before sample_ID in the vcd columns, and that control_ID is included in sample_ID!)
		dic={}
		x=0
		for item in sample_list:
			y=0
			for item2 in sample_list:
				if item in item2 and item != item2:
					try:
		                		dic[y]= x 			## make dictionairy of NGS samples (->assuming that these are in the back of the file!)
					except:
						print "Error in sample or control ID;"+str(item) +" does not excist in vcf"
	
				
				y+=1
			x+=1


	list=[["## count = number SNPs counted in SNP assay (excluding missing genotypes)"]]
	list+=[["## overlapping = number SNPs overlapping between SNP assay and NGS (thus both have a genotype)"]]
	list+=[["## no_genotype = no genotype within NGS"]]
	list+=[["## true_concordance = exactly matching genotypes between NGS and SNP assay (only for overlapping)"]]
	list+=[["## variant_concordance = variant detected in both NGS and SNP assay (0/1 vs 1/1 and visa versa)"]]
	list+=[["## het_hom= correct variant call but not similar genotype (0/1 vs 1/1 or 1/1 vs 0/1)"]]
	list+=[["## FN = total false negatives (variant call in SNP assay and 0/0 in NGS)"]]
	list+=[["## het_FN = 0/0 in NGS and 0/1 in SNP assay"]]
	list+=[["## hom_FN = 0/0 in NGS and 1/1 in SNP assay"]]
	list+=[["## <15X_FN = number FN SNPS with coverage below 15" ]]
	list+=[["## <40X_FN = number FN SNPS with coverage below 40" ]]
	list+=[["## >40X_FN = number FN SNPS with coverage above 40" ]]
	list+=[["## FP = total false positives (variant call in NGS and 0/0 in SNP assay)"]]
	list+=[["## het_FP = 0/1 in NGS and 0/0 in SNP assay"]]
	list+=[["## hom_FP = 1/1 in NGS and 0/0 in SNP assay"]]
	list+=[["#Run","SampleID(controlID)","Count", "Overlapping", "No_Genotype","TrueConcordance","VariantConc","Het/Hom","FN","het_FN","hom_FN","<15X_FN","<40X_FN",">40X_FN","FP","het_FP","hom_FP"]]
	
	for sample in dic:
		count=0
		missing=0
		true_concordance=0
		variant_concordance=0
	        FN=0
		overlap=0
		under15=0
		under40=0
		over40=0
		FP =0
		het_FP=0
		hom_FP=0
		het_FN=0
		hom_FN=0
		refcount=0
		variantcount=0
		refcountmissing=0
		variantcountmissing=0
		het_hom=0
		write_file=open(str(control_dir)+"/"+str(name.split(".")[0])+"_"+str(sample_list[sample])+"_missing_geno.txt","w")
		write_file2=open(str(control_dir)+"/"+str(name.split(".")[0])+"_"+str(sample_list[sample])+"_wrong_geno.bed","w")
		for item in lines:
			count +=1
			splititem=item.split()
			try:
				splititem[int(sample)+9].split(":")[1] 		## check if NGS call has coverage, if not, report as missing

				## nasty code to check multiallelic variants and convert back to either 0/1 or 1/1:
				if splititem[int(sample)+9].split(":")[0] == "0/2" or splititem[int(sample)+9].split(":")[0] == "0/3" or splititem[int(sample)+9].split(":")[0] == "1/2" or splititem[int(sample)+9].split(":")[0] == "1/3" or splititem[int(sample)+9].split(":")[0] == "2/3":
					splititem[int(sample)+9]= "0/1:"+str(splititem[int(sample)+9].split(":")[1])+":"+str(splititem[int(sample)+9].split(":")[2])+":"+str(splititem[int(sample)+9].split(":")[3])
				if splititem[int(sample)+9].split(":")[0] == "2/2" or splititem[int(sample)+9].split(":")[0] == "3/3":
					splititem[int(sample)+9]= "1/1:"+str(splititem[int(sample)+9].split(":")[1])+":"+str(splititem[int(sample)+9].split(":")[2])+":"+str(splititem[int(sample)+9].split(":")[3])
				##

				overlap+=1
				if splititem[int(dic[sample])+9] == "0/0" and  str(splititem[int(dic[sample])+9]) != ".":
					refcount+=1
				else:
					if str(splititem[int(dic[sample])+9]) != ".":
						variantcount+=1
				try: 						## if control sample has more field (eg coverage etc) 
	                        	splititem[int(dic[sample])+9]=splititem[int(dic[sample])+9].split(":")[0]
	                        except:
	                                pass
	
			
				if splititem[int(sample)+9].split(":")[0] == splititem[int(dic[sample])+9]: 
					true_concordance+=1 			## count equally called genotypes

				else:
					if (splititem[int(dic[sample])+9] == "0/1" and splititem[int(sample)+9].split(":")[0] == "1/1") or (splititem[int(dic[sample])+9] == "1/1" and splititem[int(sample)+9].split(":")[0] == "0/1") :
						variant_concordance+=1	 	## count concordant variant detection for non equally called genotypes (0/1(SNP) vs 1/1(NGS) or 1/1(SNP) vs 0/1(NGS)
						het_hom+=1
					else:

						if str(splititem[int(dic[sample])+9]) == ".": ## remove missing control calls
							overlap-=1
       		                          		count-=1
	
						elif splititem[int(dic[sample])+9] == "0/0" and  splititem[int(sample)+9].split(":")[0] =="0/1":
							het_FP+=1		## count het false positives
							FP+=1
							write_file2.write(str(splititem[0])+"\t"+splititem[1]+"\t"+splititem[1]+"\t"+"het_FP"+"\n")
	
						elif splititem[int(dic[sample])+9] == "0/0" and  splititem[int(sample)+9].split(":")[0] =="1/1":
							hom_FP+=1		## count hom false positives
							FP+=1
							write_file2.write(str(splititem[0])+"\t"+splititem[1]+"\t"+splititem[1]+"\t"+"hom_FP"+"\n")
	
						else:
							if str(splititem[int(dic[sample])+9]) == "0/1":
								het_FN+=1
								write_file2.write(str(splititem[0])+"\t"+splititem[1]+"\t"+splititem[1]+"\t"+"het_FN"+"\n")
							elif str(splititem[int(dic[sample])+9]) == "1/1":
								hom_FN+=1
								write_file2.write(str(splititem[0])+"\t"+splititem[1]+"\t"+splititem[1]+"\t"+"hom_FN"+"\n")
						
						
							FN+=1 		## Count FN, thus 0/0 in NGS and 0/1 or 1/1 in SNP assay
							## count number of FN SNPs with covearage below threshold: 
							samplecov=int(splititem[int(sample)+9].split(":")[1])
							if samplecov < 15:
								under15+=1
							if samplecov < 40:
	                               	        	        under40+=1
							if samplecov >= 40:
								over40+=1
					

			except:
				missing+=1					## count number of variants with missing value in NGS
				write_file.write(str(splititem[0])+"\t"+splititem[1]+"\n")
				
				if splititem[int(dic[sample])+9] == "0/0":
	                                refcountmissing+=1
					write_file2.write(str(splititem[0])+"\t"+splititem[1]+"\t"+splititem[1]+"\t"+"no_geno_ref"+"\n")
	                       
	                        elif splititem[int(dic[sample])+9] == ".":	## removes count if both control as NGS call are not known
					count-=1
					missing-=1
	
				else:
	                                variantcountmissing+=1
					write_file2.write(str(splititem[0])+"\t"+splititem[1]+"\t"+splititem[1]+"\t"+"no_geno_var"+"\n")
		
		list+=[[str(pwd.split("/")[-1:][0]),str(sample_list[sample])+"("+str(sample_list[dic[sample]])+")",count, str(overlap)+" ("+("%.2f" % (float(overlap)/float(count)*100))+"%)",str(missing)+" ("+("%.2f" % (float(missing)/float(count)*100))+"%)",str(true_concordance)+" ("+("%.2f" % (float(true_concordance)/float(overlap)*100))+"%)", str(variant_concordance+true_concordance)+" ("+("%.2f" % (float(true_concordance+variant_concordance)/float(overlap)*100))+"%)", str(het_hom)+" ("+("%.2f" % (float(het_hom)/float(overlap)*100))+"%)",str(FN)+" ("+("%.2f" % (float(FN)/float(overlap)*100))+"%)",str(het_FN)+" ("+("%.2f" % (float(het_FN)/float(overlap)*100))+"%)",str(hom_FN)+" ("+("%.2f" % (float(hom_FN)/float(overlap)*100))+"%)", str(under15)+" ("+("%.2f" % (float(under15)/float(overlap)*100))+"%)", str(under40)+" ("+("%.2f" % (float(under40)/float(overlap)*100))+"%)",str(over40)+" ("+("%.2f" % (float(over40)/float(overlap)*100))+"%)",str(FP)+" ("+("%.2f" % (float(FP)/float(overlap)*100))+"%)",str(het_FP)+" ("+("%.2f" % (float(het_FP)/float(overlap)*100))+"%)",str(hom_FP)+" ("+("%.2f" % (float(hom_FP)/float(overlap)*100))+"%)"]]


	write_file.close()
	write_file2.close()
	write_file3=open(str(pwd.split("/")[-1:][0])+"_control_stats.txt","w")
	
	for item in list: 	## print into file
		for value in item:
			write_file3.write(str(value).rstrip()+"\t")
		write_file3.write("\n")
	
	write_file3.close()

#####################
## Other functions ##
#####################

def check_design():
	if opt.design is not "diag_ss":
        	try:
			dic_design[opt.design]
     			print "Design = " +opt.design
             	except:
                	print opt.design+" is not known. See help (-h) for details"
                        sys.exit("bye bye")
       	else:
        	print "Design = "+opt.design


def check_output():
	if opt.output is not "sample_sex.txt":
		print "Output file = " +opt.output
	else:
		print  "Output file  = "+opt.output

def check_runid():
	if opt.runid is not "off":
                print "Only files with run ID \"" +opt.runid + "\" are used"
        else:
                print  "runid was not used"




#########################################################################################################



#########################
## hardcoded variables ##
#########################

control_list=["man1","man2","vrouw1","vrouw2"]
path="./"
wdir = str("/".join(sys.argv[0].split("/")[:-1]))+"/"
### Make dictionary of Design config file (design.conf)
design_file=open(str(wdir)+"design.conf","r").readlines()
dic_design={}
design_list=[]
for line in design_file:
        splitline=line.split()
	if "#" not in splitline[0]:
		dic_design[splitline[0]]= wdir+str(splitline[1])
		design_list+=[splitline[0]]
printline=""
for name in design_list: 
	printline+="("+name+") "

removed_x_markers=[47003920,48382174,1414397,100629554,100612455,7258773,132888141,31986656,38240586,64956699,1419571,1422868,1422943,100612455,1404832,1428421,1409420,1414419,123041043,1401646,1407797] ## markers removed because they were recurrently incorrect within males

###########
## START ##
###########

if __name__ == "__main__":
        from optparse import OptionParser
        from optparse import OptionGroup
        parser = OptionParser();

        group = OptionGroup(parser, "Main options")
        group.add_option("-f", default=False, dest="full", action="store_true", help="perform a full run")
        group.add_option("-m", default=False, dest="merge",action="store_true", help="merge samples only")
	group.add_option("-k", default=False, dest="mergecontrols",action="store_true", help="merge controls only")
        group.add_option("-c", default=False, dest="stats",action="store_true", help="calculate stats only")
        group.add_option("-s", default=False, dest="sex",action="store_true", help="determine sex only")
	parser.add_option_group(group)
        
	group = OptionGroup(parser, "Additional options")
	#group.add_option("-d", default="diag_ss", dest="design", metavar="[design]", help="DESIGNS:\t\t\t\t\t\tdiag_ss\t\t(elid0395321)\t\t\t\t\tlabarray\t(elid032975)\t\t\t\t\tPID\t\t(PID array)\t\t\t\t\tPID_AUTOINF_SS\t(elid0451131)\t\t\t\t\tDiag_lab2\t(elid= ?)\t\t\t\t\tDiag_lab3\t(elid= ?)\t\t\t\t\tDiag_lab4\t(elid= ?)\t\t\t\t\tDiag_lab5\t(elid= ?) ")
	group.add_option("-d", default="Diagv1", dest="design", metavar="[design]", help="DESIGNS [default = Diagv1] "+str(printline))
        group.add_option("-o", default="sample_sex.txt", dest="output", metavar="[output name]", help= "output file name for sex determination file [default = sample_sex.txt]")
        group.add_option("-r", default="off", dest="runid", metavar="[runID]", help="use specific run ID [default = off]")
	group.add_option("-n", default=4, dest="controls", metavar="[controlsrunID]", help="number of controls used [default = 4]")

        group.add_option("-D", default= wdir+"filter_trough_designed_area.pl", dest="filter", metavar="[PATH]", help="path for filter_trough_designed script [default = "+wdir+"filter_trough_designed_area_reference.pl])")
	group.add_option("-C", default= wdir+"vcfConverter.pl", dest="converter", metavar="[PATH]", help=" path for vcf converter [default = "+wdir+"vcfConverter.pl])")
	group.add_option("-V", default= "vcf-merge", dest="vcftools", metavar="[PATH]", help="path to vcftools merge [default = vcf-merge])")
	group.add_option("-S", default= wdir, dest="controlsamplesdir", metavar="[PATH]", help="path to folder with in target control vcfs [default = "+wdir+"]")
        group.add_option("-R", default= "10", dest="minmarker", metavar="[INT]", help="minimum number of markers required to call male/female [default = 10])")
        group.add_option("-M", default= "90", dest="male", metavar="[INT]", help="minimum percentage hom to call a MALE [default = 90 ])")
        group.add_option("-F", default= "80", dest="female", metavar="[INT]", help="maximum percentage hom to a FEMALE [default = 80])")
        parser.add_option_group(group)
        (opt, args) = parser.parse_args()

        filter_file= str(opt.filter)
        converter=str(opt.converter)
        vcftools= str(opt.vcftools)
        control_sample_dir=str(opt.controlsamplesdir)
        min_markers = int(opt.minmarker)
        male_cut=int(opt.male)
        female_cut=int(opt.female)        

	## check input parameters ##
	check_design()
	check_output()
	check_runid()
	
	runid=str(opt.runid)
	design_path=dic_design[str(opt.design)]
	design=str(opt.design)
	outputfile=str(opt.output)
	dic_merged=[]
	dic_control=[]
	
        log_dir= "Control_stats_log_files"
	control_dir="Control_files"
	sample_dir="Sample_files"

	os.system("mkdir "+str(log_dir))
	os.system("mkdir "+str(control_dir))
	os.system("mkdir "+str(sample_dir))
	date_run= str(datetime.datetime.now())
	date_run= str(date_run.split()[0].replace("-", ""))+str(date_run.split()[1].replace(":", "").split(".")[0])[0:4]

	config_file=open(str(log_dir)+"/control_stats_merge_"+str(date_run)+".conf","w")
        config_file.write("Date:\t\t\t\t"+str(commands.getoutput("date"))+"\n")
        config_file.write("Script filename:\t\t"+ str(sys.argv[0])+"\n")
        config_file.write("SVN Revision:\t\t\t"+ str(os.popen('svn info %s | grep "Last Changed Rev" ' % str(sys.argv[0]), "r").readline().replace("Last Changed Rev: ","")))

	if (opt.full):
		print "Option = Full run (-f)"

		config_file.write("Run options used:\t\tfull run (-f)"+"\n")
        	config_file.write("Design:\t\t\t\t"+opt.design+"\n")
        	config_file.write("Design bed file:\t\t"+str(dic_design[design])+"\n")
                config_file.write("Number of control samples:\t"+str(opt.controls)+"\n")
                config_file.write("Control samples file:\t\t"+str(control_sample_dir)+"control_samples_"+str(design)+".vcf.gz"+"\n")

		## Run requested scripts ##
		dic_merged=merge_files()
		dic_control=merge_controls()
                calc_stats()
                determine_sex()
	
	elif (opt.merge) and opt.full is not True and opt.stats is not True and opt.sex is not True and opt.mergecontrols is not True:
		print "Option = Merge samples only (-m)"
 		config_file.write("Run options used:\t\tMerge samples only (-m)"+"\n")
		## Run requested scripts ##
		dic_merged=merge_files()

        elif (opt.mergecontrols) and opt.full is not True and opt.stats is not True and opt.sex is not True and opt.merge is not True:
                print "Option = Merge controls only (-k)"
                config_file.write("Run options used:\t\tMerge controls only (-m)"+"\n")
                config_file.write("Design:\t\t\t\t"+opt.design+"\n")
                config_file.write("Design bed file:\t\t"+str(dic_design[design])+"\n")
        	config_file.write("Number of control samples:\t"+str(opt.controls)+"\n")
        	config_file.write("Control samples file:\t\t"+str(control_sample_dir)+"control_samples_"+str(design)+".vcf.gz"+"\n")
                ## Run requested scripts ##
                dic_control=merge_controls()

        elif (opt.stats) and opt.full is not True and opt.merge is not True and opt.sex is not True and opt.mergecontrols is not True:
                print "Option = Calculate stats only (-c) "
                config_file.write("Run options used:\t\tCalculate stats only (-c)"+"\n")
		config_file.write("Number of control samples:\t"+str(opt.controls)+"\n")
        	config_file.write("Control samples file:\t\t"+str(control_sample_dir)+"control_samples_"+str(design)+".vcf.gz"+"\n")

		try:
			calc_stats()
		except:
			sys.exit("Please run merge (-k) first")
	
        elif (opt.sex) and opt.full is not True and opt.stats is not True and opt.merge is not True and opt.mergecontrols is not True:
                print "Option = Determine sex only (-s) "
		config_file.write("Run options used:\t\tDetermine sex only (-s)"+"\n")
		## Run requested scripts ##
		determine_sex()
	
	elif (opt.mergecontrols) and opt.stats is True and opt.full is not True and opt.merge is not True and opt.sex is not True:
		print "Option = Diagnostics pipeline settings (-k and -c) "
		config_file.write("Run options used:\t\t Diagnostics pipeline settings (-k and -c)"+"\n")
                ## Run requested scripts ##
                dic_merged=merge_controls()
                calc_stats()

	else:
		print "Please other main options. For now, only -k an -c can be combined. Other options need to be run all together (-f) or seperately. See help (-h) for details"
		sys.exit("bye bye")


        if opt.runid is not "off":
        	config_file.write("Run ID:\t\t\t\tON\t" +opt.runid+"\n")
        else:
        	config_file.write("Run ID:\t\t\t\tOFF""\n")
        config_file.write("Filter trough design script:\t"+opt.filter+"\n")
        config_file.write("VCF converter tool:\t\t"+opt.converter+"\n")
        config_file.write("Vcf-merge tool:\t\t\t"+opt.vcftools+"\n")
        config_file.write("Output file sex determination:\t" +opt.output+"\n")
        config_file.write("Sex determination settings:\n\t\t\t\tMinmarker:\t"+str(opt.minmarker)+"\n\t\t\t\tMale cutoff:\t"+str(opt.male)+"%\n\t\t\t\tFemale cutoff:\t"+str(opt.female)+"%\n")
       	config_file.close()



## if run completes, remove single sample vcf.gz files:
for item in dic_merged:
	os.system("rm "+str(item))     
        os.system("rm "+str(item)+".tbi")     
for item in dic_control:
        os.system("rm "+str(item))     
        os.system("rm "+str(item)+".tbi")             

action1="find -iname \"*in_target*\" -exec rm -rf {} \; "
action2="find -iname \"*outside*\" -exec rm -rf {} \; "

#print action1
#print action2
os.popen(str(action1))
os.popen(str(action2))

#os.system(action1)
#os.system(action2)
#os.system("find -iname \"*converted2vcf*\"")


sys.exit("finished")	


