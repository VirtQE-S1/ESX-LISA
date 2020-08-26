#!/bin/bash

###############################################################################
##
## Description:
## pbench-agent sigle host install
##
###############################################################################
##
## Revision:
## v1.0.0 - ldu - 08/03/2020 - Build the script
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
#Variables
GIT_DEST=/root/git/pbench

#Set the default python version to python3
PY_VER=$(python -V| sed "s/..\?..\?\$//")
if [[ ! $PY_VER == "Python 3" ]]
then
    alternatives --set python /usr/bin/python3
fi

#Allow ssh to localhost
HOSTNAME=$(hostname --long)
if ! grep "$HOSTNAME" ~/.ssh/config ; then
  yes "" | ssh-keygen -N ""
  cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
  echo -e "\nHost $HOSTNAME\n\tStrictHostKeyChecking no\n\tUserKnownHostsFile=/dev/null" >> ~/.ssh/config
fi  


#1. Ansible
#1.1. Install Ansible
if ! command -v ansible-playbook >/dev/null 2>&1 ; then
  if ! yum repolist all | grep epel; then 
    yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
  fi  
  yum -y --enablerepo=epel install ansible
fi

#Enable the CRB repo if the guest not have this repo
if ! grep CRB /etc/yum.repos.d/rhel.repo; then
  git config --global http.sslVerify false
  git clone https://code.engineering.redhat.com/gerrit/perf-dept /root/perf-dept
  echo -e "\n[servers]\n$HOSTNAME" >> /root/perf-dept/sysadmin/Inventory/repo-bootstrap.hosts
  inv=/root/perf-dept/Inventory/repo-bootstrap.hosts
  cd /root/perf-dept/sysadmin/Ansible
  if ! ansible-playbook  --user=root -i ${inv} repo-bootstrap.yml; then
    UpdateSummary "CRB repo enable has failed! rerun it with ansible-playbook  --user=root -i ${inv} repo-bootstrap.yml"
    LogMsg "CRB repo enable has failed!"
    SetTestStateFailed
    exit 1
  fi
fi 


#2.PBench
#2.1. Install Pbench
#clone the latest version
git clone https://github.com/distributed-system-analysis/pbench.git $GIT_DEST

#2.1.1. Create Inventory
mkdir -p  ~/.config/Inventories || exit
cp example.sh ~/.config/Inventories/myhosts.inv
sed -i "s/host1/$(hostname --long)/" ~/.config/Inventories/myhosts.inv


#2.1.2. Run playbook PBench agent install 
pushd $GIT_DEST/agent/ansible/ || exit
if ! ansible-playbook -v -i ~/.config/Inventories/myhosts.inv pbench-agent-install.yml; then
  UpdateSummary "ansible-playbook has failed!"
  UpdateSummary "Rerun it with ansible-playbook -v -i ~/.config/Inventories/myhosts.inv pbench-agent-install.yml"
  SetTestStateFailed
  exit 1
fi

#Reload $PATH
. /etc/profile.d/pbench-agent.sh

LogMsg  "PBench installation finished"
UpdateSummary "PBench installation finished"
UpdateSummary "Registering tools"

#Register default tool set
pbench-register-tool-set

pbench-register-tool --name=mpstat --group cpu_stat_group
pbench-register-tool --name=turbostat --group cpu_stat_group

pbench-register-tool --name=iostat --group fio_group
pbench-register-tool --name=vmstat --group fio_group

pbench-list-tools
if [ $? -ne 0 ]; then
	LogMsg "pbench list tools failed."
	UpdateSummary "pbench list tools failed"
	SetTestStateFailed
	exit 1
else
	LogMsg "pbench list tools successfully"
	UpdateSummary "pbench list tools successfully"
	SetTestStateCompleted
	exit 0
fi

