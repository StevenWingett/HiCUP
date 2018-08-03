#Produce pie charts summarising the hicup_filter results
#Launched by hicup_truncater
args <- commandArgs(TRUE)

summaryFile <- args[1]
outdir <- args[2]
outSuffix <- args[3]

data <- read.delim(summaryFile, header=FALSE, skip=1) 

if(length(data) > 0){

  for (i in 1:nrow(data)) {
    line <- data[i,]
    file <- line[,1]
    valid <- line[,3]
    circ <- line[,8]
    dangling <- line[,9]
    internal <- line[,10]
    religation <- line[,11]
    contiguous <-line[,12]
    wrongSize <-line[,13]
    
    total <-line[,2]
    percValid <- round( (100 * valid / total), 0.1)
    
    outputfilename=paste(outdir, file, outSuffix, sep = "")
    svg(file=outputfilename)
    
    pieTitle <- paste( "Filter results\n", file, "\nValid ditags: ", valid,
                       "\nPercent valid: ", percValid, "%",  sep = "")
    
    pcData <- c(valid, circ, dangling, internal, religation, contiguous, wrongSize)
    percLabels <- round(pcData / total * 100, 1)
    percLabels<- paste(percLabels, "%", sep="")
    
    par(oma=c(4,0,0,0))
    par(mar=c(0,0,2,0))
    
  	pie  (pcData, 
      	labels=percLabels,
          main=pieTitle,
          cex.main = 1,
          #cex.label = 0.5,
          col = rainbow(7),
    )

  	par(oma=c(0,0,0,0))
  	par(mar=c(0, 0, 0, 0))


  	legend("bottom", c("Valid", "Same circularised", "Same dangling ends", "Same internal", 
                     "Religation", "Contiguous", "Wrong size"), 
                     ncol=2, cex=0.8, fill=rainbow(7))

  	dev.off()
    
  } 

}else{
  no_data_message = paste("R: No data in ", summaryFile)
  print(no_data_message)
}



