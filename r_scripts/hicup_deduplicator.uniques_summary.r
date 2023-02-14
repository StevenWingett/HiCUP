###################################################################################
###################################################################################
##This file is Copyright (C) 2023, Steven Wingett                                ##
##                                                                               ##
##                                                                               ##
##This file is part of HiCUP.                                                    ##
##                                                                               ##
##HiCUP is free software: you can redistribute it and/or modify                  ##
##it under the terms of the GNU General Public License as published by           ##
##the Free Software Foundation, either version 3 of the License, or              ##
##(at your option) any later version.                                            ##
##                                                                               ##
##HiCUP is distributed in the hope that it will be useful,                       ##
##but WITHOUT ANY WARRANTY; without even the implied warranty of                 ##
##MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                  ##
##GNU General Public License for more details.                                   ##
##                                                                               ##
##You should have received a copy of the GNU General Public License              ##
##along with HiCUP.  If not, see <http://www.gnu.org/licenses/>.                 ##
###################################################################################
###################################################################################


#Produce pie charts summarising the hicup_deduplicator results
#Launched by hicup_deduplicator
args <- commandArgs(TRUE)
outdir <- args[1]
file <- args[2]
outSuffix <- args[3]

data <- read.delim(file, header=FALSE, skip=1)

if(length(data) > 0){

  for (i in 1:nrow(data)) {
    line <- data[i,]
    fileInSummary <- line[,1]
    total <- line[,2]
    uniques <- line[,3]

    percUniques <- round( (100 * uniques / total), 2 )
    
    outputfilename <- paste(outdir, fileInSummary, sep="")
    outputfilename <- paste(outputfilename, outSuffix, sep = "")
    svg(file=outputfilename)
    
    graphTitle <- paste( fileInSummary, "\nDitag De-duplication results","\nUnique di-tags: ", percUniques, "%", sep = "")

    bpData <- c(total, uniques) 
    bp <- barplot(bpData,
            names.arg = c("Before de-duplication", "After de-duplication"),
            main = graphTitle,
            col=rainbow(2),
    )

     text( bp, bpData, bpData, cex=1, pos=1) 
   
    garbage <- dev.off()
    
  } 

}else{
  no_data_message = paste("R: No data in ", file)
  print(no_data_message)
}
