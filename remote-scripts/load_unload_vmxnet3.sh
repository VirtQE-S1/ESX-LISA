#!/bin/bash
#######################################################################################
## Description:
##   This script used to load/unload vmxnet3.
#######################################################################################
## Revision:
##   v1.0.0 - xinhu - 01/09/2017 - Draft script for load/unload vmxnet3 for 1 hour. 
#######################################################################################
start=$(date "+%s")
time=$[$(date "+%s")-$start]
while [ $time -lt $1 ]
do
modprobe -r vmxnet3
modprobe vmxnet3
time=$[$(date "+%s")-$start]
#echo "DEBUG: have execute $time s"
done
echo "DEBUG: execute $time s from $start"
systemctl restart NetworkManager
Sleep 6