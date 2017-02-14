#!/bin/bash
###############################################################################
##
## Description:
##   This script is storage utils file, which including functions of checking
##   fdisk, mkfs, mount file system.
##
###############################################################################
##
## Revision:
## v1.0 - xuli - 01/09/2017 - Draft script for case stor_utils.sh
## v1.1 - xuli - 01/09/2017 - update function comment to inner function
## v1.2 - xuli - 02/08/2017 - Add function DoParted, update DoMountFs to support
## mount type, e.g. nfs, add diskFormatType for TestMultiplFileSystems and
## TestSingleFileSystem
###############################################################################

CheckIntegrity()
{
    ############################################################################
    # Description:
    #   Perform data integrity test by checksum
    # Parameters:
    # $1 : storage device name /dev/sdb
    # Return: 0 : if CheckIntegrity successfully, otherwise, return 1
    ############################################################################

    targetDevice=$1
    testFile="/dev/shm/testsource"
    blockSize=$((32*1024*1024))
    _gb=$((1*1024*1024*1024))
    targetSize=$(blockdev --getsize64 $targetDevice)
    let "blocks=$targetSize / $blockSize"

    if [ "$targetSize" -gt "$_gb" ] ; then
        targetSize=$_gb
        let "blocks=$targetSize / $blockSize"
    fi

    blocks=$((blocks-1))
    mount $targetDevice /mnt/
    targetDevice="/mnt/1"
    LogMsg "Creating test data file $testfile with size $blockSize"
    echo "We will fill the device $targetDevice (of size $targetSize) with this data (in $blocks) and then will check if the data is not corrupted."
    echo "This will erase all data in $targetDevice"

    LogMsg "Creating test source file... ($BLOCKSIZE)"

    dd if=/dev/urandom of=$testFile bs=$blockSize count=1 status=noxfer 2> /dev/null

    LogMsg "Calculating source checksum..."
    checksum=$(sha1sum $testFile | cut -d " " -f 1)

    LogMsg "Checking ${blocks} blocks"
    for ((y=0 ; y<$blocks ; y++)) ; do
        #LogMsg "Writing block $y to device $targetDevice ..."
        dd if=$testFile of=$targetDevice bs=$blockSize count=1 seek=$y status=noxfer 2> /dev/null
        #echo -n "Checking block $y ..."
        testChecksum=$(dd if=$targetDevice bs=$blockSize count=1 skip=$y status=noxfer 2> /dev/null | sha1sum | cut -d " " -f 1)
        if [ "$checksum" != "$testChecksum" ] ; then
            LogMsg "Checksum mismatch on  block $y for ${targetDevice} "
            return 1
        fi
    done
    LogMsg "Data integrity test on ${blocks} blocks on drive $1 : success "
    umount /mnt/
    rm -f $testFile
    return 0
}

DoFdisk()
{
    ############################################################################
    # Description:
    #   Use fdisk /dev/sdb to create partition /dev/sdb1
    # Parameters:
    # $1 : storage device name /dev/sdb
    # Return: 0 : if fdisk successfully, otherwise, return 1
    ############################################################################
    local driveName=$1

    (echo d;echo;echo w)|fdisk $driveName
    (echo n;echo p;echo 1;echo;echo;echo w)|fdisk $driveName

    if [ "$?" = "0" ]; then
        LogMsg "Successfully fdisk drive."
        return 0
    else
        LogMsg "Error in fdisk drive, check disk is already mounted or not."
        return 1
    fi
}

DoParted()
{
    ############################################################################
    # Description:
    #   Use parted /dev/sdb to create partition /dev/sdb1
    # Parameters:
    # $1 : storage device name /dev/sdb
    # Return: 0 : if parted successfully, otherwise, return 1
    ############################################################################
    local driveName=$1
    parted -s -- $driveName mklabel gpt
    if [ "$?" = "0" ]; then
        LogMsg "Successfully parted mklabel gpt."
    else
        LogMsg "Error in parted mklabel gpt, check disk is already mounted or not."
        return 1
    fi

    parted -s -- $driveName mkpart primary 64s -64s
    if [ "$?" = "0" ]; then
        LogMsg "Successfully parted drive."
        return 0
    else
        LogMsg "Error in parted drive, check disk is already mounted or not."
        return 1
    fi
}

