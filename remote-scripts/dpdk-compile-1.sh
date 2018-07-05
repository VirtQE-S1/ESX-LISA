#!/bin/bash

###############################################################################
##
## Description:
##   compile DPDK and make sure it's working
##
###############################################################################
##
## Revision:
## v1.0.0 - ruqin - 7/5/2018 - Build the script
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


: '
        <test>
            <testName>DPDK-Compile</testName>
            <testID>ESX-DPDK-001</testID>
            <setupScript>
                <file>setupscripts\change_cpu.ps1</file>
                <file>setupscripts\change_memory.ps1</file>
                <file>setupscripts\add_vmxnet3.ps1</file>
                <file>setupscripts\add_vmxnet3.ps1</file>
                <file>setupscripts\add_vmxnet3.ps1</file>
            </setupScript>
            <testScript>dpdk-compile-1.sh</testScript>
            <files>remote-scripts/dpdk-compile-1.sh</files>
            <files>remote-scripts/utils.sh</files>
            <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
            <testParams>
                <param>VCPU=8</param>
                <param>VMMemory=8GB</param>
                <param>TC_COVERED=DEMO-01</param>
            </testParams>
            <timeout>600</timeout>
            <onError>Continue</onError>
            <noReboot>True</noReboot>
        </test>
'

SetTestStateFailed

# Download compressed file from given url

GetDistro

LogMsg $DISTRO

if [ "$DISTRO" == "redhat_7" ]; then
    LogMsg "RHEL7"
    UpdateSummary "RHEL7"
    url=https://fast.dpdk.org/rel/dpdk-18.02.2.tar.xz
elif [ "$DISTRO" == "redhat_8" ]; then
    LogMsg "RHEL8"
    UpdateSummary "RHEL8"
    url=https://fast.dpdk.org/rel/dpdk-18.02.1.tar.xz
else
    SetTestStateAborted
    LogMsg "Not support rhel6"
    exit 1
fi


# if [ "$(./usertools/dpdk-devbind.py -s | grep unused=igb_uio | wc -l)"  -gt 3 ];
# then
#     count=0
#     for i in $(./usertools/dpdk-devbind.py -s | grep unused=igb_uio | awk 'NR>0{print}'\
#     |  awk 'BEGIN{FS="="}{print $2}' | awk '{print $1}');
#     do
#         if [ "$i" != "$Server_Adapter" ];
#         then
#             LogMsg "Will Disconnect $i"
#             nmcli device disconnect "$i"
#             count=$((count + 1))

#             if [ $count -eq 2 ]; then
#                 break
#             fi
#         fi
#     done
# else
#     LogMsg "Failed Not Enough Netowrk Adapter"
#     SetTestStateAborted
#     exit 1
# fi



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
