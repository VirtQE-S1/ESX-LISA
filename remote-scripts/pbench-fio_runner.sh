#!/bin/bash

###############################################################################
##
## Description:
## pbench-agent install and run pbench-fio
##
###############################################################################
##
## Revision:
## v1.0.0 - ldu - 12/30/2020 - Build the script
##
###############################################################################
dos2unix utils.sh

# Source utils.sh
. utils.sh || {
	UpdateSummary "Error: unable to source utils.sh!"
	exit 1
}

# Source constants.sh to get all paramters from XML <testParams>
. constants.sh || {
	UpdateSummary "Error: unable to source constants.sh!"
	exit 1
}

# Source constants file and initialize most common variables
UtilsInit

###############################################################################
##
## Main
##
###############################################################################
#perf-agent repo clone
cd /root/
git clone https://github.com/virt-s1/perf-agent.git
pushd /root/perf-agent/pbench_setup/ || exit
UpdateSummary "perf-agent repo git clone done."

#Set the default python version to python3
PY_VER=$(python -V| sed "s/..\?..\?\$//")
if [[ ! $PY_VER == "Python 3" ]]
then
    alternatives --set python /usr/bin/python3
else
    UpdateSummary "python version is python3!"
fi

#Allow ssh to localhost
HOSTNAME=$(hostname --long)
if ! grep "$HOSTNAME" ~/.ssh/config ; then
  yes "" | ssh-keygen -N ""
  cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
  echo -e "\nHost $HOSTNAME\n\tStrictHostKeyChecking no\n\tUserKnownHostsFile=/dev/null" >> ~/.ssh/config
fi  
UpdateSummary "the sshkey for local host done."

#change the inventory file to add local host
echo $HOSTNAME >> inventory
UpdateSummary "The inventory update for localhost done."

#Install Ansible
if ! command -v ansible-playbook >/dev/null 2>&1 ; then
  if ! yum repolist all | grep epel; then 
    yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
  fi  
  yum -y --enablerepo=epel install ansible --nogpgcheck
fi
UpdateSummary "ansible install done."

#install the pbench-agent and config the env 
./setup.sh
if [ $? -ne 0 ]; then
	LogMsg "Test Failed.Setup script failed."
	UpdateSummary "Test failed.Setup script failed"
	SetTestStateFailed
	exit 1
else
	LogMsg "Setup script successfully."
	UpdateSummary "Setup script successfully."
fi
#Reload $PATH
. /etc/profile.d/pbench-agent.sh

#check the pbench-agent
rpm -qa pbench-agent
if [ $? -ne 0 ]; then
	LogMsg "Test Failed.PBench installation failed."
	UpdateSummary "Test failed. PBench installation failed"
	SetTestStateFailed
	exit 1
else
	LogMsg "PBench installation successfully."
	UpdateSummary "PBench installation successfully."
fi

#Install fio
yum install fio -y
if [ $? -ne 0 ]; then
	LogMsg "Test Failed.fio installation failed."
	UpdateSummary "Test failed. fio installation failed"
	SetTestStateFailed
	exit 1
else
	LogMsg "fio installation successfully."
	UpdateSummary "fio installation successfully."
fi
ln -s /usr/bin/fio /usr/local/bin/fio
UpdateSummary "The fio install done."

#change dir to pbench runner
pushd /root/perf-agent/pbench_runner/ || exit
chmod 777 *
#set the test run id
testrun_id=$(./make_testrunid.py --type fio --platform ESXi \
--compose $vmName --customized-labels $lable) || exit 1

#set the log path
yum install nfs-utils make -y
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
log_path="/mnt/$testrun_id"
mkdir -p $log_path || exit 1
UpdateSummary "mkdir for log path $log_path "

#Write down metadata entries to a json file
./write_metadata.py --file $log_path/testrun_metadata.json \
    --keypair testrun.platform=ESXi \
    --keypair testrun.id=$testrun_id \
    --keypair testrun.date=$(date +"%Y-%m-%d" ) \
    --keypair testrun.type=fio \
    --keypair testrun.comments= \
    --keypair os.compose=$vmName \
    --keypair os.branch="$(cat /etc/redhat-release)" \
    --keypair os.kernel=$(uname -r) \
    --keypair hardware.disk.backend=$DiskDataStore \
    --keypair hardware.disk.driver=$DiskType \
    --keypair hardware.disk.format=$FS \
    --keypair hardware.disk.Capacity="$CapacityGB"G \
    --keypair hypervisor.cpu=32 \
    --keypair hypervisor.cpu_model=$cpu \
    --keypair hypervisor.version="$(vmware-toolbox-cmd stat raw text session |grep version |sed 's/^version = \(.*\)/\1/')" \
    --keypair tool.fio.version=$(rpm -qa fio) \
    --keypair guest.cpu=$VCPU \
    --keypair guest.memory=$VMMemory \
    --keypair guest.flavor=$flavor
UpdateSummary "Test run metadata file created "

# Run pbench-fio for sequential access
UpdateSummary "start run pbench-fio sequential access "
./pbench-fio.wrapper --config=${testrun_id#*_} \
    --job-file=./fio-default.job --samples=5 \
    --targets=/dev/$disk --job-mode=concurrent \
    --pre-iteration-script=./drop-cache.sh \
    --test-types=read,write,rw \
    --block-sizes=4,16,128,1024 \
    --iodepth=1,8,16 --numjobs=1
if [ $? -ne 0 ]; then
	LogMsg "pbench runner sequential failed."
	UpdateSummary "pbench runner sequential failed"
	SetTestStateFailed
	exit 1
else
	LogMsg "pbench runner sequential successfully"
	UpdateSummary "pbench runner sequential successfully"
fi
# Run pbench-fio for random access
UpdateSummary "start run pbench-fio random access "
./pbench-fio.wrapper --config=${testrun_id#*_} \
    --job-file=./fio-default.job  --samples=5 \
    --targets=/dev/$disk --job-mode=concurrent \
    --pre-iteration-script=./drop-cache.sh \
    --test-types=randread,randwrite,randrw \
    --block-sizes=4,16,128,1024 \
    --iodepth=1,8,16 --numjobs=16
if [ $? -ne 0 ]; then
	LogMsg "pbench runner random failed."
	UpdateSummary "pbench runner random failed"
	SetTestStateFailed
	exit 1
else
	LogMsg "pbench runner random successfully"
	UpdateSummary "pbench runner random successfully"
fi
# Collect test results to the log path
mv /var/lib/pbench-agent/fio_* $log_path
if [ $? -ne 0 ]; then
	LogMsg "pbench result move failed."
	UpdateSummary "pbench result move failed"
	SetTestStateFailed
	exit 1
else
	LogMsg "pbench result move successfully"
	UpdateSummary "pbench result move successfully"
	SetTestStateCompleted
	exit 0
fi