DoMakeFs()
{
    ############################################################################
    # Description:
    #   Make partition as target file system by mkfs
    # Parameters:
    # $1 : storage device name /dev/sdb
    # $2 : target file system type, e.g. ext3, ext4, xfs
    # Return: 0 : if mkfs successfully, otherwise, return 1
    ############################################################################
    local driveName=$1
    local fs=$2
    # for xfs, if overwrite original file system, need to use -f
    if [ "$fs" = "xfs" ]; then
       mkfs.$fs  ${driveName}1 -f |tr -d '\b\r'
    else
       mkfs.$fs  ${driveName}1 |tr -d '\b\r'
    fi

    if [ "$?" = "0" ]; then
        LogMsg "mkfs.$fs ${driveName}1 successful..."
        return 0
    else
        LogMsg "Error in creating file system.."
        return 1
    fi
  }

DoMountFs()
{
    ############################################################################
    # Description:
    #    mount /dev/sdb1 to mountpoint,e.g. /mnt
    # Parameters:
    # $1 : storage device name /dev/sdb
    # $2 : mountPoint, e.g. /mnt
    # $3 : mountType, e.g. nfs
    # Return: 0 : if mount successfully, otherwise, return 1
    ############################################################################
    local driveName=$1
    local mountPoint=$2
    local mountType=$3
    if [ ! ${mountType} ]; then
        mount ${driveName}1 $mountPoint
    else
        # mount -t nfs $NFS_Path /mnt
        mount -t ${mountType} ${driveName} $mountPoint
    fi
    if [ "$?" = "0" ]; then
        LogMsg "Drive mounted successfully..."
        return 0
    else
        LogMsg "Error in mount ${driveName} with $mountPoint .."
        return 1
    fi
}

DoDDFile()
{
    ############################################################################
    # Description:
    # create file under by dd,dd if=/dev/zero of=/mnt/Example/data bs=10M count=5
    # Parameters:
    # $1 : inFile
    # $2 : outFile
    # $3 : bs
    # $4 : count
    # Return: 0 : if dd file successfully, otherwise, return 1
    ############################################################################
    local inFile=$1
    local outFile=$2
    local bs=$3
    local count=$4

    dd if=$inFile of=$outFile bs=$bs count=$count
    if [ "$?" = "0" ] && [ -e $outFile ]; then
        LogMsg "Successful created dd file"
        return 0
    else
        LogMsg "Error in creat file by dd .."
        return 1
    fi
}

