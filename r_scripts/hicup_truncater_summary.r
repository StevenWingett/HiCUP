#Produce bar charts showing the number of reads truncated/not truncated by hicup_truncater
#Launched by hicup_truncater
args <- commandArgs(TRUE)
outdir <- args[1]
file <- args[2]

data <- read.delim(file, header=FALSE, skip=1) 

if(length(data) > 0){
  
  for (i in 1:nrow(data)) {
    line <- data[i,]
    file <- line[,1]
    truncated <- line[,3]
    notTruncated <- line[,5]
    percTruncated <- line[,4]
    avTruncated <- line[,7]

    outputfilename=paste(file, "truncation_barchart.svg", sep = ".")
    outputfilename=paste(outdir, outputfilename, sep = "")
    
    svg(file=outputfilename)
    
    graphTitle <- paste( file, " Truncation Results\n","Percent truncated: ", percTruncated, 
                        "\nAverage length truncated read(bp): ", avTruncated,  sep = "")
    
    bpData <- c(truncated, notTruncated) 
    bp <- barplot(bpData,
            names.arg = c("Truncated", "Not Truncated"),
            main = graphTitle,
            col=c("red","lightblue"),
    )

     text( bp, bpData, bpData, cex=1, pos=1) 

    dev.off()
    
  }  

}else{
  no_data_message = paste("R: No data in ", file)
  print(no_data_message)
}

