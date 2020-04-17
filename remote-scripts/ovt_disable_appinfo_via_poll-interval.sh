#!/bin/bash

###############################################################################
##
## Description:
##   This script check disable appinfo plugin via set poll-interval to 0
##
###############################################################################
##
## Revision:
##  v1.0.0 - ldu - 04/10/2020 - Build scripts.
##
###############################################################################
#         <test>
#             <testName>ovt_disable_appinfo_via_poll-interval</testName>
#             <testID>ESX-OVT-040</testID>
#             <testScript>ovt_disable_appinfo_via_poll-interval.sh</testScript>
#             <files>remote-scripts/ovt_disable_appinfo_via_poll-interval.sh</files>
#             <files>remote-scripts/utils.sh</files>
#             <testParams>
#                 <param>TC_COVERED=RHEL6-0000,RHEL-187174</param>
#             </testParams>
#             <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
#             <timeout>600</timeout>
#             <onError>Continue</onError>
#             <noReboot>False</noReboot>
#         </test>
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

if [[ $DISTRO == "redhat_6" ]]; then
        SetTestStateSkipped
        exit
fi

#check the ovt package file list to confirm whether support appinfo plugin
rpm -ql open-vm-tools | grep "libappInfo"
if [[ $? == 0 ]]; then
  LogMsg $version_num
  UpdateSummary "Info: The OVT supoort appinfo plugin."
else
  LogMsg "Info : skip as OVT supoort appinfo plugin."
  UpdateSummary "skip as OVT supoort appinfo plugin."
  SetTestStateSkipped
  exit
fi


#Make sure the captures the app information in gust every 1 seconds
vmware-toolbox-cmd config set appinfo poll-interval 1

sleep 6
#Both below two command should get the running appinfo in guest
appNumber1=$(vmware-rpctool "info-get guestinfo.appInfo" | wc -l)
#check the app number in guest
if [ "$appNumber1" -gt "100" ]; then
  LogMsg $appNumber1
  UpdateSummary "Info: the running appinfo collect passed. the app number is $appNumber1."
else
  LogMsg "Info : Test failed, $appNumber1."
  UpdateSummary "Test failed. The app number below than 100,is $appNumber1."
  SetTestStateFailed
  exit 1
fi

#Disable the appinfo plugin
vmware-toolbox-cmd config set appinfo poll-interval 0

sleep 6
appNumber=$(vmware-rpctool "info-get guestinfo.appInfo" | wc -l)
#check the app number in guest
if [ "$appNumber" -eq "1" ]; then
  LogMsg $appNumber
  UpdateSummary "Test Successfully. The appinfo plugin has disabled."
  SetTestStateCompleted
  exit 0
else
  LogMsg "Info : Test failed, $appNumber."
  UpdateSummary "Test failed. The appinfo plugin disabled failed, the app number is $appNumber."
  SetTestStateFailed
  exit 1
fi

