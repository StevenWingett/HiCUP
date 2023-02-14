###################################################################################
###################################################################################
##This file is Copyright (C) 2022, Steven Wingett                                ##
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
    uniques <- line[,3]
    cisClose <- line[,4]
    cisFar <- line[,5]
    trans <- line[,6]
    
    outputfilename <- paste(outdir, fileInSummary, sep = "")
    outputfilename <- paste(outputfilename, outSuffix, sep = "")
    svg(file=outputfilename)
    
    pieTitle <- paste( "Deduplicator cis/trans results\n", fileInSummary,  sep = "")
    
    pcData <- c(cisClose, cisFar, trans)
    pcLabels <- c("Cis Close (<10kbp)", "Cis Far (>10kbps)", "Trans" )
    percLabels <- round((100 * pcData / uniques), 2)
    percLabels <- paste(percLabels, "%", sep="")

    par(oma=c(4,0,0,0))
    par(mar=c(0,0,2,0))
    
  	pie  (   pcData, 
      	     labels=percLabels,
              main=pieTitle,
              cex.main=1,
              col=rainbow(7),
              clockwise=TRUE
    )

  	par(oma=c(0,0,0,0))
  	par(mar=c(0, 0, 0, 0))

  	legend("bottom", pcLabels, ncol=2, cex=0.8, fill=rainbow(7))

  	dev.off()
    
  } 

}else{
  no_data_message = paste("R: No data in ", file)
  print(no_data_message)
}
