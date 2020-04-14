#!/bin/bash

###############################################################################
##
## Description:
##   This script change appinfo plugin poll-interval default value, the default value is 30 miniutes
##
###############################################################################
##
## Revision:
##  v1.0.0 - ldu - 04/11/2020 - Build scripts.
##
###############################################################################
#         <test>
#             <testName>ovt_change_poll_interval_value</testName>
#             <testID>ESX-OVT-040</testID>
#             <testScript>ovt_change_poll_interval_value.sh</testScript>
#             <files>remote-scripts/ovt_change_poll_interval_value.sh</files>
#             <files>remote-scripts/utils.sh</files>
#             <testParams>
#                 <param>TC_COVERED=RHEL6-0000,RHEL-187176</param>
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
  UpdateSummary "Info: The OVT version great 10, version number is $version_num."
else
  LogMsg "Info : skip as OVT version old then 10, $version_num."
  UpdateSummary "skip as OVT version old then 10, version number is $version_num."
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
  UpdateSummary "Info: the first set poll-interval to 1, appinfo collect passed. the app number is $appNumber1."
else
  LogMsg "Info : Test failed, $appNumber1."
  UpdateSummary "Test failed. The first set poll-interval to 1, app number is $appNumber1."
  SetTestStateFailed
  exit 1
fi

#Make sure the captures the app information in gust every 1 seconds
vmware-toolbox-cmd config set appinfo poll-interval 0

sleep 6
#Both below two command should get the running appinfo in guest
appNumber2=$(vmware-rpctool "info-get guestinfo.appInfo" | wc -l)
#check the app number in guest
if [ "$appNumber2" -lt "2" ]; then
  LogMsg $appNumber2
  UpdateSummary "Test Successfully. Second set poll-interval to 0,the app number is $appNumber2."
else
  LogMsg "Info : Test failed, $appNumber2."
  UpdateSummary "Test failed. Second set poll-interval to 0, app number should be 0, the app number is $appNumber2."
  SetTestStateFailed
  exit 1
fi

vmware-toolbox-cmd config set appinfo poll-interval 20

sleep 15
appNumber3=$(vmware-rpctool "info-get guestinfo.appInfo" | wc -l)
#check the app number in guest
if [ "$appNumber3" -lt "2" ]; then
  LogMsg $appNumber3
  UpdateSummary "Test Successfully.Third time set poll-interval to 20, The appinfo plugin has no value,the app number is $appNumber3."
else
  LogMsg "Info : Test failed, $appNumber3."
  UpdateSummary "Test failed. Third time set poll-interval to 20, wait 15s,should no app, the app number is $appNumber3."
  SetTestStateFailed
  exit 1
fi



sleep 10
#Both below two command should get the running appinfo in guest
appNumber4=$(vmware-rpctool "info-get guestinfo.appInfo" | wc -l)
#check the app number in guest
if [ "$appNumber4" -gt "100" ]; then
  LogMsg $appNumber4
  UpdateSummary "Info: Third time set poll-interval to 20, wait 21s, the app number is $appNumber4."
  SetTestStateCompleted
  exit 0
else
  LogMsg "Info : Test failed, $appNumber4."
  UpdateSummary "Test failed. Third time set poll-interval to 20, wait 21s,app number is $appNumber4."
  SetTestStateFailed
  exit 1
fi

