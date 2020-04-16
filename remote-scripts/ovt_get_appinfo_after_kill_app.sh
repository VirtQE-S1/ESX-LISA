#!/bin/bash

###############################################################################
##
## Description:
##   This script check appinfo after kill some running app
##
###############################################################################
##
## Revision:
##  v1.0.0 - ldu - 04/15/2020 - Build scripts.
##
###############################################################################
#         <test>
#             <testName>ovt_get_appinfo_after_kill_app</testName>
#             <testID>ESX-OVT-045</testID>
#             <testScript>ovt_get_appinfo_after_kill_app.sh</testScript>
#             <files>remote-scripts/ovt_get_appinfo_after_kill_app.sh</files>
#             <files>remote-scripts/utils.sh</files>
#             <testParams>
#                 <param>TC_COVERED=RHEL6-0000,RHEL-187199</param>
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

#check the ovt version, if version old then 11, skip it.
version=$(rpm -qa open-vm-tools)
version_num=${version:14:2}
if [ "$version_num" -gt "10" ]; then
  LogMsg $version_num
  UpdateSummary "Info: The OVT version great 10, version number is $version."
else
  LogMsg "Info : skip as OVT version old then 10, current version is $version."
  UpdateSummary "skip as OVT version old then 10, version number is $version."
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

#Kill some running app
pkill chronyd

sleep 6
appNumber=$(vmware-rpctool "info-get guestinfo.appInfo" | wc -l)
#check the app number in guest
if [ "$appNumber" -lt $appNumber1 ]; then
  LogMsg app number is $appNumber.
  UpdateSummary "Test Successfully. The appinfo plugin could get appinfo correctly after kill some app,the app number is $appNumber."
  SetTestStateCompleted
  exit 0
else
  LogMsg "Info : Test failed, $appNumber."
  UpdateSummary "Test failed. The appinfo plugin captures appinfo failed after kill some app, the app number is $appNumber."
  SetTestStateFailed
  exit 1
fi

