#！/bin/bash

###############################################################################
##
## Description:
##   This script do partition and format the new disk.
##  
###############################################################################
##
## Revision:
## v1.0 - junfwang - 02/01/2018 - Draft script for case stor_add_indepandent_disk.
##
###############################################################################

dos2unix utils.sh

# Source utils.sh
. utils.sh || {
    echo "Error: unable to source utils.sh!"
    exit 1
}

# Source constants file and initialize most common variables
UtilsInit

###############################################################################
##
## Main Body
##
###############################################################################

#do partition of /dev/sdb
fdisk /dev/sdb <<EOF
n
p
1


w
EOF
#format /dev/sdb1
mkfs.ext3 /dev/sdb1
disk=$(fdisk -l|grep sdb1|wc -l)
if [ $disk = "1" ];then
   SetTestStateCompleted
   exit 0
else 
   SetTestStateAborted
   exit 1
fi