#!/bin/bash

###############################################################################
## 
## Description:
##   What does this script?
##   What's the result the case expected?
## 
###############################################################################
##
## Revision:
## v1.0 - xiaofwan - 1/6/2017 - Draft shell script as test script.
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
## Put your test script here
## NOTES:
## 1. Please use LogMsg to output log to terminal.
## 2. Please use UpdateSummary to output log to summary.log file.
## 3. Please use SetTestStateFailed, SetTestStateAborted, SetTestStateCompleted,
##    and SetTestStateRunning to mark test status. 
##
###############################################################################


# Download compressed file from given url

url=https://fast.dpdk.org/rel/dpdk-18.02.2.tar.xz
LogMsg $url
filename=$(curl -skIL $url | grep -o -E 'filename=.*$' | sed -e 's/filename=//')
filename="$(echo -e "${filename}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

if [ ${#filename} -le 1 ]
then
    url_arr=(${url//\// })
    filename="${url_arr[-1]}"
fi

LogMsg $filename

if [ ! -f "$filename" ]
then
    LogMsg "Source Code Not Exist"
    wget $url
    if [ ! "$?" -eq 0 ]
    then
        LogMsg "Source Code Download Failed"
        SetTestStateAborted
    fi

fi

# Install required packages

yum install elfutils-libelf-devel  elfutils-devel \
    make gcc glibc-devel kernel-devel numactl-devel numactl-libs python-devel -y


# Enable Hugepages support

echo 2048 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
mkdir /mnt/huge
mount -t hugetlbfs nodev /mnt/huge
echo "nodev /mnt/huge hugetlbfs defaults 0 0" >> /etc/fstab

if [ ! "$?" -eq 0 ]
then
    LogMsg "Huge Pages Failed"
    SetTestStateAborted
fi

cpu_num=`cat /proc/cpuinfo | grep "processor" | wc -l`

LogMsg $cpu_num
UpdateSummary $cpu_num


# Uncompressed file and compile 

folder=`tar -xvf $filename | awk 'NR==1{print}' | cut -d/ -f1`

cd $folder
let folder=pwd
make config T=x86_64-native-linuxapp-gcc

LogMsg "Start Compile"

RTE_TARGET=x86_64-native-linuxapp-gcc


RTE_SDK=`pwd`
make -j8 install T=$RTE_TARGET
status=$?
if [ ! "$status" -eq 0 ]
then
    SetTestStateFailed
else
    LogMsg "RTE_SDK is $RTE_SDK"
    LogMsg "RTE_TARGET is $RTE_TARGET"
    echo "export RTE_SDK=$RTE_SDK" > /etc/profile.d/dpdk.sh
    echo "export RTE_TARGET=$RTE_TARGET" >> /etc/profile.d/dpdk.sh

    source /etc/profile.d/dpdk.sh
    SetTestStateCompleted
fi
