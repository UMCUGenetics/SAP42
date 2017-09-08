#! /usr/bin/env python
import sys, os, re
import commands
import getopt

# AUTHOR:       M.G. Elferink
# DATE:         06-02-2013
# PROGRAM:      check_for_errors.py
# USAGE:        check_for_errors.py  
# PURPOSE:      check all folders for presence of fastq chunks, sorted bam files, NoGo files, pileup files, and if the vap42.txt files are empty

##FUNCTIONS##
def check_samples(lane):
	#print "hello",lane,commands.getoutput("ls -l "+str(lane)+" | egrep \'^d\'").split("F3")
	return (len(commands.getoutput("ls -l "+str(lane)+" | egrep \'^d\'").split("F3"))-1)  ## -1 because split on F3 for last files

def uniq(input):
  output = []
  for x in input:
    if x not in output:
      output.append(x)
  return output


##START##
pwd= commands.getoutput("pwd")
error=0
write_file=open(str(pwd)+"/check.log","w")

## check number of samples within lanes
lanes= commands.getoutput("find -iname \"*_0?\" -type d").split()	
list=[]
for lane in lanes:
	write_file.write(str(lane)+"\t"+str(check_samples(lane))+"\n")
	list += [check_samples(lane)]

if len(uniq(list)) == 1:
	samples= int(uniq(list)[0])
else:
	#print "WARNING, some lanes have different number of samples. See log file"
	samples=0
	error+=1


## search for NoGo files ##
nogo= commands.getoutput("find -iname \"nogo*\" ").split()
if len(nogo)>0:
	#print "WARNING: There are NoGo files present. See log file"
	error+=1
	write_file.write("WARNING: There are NoGo files present:"+"\n")
	for item in nogo:
		write_file.write("\t"+ str(item)+"\n")
	
## check number of merged samples compared to lanes
merged_dir=commands.getoutput("find -iname \"merged*\" -type d").split()
if int(samples) != int(len(merged_dir)): 
	#print "WARNING: Number of merged samples do not match with number of samples in lanes. See log file"
	write_file.write("WARNING:Number of merged samples do not match with number of samples in lanes."+ "\t"+"samples in lanes= "+str(samples)+"\t"+"samples merged= "+ str(len(merged_dir))+"\n")
	error+=1

for folder in merged_dir:
	vap42= commands.getoutput("wc -l "+str(folder)+"/vap42.txt").split()
	try:
		if int(vap42[0]) > 0:
			#print "WARNING: non-empty vap42.txt files. See log file"
			write_file.write("WARNING: non-empty vap42.txt files:"+"\t"+str(vap42[0])+"\t"+str(vap42[1])+"\n")
			error+=1
	except:
		print"vap42.txt missing"+ str(vap42)
## check for fastq chunk left-overs 
reads_dir=commands.getoutput("find -iname \"reads\" -type d").split()
	
for item in reads_dir:
	if "merged" not in item:
		if len(commands.getoutput("find "+str(item)+" -iname \"*fastq\"").split())>0:
			#print "WARNING: fastq chunks are found. See log file"
			write_file.write("WARNING: fastq chunk: "+"\n")
			for item in commands.getoutput("find "+str(item)+" -iname \"*fastq\"").split():
				 write_file.write("\t"+str(item)+"\n")
			error+=1

## check for sorted BAM files and pileup files
results_dir=commands.getoutput("find -iname \"results\" -type d").split()
for results in results_dir:     ## check sorted BAM files within results folder of the lanes (Mapping related)
        if "merged" not in results:
		if len(commands.getoutput("find "+str(results)+" -iname \"*sorted.bam\"").split())>0:
                        write_file.write("WARNING: sorted_bam: "+"\n")
                        for item in commands.getoutput("find "+str(results)+" -iname \"*sorted.bam\"").split():
                                 write_file.write("\t"+str(item)+"\n")
                        error+=1

for results in results_dir:     ## check pileup files  within merged folders (SNP-calling related)
        if "merged" in results:
                if len(commands.getoutput("find "+str(results)+" -iname \"*pileup\"").split())>0:
                        write_file.write("WARNING: pileup file: "+"\n")
                        for item in commands.getoutput("find "+str(results)+" -iname \"*pileup\"").split():
                                 write_file.write("\t"+str(item)+"\n")
                        error+=1

if error == 0:
	print "No warnings found. Sweet!"
	write_file.write("\n"+"No warnings found. Sweet!"+"\n")
else:
	print "There are warnings. Check the log file for details"


write_file.close()
sys.exit()
