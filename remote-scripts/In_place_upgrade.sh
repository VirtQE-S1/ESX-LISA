#!/bin/bash

###############################################################################
##
## Description:
## This script test RHEL in place upgrade from rhel 7 to rhel8
##
###############################################################################
##
## Revision:
## v1.0 - ldu - 19/08/2020 - Build scripts.
##
###############################################################################

dos2unix utils.sh

# Source utils.sh
. utils.sh || {
    echo "Error: unable to source utils.sh!"
    exit 1
}

# Source constants file and initialize most common variables
UtilsInit

###############################################################################
# Start the testing
###############################################################################
#Check the guest version, skip RHEL 6, as this script not suitable RHEL 6
if [[ $DISTRO == "redhat_6" ]]; then
    SetTestStateSkipped
    exit
fi

#subscription the guest with a test account, such as  --username leapp-devel-test --password 6VafUsaywiudCed
subscription-manager register --username ldu_test --password redhat --serverurl "subscription.rhsm.stage.redhat.com" --auto-attach

#Enable RHEL7 repo
subscription-manager repos --enable rhel-7-server-rpms
subscription-manager repos --enable rhel-7-server-extras-rpms

#update the guest to latest version
# yum update -y
# if [ ! "$?" -eq 0 ]
# then
#     LogMsg "ERROR: yum update guest failed"
#     UpdateSummary "ERROR: yum update guest  failed"
#     SetTestStateAborted
#     exit 1
# else
#     LogMsg "INFO: yum update guest successfully"
#     UpdateSummary "INFO: yum update guest successfully"
# fi

#Install os-tests for upgrade regression test
pip3 install -U os-tests

#Download the leapp repo
curl -k https://copr.devel.redhat.com/coprs/oam-group/leapp/repo/rhel-7/oam-group-leapp-rhel-7.repo -o /etc/yum.repos.d/oam-group-leapp-rhel-7.repo
sed -i 's/$basearch/x86_64/g' /etc/yum.repos.d/oam-group-leapp-rhel-7.repo

#Install the leapp tool for upgrade guest
yum install -y leapp "leapp-repository*master*"
if [ ! "$?" -eq 0 ]
then
    LogMsg "ERROR: yum install leapp failed"
    UpdateSummary "ERROR: yum install leapp failed"
    SetTestStateAborted
    exit 1
else
    LogMsg "INFO:yum install leapp successfully"
    UpdateSummary "INFO: yum install leapp successfully"
fi

#Download the config file
curl -k --create-dirs -o /etc/leapp/files/pes-events.json https://gitlab.cee.redhat.com/leapp/oamg-rhel7-vagrant/raw/master/roles/init/files/leapp-data/pes-events.json
curl -k --create-dirs -o /etc/leapp/files/repomap.csv https://gitlab.cee.redhat.com/leapp/oamg-rhel7-vagrant/raw/master/roles/init/files/leapp-data/repomap.csv

#permit the root login
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config

leapp answer --section remove_pam_pkcs11_module_check.confirm=True --add

#upgrade the guest.
#if upgrade not released RHEL version,please use command 
LEAPP_DEVEL_SKIP_CHECK_OS_RELEASE=1 LEAPP_UNSUPPORTED=1 leapp upgrade --debug
# LEAPP_UNSUPPORTED=1 leapp upgrade --debug
if [ ! "$?" -eq 0 ]
then
    LogMsg "ERROR: The leapp upgrade command failed"
    UpdateSummary "ERROR: The leapp upgrade command failed"
    SetTestStateFailed
    exit 1
else
    LogMsg "INFO:The leapp upgrade command successfully"
    UpdateSummary "INFO: The leapp upgrade command successfully"
    reboot
    sleep 300
    SetTestStateCompleted
    exit 0
fi