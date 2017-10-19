#!/bin/bash

###############################################################################
##
## Description:
##   This script checks open-vm-tools upgrade and downgrade.
##   The vmtoolsd status should be running after downgrade and upgrade.
##
###############################################################################
##
## Revision:
## v1.0 - ldu - 10/13/2017 - Draft script for case ESX-OVT-022.
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

#
# Start the testing
#

if [[ $DISTRO != "redhat_7" ]]; then
    SetTestStateSkipped
    exit
fi

#Make sure the os installed open-vm-tools and open-vm-tools-desktop.

yum erase -y open-vm-tools
yum install -y open-vm-tools-desktop
systemctl restart vmtoolsd
sleep 6
service=$(systemctl status vmtoolsd |grep running -c)

if [ "$service" = "1" ]; then
  LogMsg $service
  UpdateSummary "Test Successfully. service vmtoolsd is running."
else
  LogMsg "Info : The service vmtoolsd is not running'"
  UpdateSummary "Test Successfully. The service vmtoolsd is not running."
  SetTestStateAborted
  exit 1
fi

#Download the open-vm-tools older version

url=http://download.eng.bos.redhat.com/brewroot/packages/open-vm-tools/
#url=http://download.eng.bos.redhat.com/brewroot/packages/open-vm-tools/10.1.10/3.el7/x86_64/open-vm-tools-10.1.10-3.el7.x86_64.rpm
# get1=$url$version1
# get2=$url$version2
wget -P /root/ $url$version1

wget -P /root/ $url$version2
sleep 12
yum downgrade /root/*.rpm -y
sleep 30

#check the open-vm-tools version after downgrade.
version=$(rpm -qa open-vm-tools)
UpdateSummary "print the upgrade version $version"
if [ "$version" = "$newVersion" ]; then
        LogMsg "$version"
        UpdateSummary "Test Successfully. The open-vm-tools version is right."
else
        LogMsg "Info : The downgrade build info not right'"
        UpdateSummary "Test Failed,open-vm-tools downgrade build info not right ."
        SetTestStateFailed
        exit 1
fi

yum upgrade open-vm-tools-desktop open-vm-tools -y
sleep 30
version=$(rpm -qa open-vm-tools)
UpdateSummary "print the upgrade version $version"
if [ "$version" = "$defaultVersion" ]; then
        LogMsg "$version"
        UpdateSummary "Test Successfully. The open-vm-tools upgrade version is right."
        SetTestStateCompleted
        exit 0
else
        LogMsg "Info : The downgrade build info not right'"
        UpdateSummary "Test Failed,open-vm-tools upgrade build info not right ."
        SetTestStateFailed
        exit 1
fi
