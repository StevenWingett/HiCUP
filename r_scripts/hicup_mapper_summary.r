#Produce bar charts showing the number of reads mapped/not mapped by hicup_mapper
#Launched by hicup_mapper
args <- commandArgs(TRUE)
outdir <- args[1]
file <- args[2]

data <- read.delim(file, header=FALSE, skip=1) 

if(length(data) > 0){
  
  for (i in 1:nrow(data)) {
    line <- data[i,]
    file <- line[,1]
    tooShort <- line[,3]
    unique <- line[,5]
    multi <- line[,7]
    notAlign <- line[,9]
    paired <- line[,11]
    percPaired <- line[12]

    outputfilename=paste(file,"mapper_barchart.svg", sep = ".")
    outputfilename=paste(outdir, outputfilename, sep = "")
    svg(file=outputfilename)
    
    graphTitle <- paste( file, " Mapping Results\n","Percent paired: ", percPaired,  sep = "")

    bpData <- c(tooShort, unique, multi, notAlign, paired) 
    bp <- barplot(bpData,
            names.arg = c("Too short", "Unique", "Multi", 'Not align', 'Paired'),
            main = graphTitle,
            col=c("red","green","blue","orange","yellow"),
    )

     text( bp, bpData, bpData, cex=1, pos=1) 
 
    dev.off()   
  }  

}else{
  no_data_message = paste("R: No data in ", file)
  print(no_data_message)
}


