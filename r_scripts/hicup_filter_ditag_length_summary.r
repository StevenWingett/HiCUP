#Produce line graph summarising the di-tag size distribution
#Launched by hicup_filter
args <- commandArgs(TRUE)
outdir <- args[1]
file <- args[2]

data <- read.delim(file, header=FALSE, skip=1) 

if(length(data) > 0){

	outputfilename <- basename(file)
	outputfilename <- paste(outputfilename, "svg", sep = ".")
	outputfilename <- paste(outdir, outputfilename, sep = "")
	svg(file=outputfilename)

	data <- read.delim(file, header=FALSE, skip=0) 

	plot (data, type="l", xlab="Di-tag length (bps)",
	     ylab="Frequency", main="Di-tag frequency Vs Length"
	    )

	garbage <- dev.off()

}else{
  no_data_message = paste("R: No data in ", file)
  print(no_data_message)
}
