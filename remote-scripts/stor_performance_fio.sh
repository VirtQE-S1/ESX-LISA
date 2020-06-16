
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
## v2.0.0 - ldu - 04/02/2019 - add new function, could benchmark test result.
## v2.1.0 - ldu - 02/06/2020 - update the test log name and folder.
## v2.2.0 - ldu - 03/12/2020 - update test paramter for fio and change the benchmark result file to chmod 666.
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
#Check the guest version which use python2.x or python3, so install pip
#Below moudle yaml,click pandas numpy scipy is used by python script RunFioTest.py and GenerateTestReport.py.
if [[ $DISTRO != "redhat_8" ]]; then
	curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
	python get-pip.py
	pip install click pandas numpy scipy PyYAML
	UpdateSummary "For rhel6 and rhel7, python2.x use pip"
else
	#For RHEL8, manually create soft link python point to python3
	ln -s /usr/libexec/platform-python /usr/bin/python
	#install pip3.6 for RHEL8
	curl https://bootstrap.pypa.io/get-pip.py | python
	
	#install modules with pip command
	pip3.6 install click pandas numpy scipy PyYAML
	UpdateSummary "For rhel8, use pip3.6 install modules"
fi

#Install required package for fio copile and mount nfs disk.
yum install nfs-utils make -y

#install storage performance tool fio.
wget https://github.com/axboe/fio/archive/fio-3.14.tar.gz
tar -zxvf fio-3.14.tar.gz
cd fio-fio-3.14
make && make install
if [ ! "$?" -eq 0 ]; then
	LogMsg "ERROR:  install fio failed or make,nfs-utils install failed."
	UpdateSummary "ERROR:  install fio failed or make,nfs-utils install failed."
	SetTestStateAborted
	exit 1
else
	UpdateSummary "Fio install passed."
fi

#Check the fio version.
version=`fio --version`
if [ $version == "fio-3.14" ]; then
	LogMsg "fio version $version is correctly."
	UpdateSummary "fio version $version is correctly."
else
	LogMsg "fio version is not correctly."
	UpdateSummary "fio version is not correctly."
	SetTestStateAborted
	exit 1
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
if [[ $FS != raw ]]; then

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
	if [[ $DiskType == NVMe ]]; then
		disk="/dev/${disk}p1"
	else
		disk="/dev/${disk}1"
	fi
	mkfs.$FS $disk
	UpdateSummary "format with $FS filesystem"
	#Mount  disk to /$disk.
	mkdir /test
	mount $disk /test
	if [ ! "$?" -eq 0 ]; then
		LogMsg "Mount Failed"
		UpdateSummary "FAIL: Mount Failed"
		SetTestStateAborted
		exit 1
	else
		LogMsg "Mount disk successfully"
		UpdateSummary "Passed: Mount disk successfully"
	fi
else
	LogMsg "The disk is RAW disk."
	UpdateSummary "The disk is RAW disk, no need filesystem"

fi

# #mount one nfs disk to store the test result.
 mount -t nfs $nfs /mnt -o vers=3
if [ $? -ne 0 ]; then
	LogMsg "Test Failed. mount nfs failed."
	UpdateSummary "Test failed. mount nfs failed"
	SetTestStateFailed
	exit 1
else
	LogMsg "mount nfs successfully."
	UpdateSummary "mount nfs successfully."
fi


#set the compare kernel for fio test result, if the kernel set in xml will use it, if not ,we select the latest for this Distro.
if [ ! ${base} ]; then
	basepath=`ls -lt /mnt | grep ${DISTRO}_${yamlFile##*/}_.*_${DiskType}_${FS}_ | head -n 1 |awk '{print $9}'`
    UpdateSummary "set basepath $basepath from latest one in folder $base"
else
    basepath=`ls -lt /mnt | grep ${base}_${DiskType}_${FS}_ | head -n 1 |awk '{print $9}'`
	UpdateSummary "set basepath $basepath from xml kernel version $base"
fi

#Create fio test result path.
path="${DISTRO}_${yamlFile##*/}_kernel-$(uname -r)_${DiskType}_${FS}_$(date +%Y%m%d%H%M%S)"
mkdir -p /home/$path

#Download fio python scripts from github.
cd /root
git clone https://github.com/SCHEN2015/virt-perf-scripts.git
cd /root/virt-perf-scripts/block
[ -r ${yamlFile:="../virt_perf_scripts.yaml"} ] && rm -f virt_perf_scripts.yaml \
&& ln -s $yamlFile virt_perf_scripts.yaml && UpdateSummary "currently used $yamlFile yaml file"

#run setup scripts
./utils/setup.sh

# set filename dependecy raw or filesystem disk 
if [[ $FS == raw ]]; then
	filename="/dev/${disk}"
else
	filename="/test/test"
fi

# Execute fio test
/usr/bin/python ./RunFioTest.py --numjobs 1 --rw_list read,write,rw  --backend $backend --driver $DiskType --fs $FS --filename $filename --log_path /home/$path 
if [ $? -ne 0 ]; then
	LogMsg "Test Failed. fio run failed."
	UpdateSummary "Test failed.fio run failed. RunFioTest.py --dryrun --rounds 1 --runtime 1 --backend $backend --driver $DiskType --fs $FS --filename $filename --log_path /mnt/$path"
	SetTestStateFailed
	exit 1
else
	LogMsg " fio run for numjobs 16 successfully."
	UpdateSummary "fio run successfully."
fi

/usr/bin/python ./RunFioTest.py --numjobs 16 --rw_list randread,randwrite,randrw --backend $backend --driver $DiskType --fs $FS --filename $filename --log_path /home/$path
if [ $? -ne 0 ]; then
	LogMsg "Test Failed. fio run failed."
	UpdateSummary "Test failed.fio run failed. RunFioTest.py --dryrun --rounds 1 --runtime 1 --backend $backend --driver $DiskType --fs $FS --filename $filename --log_path /mnt/$path"
	SetTestStateFailed
	exit 1
else
	LogMsg " fio run for numjobs 1 successfully."
	UpdateSummary "fio run successfully."
fi

# Generate Fio test report
/usr/bin/python ./GenerateTestReport.py --result_path /home/$path
if [ $? -ne 0 ]; then
	LogMsg "Test report generate failed"
	UpdateSummary "Test report generate failed"
	SetTestStateFailed
	exit 1
else
	LogMsg "Test report generate successfully."
	UpdateSummary "Test report generate successfully."
fi

#copy the test result to nfs folder
cp -r /home/$path /mnt

#Generate benchmark Report in nfs folder
ls /mnt/benchmark || mkdir /mnt/benchmark
/usr/bin/python ./GenerateBenchmarkReport.py --base_csv /mnt/${basepath}/fio_report.csv --test_csv  /mnt/${path}/fio_report.csv --report_csv /mnt/benchmark/${basepath}_VS_${path}.csv
if [ $? -ne 0 ]; then
	LogMsg "Test result benchmark failed,"
	UpdateSummary "Test result benchmark failed, basepath is $basepath and path is $path"
	SetTestStateFailed
	exit 1
else
    chmod 666 /mnt/benchmark/*
	LogMsg "Test result benchmark successfully, basepath is $basepath and path is $path."
	UpdateSummary "Test result benchmark successfully, basepath is $basepath and path is $path."
	SetTestStateCompleted
	exit 0
fi
