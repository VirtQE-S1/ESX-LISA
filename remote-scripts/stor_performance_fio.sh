#!/bin/bash

###############################################################################
##
## Description:
##  Test the guest SCSI,NVMe,IDE controller disk performance with fio tool.
##
###############################################################################
##
## Revision:
## v1.0.0 - ldu - 8/20/2018 - Build the script
##
###############################################################################


dos2unix utils.sh


# Source utils.sh
. utils.sh || {
    echo "Error: unable to source utils.sh!"
    exit 1
}


# Source constants.sh to get all paramters from XML <testParams>
. constants.sh || {
    echo "Error: unable to source constants.sh!"
    exit 1
}


# Source constants file and initialize most common variables
UtilsInit


###############################################################################
##
## Main
##
###############################################################################
#Check the guest version which use python2.x, so install pip
if [[ $DISTRO != "redhat_8" ]]; then
    yum install -y python-yaml
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
    python get-pip.py
    pip install click pandas numpy scipy
    UpdateSummary "For rhel6 and rhel7, python2.x use pip"
else
    yum install python3-yaml -y
    pip3 install click pandas numpy scipy   
    #For RHEL8, manually create soft link python point to python3.
    ln -s /usr/bin/python3 /usr/bin/python
    UpdateSummary "For rhel8, use pip3 install modules"
fi

#pip install required python modules.
yum install nfs-utils make -y
 
#install storage performance tool fio and other required packages.
wget https://github.com/axboe/fio/archive/fio-3.2.tar.gz
tar -zxvf fio-3.2.tar.gz
cd fio-fio-3.2
make && make install
if [ ! "$?" -eq 0 ]; then
    LogMsg "ERROR:  install fio failed"
    UpdateSummary "ERROR:  install fio failed"
    SetTestStateAborted
    exit 1
else
    UpdateSummary "Fio install passed."
fi

#Check the new added Test disk /dev/$disk exist.
ls /dev/$disk
if [ ! "$?" -eq 0 ]; then
    LogMsg "Test Failed.Test disk /dev/$disk not exist."
    UpdateSummary "Test failed.Test disk /dev/$disk not exist."
    SetTestStateAborted
    exit 1
else
    LogMsg " Test disk /dev/$disk exist."
    UpdateSummary "Test disk /dev/$disk exist."
fi

# Do Partition for Test disk if needed.
if [[ $FS != raw ]];then

    fdisk /dev/$disk <<EOF
        n
        p
        1


        w
EOF

    # Get new partition
    kpartx /dev/$disk

    # Wait a while
    sleep 6

    # Format with file system
    if [[ $DiskType = NVMe ]]; then
        mkfs.$FS /dev/"$disk"p1
        UpdateSummary "format with $FS filesystem"
        #Mount  disk to /$disk.
        mkdir /test
        mount /dev/"$disk"p1 /test
        if [ ! "$?" -eq 0 ]
        then
            LogMsg "Mount Failed"
            UpdateSummary "FAIL: Mount Failed"
            SetTestStateAborted
            exit 1
        else
            LogMsg "Mount disk successfully"
            UpdateSummary "Passed: Mount disk successfully"
        fi
    else
        mkfs.$FS /dev/"$disk"1
        UpdateSummary "format with $FS filesystem"
        #Mount  disk to /$disk.
        mkdir /test
        mount /dev/"$disk"1 /test
        if [ ! "$?" -eq 0 ]
        then
            LogMsg "Mount Failed"
            UpdateSummary "FAIL: Mount Failed"
            SetTestStateAborted
            exit 1
        else
            LogMsg "Mount disk successfully"
            UpdateSummary "Passed: Mount disk successfully"
        fi
    fi
else
    LogMsg "The disk is RAW disk."
    UpdateSummary "The disk is RAW disk, no need filesystem"

fi

#Create fio test result path.
path="/root/log/${DISTRO}_kernel-$(uname -r)_${disktype}_${FS}_$(date +%Y%m%d%H%M%S)/"
mkdir -p $path

#Download fio python scripts from github.
cd /root
git clone https://github.com/SCHEN2015/virt-perf-scripts.git
cd /root/virt-perf-scripts/block

# Execute fio test
if [[ $FS = raw ]]; then
    ./RunFioTest.py --rounds 1 --backend $DiskType --driver $DiskType --fs $FS --filename /dev/$disk --log_path $path
    if [ $? -ne 0 ]; then
        LogMsg "Test Failed. RunFioTest.py --rounds 1 --backend $DiskType --driver $DiskType --fs $FS --filename /dev/$disk --log_path $path fio run for RAW disk failed.$path"
        UpdateSummary "Test failed. RunFioTest.py --rounds 1 --backend $DiskType --driver $DiskType --fs $FS --filename /dev/$disk --log_path $path fio run for RAW disk failed.$path"
        SetTestStateFailed
        exit 1
    else
       LogMsg " fio run for RAW disk successfully."
       UpdateSummary "fio run for RAW disk successfully."
    fi
else
    ./RunFioTest.py --rounds 1 --backend $DiskType --driver $DiskType --fs $FS --filename /test/test --log_path $path
    if [ $? -ne 0 ]; then
        LogMsg "Test Failed. fio run for FS disk failed.$path"
        UpdateSummary "Test failed.fio run for FS disk failed.$path"
        SetTestStateFailed
        exit 1
    else
       LogMsg " fio run for FS disk successfully."
       UpdateSummary "fio run for FS disk successfully."
    fi
fi
    
# Generate Fio test report
./GenerateTestReport.py --result_path $path
file=`ls $path`
mount -t nfs $nfs /mnt -o vers=3
cp -a $path /mnt
if [ $? -ne 0 ]; then
    LogMsg "Test report generate failed"
    UpdateSummary "Test report generate failed,$path and $file"
    SetTestStateFailed
    exit 1
else
    LogMsg "Test report generate successfully."
    UpdateSummary "Test report generate successfully.$path and $file"
    SetTestStateCompleted
    exit 0
fi