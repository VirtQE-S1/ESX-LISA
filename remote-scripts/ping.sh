#!/bin/bash
#######################################################################################
## Description:
##   This script used to time the ping.
#######################################################################################
## Revision:
##   v1.0.0 - xinhu - 01/09/2017 - Draft script for ping -f 1 hour. 
#######################################################################################
start=$(date "+%s")
time=$[$(date "+%s")-$start]
while [ $time -lt $1 ]
do
time=$[$(date "+%s")-$start]
done
PIDs=`ps -au | grep "ping -f"`
PID=`echo ${PIDs[0]}|awk '{print $2}'`
kill -9 $PID
echo "DEBUG: execute $time s from $start"
