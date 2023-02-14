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
