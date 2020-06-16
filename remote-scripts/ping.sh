#!/bin/bash
#######################################################################################
## Description:
##   This script used to time the ping.
#######################################################################################
## Revision:
##   v1.0.0 - xinhu - 10/18/2019 - Draft script for ping -f 1 hour.
##   v1.0.1 - xinhu - 11/07/2019 - Add the ping command  
#######################################################################################
nohup ping -f $2 &
estart=$(date "+%s")
etime=$[ $(date "+%s") - $estart ]
while [ $etime -lt $1 ]
do
    etime=$[ $(date "+%s") - $estart ]
done
PIDs=`ps -au | grep "ping -f"`
PID=`echo ${PIDs[0]}|awk '{print $2}'`
kill -9 $PID
echo "DEBUG: execute $etime s from $estart"