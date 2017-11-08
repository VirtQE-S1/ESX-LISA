#!/bin/bash

###############################################################################
##
## Description:
##   This script checks open-vm-tools-debuginfo upgrade and downgrade.
##

##<test>
#     <testName>ovt_upgrade_downgrade_debuginfo</testName>
#     <testID>ESX-OVT-022</testID>
#     <testScript>ovt_upgrade_downgrade_debuginfo.sh</testScript>
#     <files>remote-scripts/ovt_upgrade_downgrade_debuginfo.sh</files>
#     <files>remote-scripts/utils.sh</files>
#     <testParams>
#         <param>url1=10.1.5/3.el7/x86_64/</param>
#         <param>url2=10.1.10/3.el7/x86_64/</param>
#         <param>version1=open-vm-tools-debuginfo-10.1.5-3.el7.x86_64.rpm</param>
#         <param>version2=open-vm-tools-debuginfo-10.1.10-3.el7.x86_64.rpm</param>
#         <param>defaultVersion=open-vm-tools-debuginfo-10.1.5-3.el7.x86_64</param>
#         <param>newVersion=open-vm-tools-debuginfo-10.1.10-3.el7.x86_64</param>
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
## v1.0 - ldu - 10/19/2017 - Draft script for case ESX-OVT-023.
## RHEL7-71602
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

#Make sure the os installed open-vm-tools and service vmtoolsd is running.

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

#Download the open-vm-tools-debuginfo current and older version

url=http://download.eng.bos.redhat.com/brewroot/packages/open-vm-tools/

wget -P /root/ $url$url1$version1
wget -P /root/ $url$url2$version2

yum install -y /root/$version1

#yum downgrade $version2 -y
yum upgrade /root/$version2 -y

#check the open-vm-tools version after upgrade.
version=$(rpm -qa open-vm-tools-debuginfo)
UpdateSummary "print the upgrade version $version"
if [ "$version" = "$newVersion" ]; then
        LogMsg "$version"
        UpdateSummary "Test Successfully. The open-vm-tools-debuginfo upgrade build version is right."
else
        LogMsg "Info : The upgrade build info not right'"
        UpdateSummary "Test Failed,open-vm-tools-debuginfo upgrade build info not right ."
        SetTestStateFailed
        exit 1
fi
#yum upgrade open-vm-tools-debuginfo -y
yum downgrade /root/$version1 -y
#check the open-vm-tools version after downgrade.
version=$(rpm -qa open-vm-tools-debuginfo)
UpdateSummary "print the downgrade version $version"
if [ "$version" = "$defaultVersion" ]; then
        LogMsg "$version"
        UpdateSummary "Test Successfully. The open-vm-tools-debuginfo dwongrade version is right."
        SetTestStateCompleted
        exit 0
else
        LogMsg "Info : The downgrade build info not right'"
        UpdateSummary "Test Failed,open-vm-tools-debuginfo downgrade build info not right ."
        SetTestStateFailed
        exit 1
fi
