#!/bin/bash

###############################################################################
##
## Description:
##   This script checks open-vm-tools upgrade and downgrade.
##   The vmtoolsd status should be running after downgrade and upgrade.
##
# <test>
#     <testName>ovt_upgrade_downgrade_vmtools</testName>
#     <testID>ESX-OVT-022</testID>
#     <testScript>ovt_upgrade_downgrade_vmtools.sh</testScript>
#     <files>remote-scripts/ovt_upgrade_downgrade_vmtools.sh</files>
#     <files>remote-scripts/utils.sh</files>
#     <testParams>
#         <param>defaultVersion=open-vm-tools-10.1.10-3.el7.x86_64</param>
#         <param>version1=10.1.5/3.el7/x86_64/open-vm-tools-10.1.5-3.el7.x86_64.rpm</param>
#         <param>version2=10.1.5/3.el7/x86_64/open-vm-tools-desktop-10.1.5-3.el7.x86_64.rpm</param>
#         <param>ChangeVersion=open-vm-tools-10.1.5-3.el7.x86_64</param>
#         <param>TC_COVERED=RHEL6-34901,RHEL7-50884</param>
#     </testParams>
#     <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
#     <timeout>300</timeout>
#     <onError>Continue</onError>
#     <noReboot>False</noReboot>
# </test>
##
###############################################################################
##
## Revision:
## v1.0 - ldu - 10/13/2017 - Draft script for case ESX-OVT-022.
## RHEL7-50890
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

if [[ $DISTRO = "redhat_6" ]]; then
    SetTestStateSkipped
    exit
fi

#Make sure the os installed open-vm-tools and open-vm-tools-desktop.


yum install -y open-vm-tools-desktop
systemctl restart vmtoolsd

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

wget -P /root/ $url$version1

wget -P /root/ $url$version2

#Downgrade the open-vm-tools to a older version.
yum downgrade /root/*.rpm -y

#check the open-vm-tools version after upgrade.
version=$(rpm -qa open-vm-tools)
UpdateSummary "print the downgrade version $version"
if [ "$version" = "$ChangeVersion" ]; then
        LogMsg "$version"
        UpdateSummary "Test Successfully. The open-vm-tools version is right."
else
        LogMsg "Info : The downgrade build info not right'"
        UpdateSummary "Test Failed,open-vm-tools downgrade build info not right ."
        SetTestStateFailed
        exit 1
fi
#Upgrage the open-vm-tools to defaultVersion.
yum upgrade open-vm-tools-desktop open-vm-tools -y
#check the open-vm-tools version after downgrade.
version=$(rpm -qa open-vm-tools)
UpdateSummary "print the upgrade version $version"
if [ "$version" = "$defaultVersion" ]; then
        LogMsg "$version"
        UpdateSummary "Test Successfully. The open-vm-tools upgrade version is right."
        SetTestStateCompleted
        exit 0
else
        LogMsg "Info : The upgrade build info not right'"
        UpdateSummary "Test Failed,open-vm-tools upgrade build info not right ."
        SetTestStateFailed
        exit 1
fi
