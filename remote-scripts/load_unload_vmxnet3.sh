#!/bin/bash
#######################################################################################
## Description:
##   This script used to load/unload vmxnet3.
#######################################################################################
## Revision:
##   v1.0.0 - xinhu - 01/09/2017 - Draft script for load/unload vmxnet3 for 1 hour. 
#######################################################################################
estart=$(date "+%s")
etime=$[ $(date "+%s") - $estart ]
while [ $etime -lt $1 ]
do
    modprobe -r vmxnet3
    modprobe vmxnet3
    etime=$[ $(date "+%s") - $estart ]
    #echo "DEBUG: have execute $time s"
done
echo "DEBUG: execute $etime s from $estart"
systemctl restart NetworkManager
Sleep 6 