#!/bin/bash

###############################################################################
##
## Description:
##   Check vmcore is created and size is correct
##   Find vmcore; vmcore size is correct
##
###############################################################################
##
## Revision:
## v1.0 - boyang - 18/01/2017 - Build script.
##
###############################################################################

dos2unix utils.sh

#
# Source utils.sh
#
. utils.sh || {
    echo "Error: unable to source utils.sh!"
    exit 1
}

#
# Source constants file and initialize most common variables
#
UtilsInit

###############################################################################
##
## Main Body
##
###############################################################################

LogMsg "Start to check vmcore......."
UpdateSummary "Start to check vmcore......."
find /var/crash/*/vmcore -type f -size +10M
if [ $? -eq 0 ]
then
	LogMsg "SUCCESS: Proper file was found."
	UpdateSummary "SUCCESS: Proper file was found"
else 
	LogMsg "FAIL: No file was found in /var/crash of size greater than 10M."
	UpdateSummary "FAIL: No file was found in /var/crash of size greater than 10M."
	exit 1
fi
