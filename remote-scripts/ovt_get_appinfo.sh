#!/bin/bash

###############################################################################
##
## Description:
##   This script verify open-vm-tools function collect running appinfo
##
###############################################################################
##
## Revision:
##  v1.0.0 - ldu - 04/10/2020 - Build scripts.
##
###############################################################################
#         <test>
#             <testName>ovt_get_appinfo</testName>
#             <testID>ESX-OVT-039</testID>
#             <testScript>ovt_get_appinfo.sh</testScript>
#             <files>remote-scripts/ovt_get_appinfo.sh</files>
#             <files>remote-scripts/utils.sh</files>
#             <testParams>
#                 <param>TC_COVERED=RHEL6-0000,RHEL-187173</param>
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

#Make sure the captures the app information in gust every 3 seconds
vmware-toolbox-cmd config set appinfo poll-interval 1

sleep 6
#Both below two command should get the running appinfo in guest
appNumber1=$(vmware-rpctool "info-get guestinfo.appInfo" | wc -l)
appNumber2=$(vmtoolsd --cmd "info-get guestinfo.appInfo" | wc -l)
if [ $appNumber1 -eq $appNumber2 ]; then
  LogMsg "vmware-rpctool:$appNumber1,vmtoolsd --cmd:$appNumber2"
  UpdateSummary "info: the running appinfo collect passed for both command."
else
  LogMsg "Info :vmware-rpctool:$appNumber1,vmtoolsd --cmd:$appNumber2"
  UpdateSummary "Test failed. The appinfo get failed in guest.vmware-rpctool:$appNumber1,vmtoolsd --cmd:$appNumber2"
  SetTestStateFailed
  exit 1
fi
#check the app number in guest
if [ "$appNumber1" -gt "100" ]; then
  LogMsg $appNumber
  UpdateSummary "Test Successfully. the running appinfo collect passed."
  SetTestStateCompleted
  exit 0
else
  LogMsg "Info : Test failed, $appNumber1"
  UpdateSummary "Test failed. The app number below than 100,is $appNumber1."
  SetTestStateFailed
  exit 1
fi