DoUMountFs()
{
    ############################################################################
    # Description:
    #    umount mountpoint,e.g. /mnt
    # Parameters:
    # $1 : mountPoint, e.g. /mnt
    # $2 : boolean value for clean fs, if set as "true", will remove file under
    #      mountPoint, otherwise, will not clean file.
    # Return: 0 : if umount successfully, otherwise, return 1
    ############################################################################
    local mountPoint=$1
    local cleanfs=$2
    umount $mountPoint
    if [ "$?" = "0" ]; then
        LogMsg "Drive umounted successfully..."
        if [ $cleanfs = "true" ];  then
            rm -f $mountPoint/*
        fi
        return 0
    else
        LogMsg "Error in umount $mountPoint..."
        return 1
    fi
}

CheckDiskSize()
{
    ############################################################################
    # Description:
    #    check disk size by fdisk and compare with expected file size
    # Parameters:
    # $1 : storage device name /dev/sdb
    # $2 : expected disk size, this size must be bytes, when add 1G disk,
    #      1073741824 shows in fdisk
    #      dynamicDiskSize=$(($OriginalSizeGB*1024*1024*1024))
    # Return: 0 : if disk size is same with expected size, otherwise, return 1
    ############################################################################
    local driveName=$1
    local dynamicDiskSize=$2

    fdisk -l $driveName > fdisk.dat 2> /dev/null
    elementCount=0
    for word in $(cat fdisk.dat)
    do
        elementCount=$((elementCount+1))
        if [ $elementCount == 5 ]; then
            if [ $word -ne $dynamicDiskSize ]; then
                LogMsg "Error: ${driveName}1 has an unknown disk size: $word"
                return 1
            else
                LogMsg "Disk size check Successfully..."
                return 0
            fi
        fi
    done
}

CheckDiskCount()
{
    ############################################################################
    # Description:
    #   Count the number of SCSI= and IDE= entries in constants, then compare
    # with /dev/sd* except /dev/sda.
    # Parameters:
    # $1 : storage device name /dev/sdb
    # $2 : expected disk size, this size must be bytes, when add 1G disk,
    #      1073741824 shows in fdisk
    #      dynamicDiskSize=$(($OriginalSizeGB*1024*1024*1024))
    # Return: 0 : if disk number in constant.sh is same with /dev/sd*,
    #        otherwise, return 1
    ############################################################################
    diskCount=0
    for entry in $(cat ./constants.sh)
    do
        # Convert to lower case
        lowStr="$(tr '[A-Z]' '[a-z]' <<<"$entry")"

        # does it start wtih ide or scsi
        if [[ $lowStr == *ide* ]];
        then
            diskCount=$((diskCount+1))
        fi
        if [[ $lowStr == *scsi* ]];
        then
            diskCount=$((diskCount+1))
        fi
    done
    #
    # Compute the number of sd* drives on the system,
    # Subtract the boot disk from the sdCount
    #
    sdCount=0
    for drive in /dev/sd*[^0-9]
    do
        sdCount=$((sdCount+1))
    done

    sdCount=$((sdCount-1))
    if [ $sdCount != $diskCount ]; then
        LogMsg "constants.sh disk count ($diskCount) does not match disk count
        from /dev/sd* ($sdCount)"
        return 1
    else
        LogMsg "constants.sh disk count ($diskCount) match disk count"
        return 0
    fi
}

TestSingleFileSystem()
{
    ############################################################################
    # Description:
    #   Fdisk disk, and create a file system, mount, then create file on it,
    # umount, CheckIntegrity
    # Parameters:
    # $1 : storage device name /dev/sdb
    # $2 : file system type (ext4,ext3)
    # $3 : disk format type, parted, or fdisk
    # Return: 0 : test file system successfully, otherwise, return 1
    ############################################################################
    local driveName=$1
    local fs=$2
    local diskFormatType=$3

    if [ "$diskFormatType" = "parted" ]; then
        DoParted $driveName
        if [ "$?" != "0" ]; then
            LogMsg "Error in parted $driveName"
            return 1
        fi
    else
        # fdisk /dev/sd*
        DoFdisk $driveName
        if [ "$?" != "0" ]; then
            LogMsg "Error in fdisk $driveName"
            return 1
        fi
    fi

    #make file system
    DoMakeFs $driveName $fs
    if [ "$?" != "0" ]; then
        LogMsg "Error in mkfs for $driveName as $fs"
        return 1
    fi

    local mountPoint="/mnt"
    #mount /dev/sdb1 to /mnt
    DoMountFs $driveName $mountPoint
    if [ "$?" != "0" ]; then
        LogMsg "Error in mount ${driveName}1 to $mountPoint"
        return 1
    fi

    # and create file under /mnt
    DoDDFile "/dev/zero" "/mnt/data" "10M" "50"
    #dd if=/dev/zero of=/mnt/Example/data bs=10M count=50
    if [ "$?" != "0" ]; then
        LogMsg "Error in dd file to $mountPoint"
        return 1
    fi

    #mount /dev/sdb1 to /mnt and clean up /mnt file
    DoUMountFs $mountPoint "true"
    if [ "$?" != "0" ]; then
        LogMsg "Error in umount $mountPoint"
        return 1
    fi
    # Perform Data integrity test
    CheckIntegrity ${driveName}1
    if [ "$?" != "0" ]; then
        LogMsg "Error in IntegrityCheck"
        return 1
    fi
    return 0
 }

 TestMultiplFileSystems()
 {
    ###########################################################################
    # Description:
    #   Call TestSingleFileSystem, do fdisk disk,create a file system, mount,
    # then create file on it, umount for multiple file systems,
    # Parameters:
    # $1 : file system array: e.g. (ext3, ext4, xfs)
    # $2 : disk format type, e.g. fdisk or parted
    # Return: 0 : test file systems successfully, otherwise, return 1
    ###########################################################################
    local fileSystems=($1)
    local diskFormatType=$2
    for driveName in /dev/sd*[^0-9];
    do
     # Skip /dev/sda
        if [ ${driveName} = "/dev/sda" ]; then
            continue
        fi
        for fs in "${fileSystems[@]}"; do
                command -v mkfs.$fs
                if [ "$?" != "0" ]; then
                    LogMsg "File-system tools for $fs not present. Skip filesystem $fs."
                else
                    TestSingleFileSystem $driveName $fs $diskFormatType
                    if [ "$?" != "0" ]; then
                        LogMsg "Disk file test failed."
                        return 1
                    fi
                fi
        done
    done
    return 0
}
