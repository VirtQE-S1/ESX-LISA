#!/bin/bash


########################################################################################
## Description:
##	Change appinfo plugin poll-interval default value(30 miniutes).
## Revision:
##	v1.0.0 - ldu - 04/11/2020 - Build scripts.
########################################################################################


########################################################################################
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
########################################################################################


dos2unix utils.sh


# Source utils.sh
. utils.sh || {
    echo "Error: unable to source utils.sh!"
    exit 1
}


# Source constants file and initialize most common variables
UtilsInit


# Start the testing
if [[ $DISTRO == "redhat_6" ]]; then
        SetTestStateSkipped
        exit
fi


# Check the ovt package file list to confirm whether support appinfo plugin.
rpm -ql open-vm-tools | grep "libappInfo"
if [[ $? == 0 ]]; then
  LogMsg "INFO: The OVT supoorts appinfo plugin."
  UpdateSummary "INFO: The OVT supoorts appinfo plugin."
else
  LogMsg "INFO: Skip as OVT didn't supoort appinfo plugin."
  UpdateSummary "INFO: Skip as OVT didn't supoort appinfo plugin."
  SetTestStateSkipped
  exit
fi


# Make sure to capture the app information in gust every 1 seconds.
vmware-toolbox-cmd config set appinfo poll-interval 1
sleep 6
# Both below two commands should get the running appinfo in guest.
appNumber1=$(vmware-rpctool "info-get guestinfo.appInfo" | wc -l)
# Check the app numbers in guest.
if [ "$appNumber1" -gt "100" ]; then
  LogMsg "INFO: The first time to set poll-interval to 1, appinfo collect passed. the app number is ${appNumber1}."
  UpdateSummary "INFO: The first time to set poll-interval to 1, appinfo collect passed. the app number is ${appNumber1}."
else
  LogMsg "FAILED: Failed to set poll-interval to 1 in the first time, app number is ${appNumber1}."
  UpdateSummary "FAILED: Failed to set poll-interval to 1 in the first time, app number is ${appNumber1}."
  SetTestStateFailed
  exit 1
fi


# Make sure the captures the app information in gust every 1 seconds????
# Disable this feature.
vmware-toolbox-cmd config set appinfo poll-interval 0
sleep 6
# Both below two command should get the running appinfo in guest.
appNumber2=$(vmware-rpctool "info-get guestinfo.appInfo" | wc -l)
# Check the app number in guest.
if [ "$appNumber2" -lt "2" ]; then
  LogMsg "INFO: The second time to set poll-interval to 0, appinfo collect passed. the app number is ${appNumber2}."
  UpdateSummary "INFO: The second time to set poll-interval to 0, appinfo collect passed. the app number is ${appNumber2}."
else
  LogMsg "FAILED: Failed to set poll-interval to 0 in the second time, app number is ${appNumber2}."
  UpdateSummary "FAILED: Failed to set poll-interval to 0 in the second time, app number is ${appNumber2}."
  SetTestStateFailed
  exit 1
fi


# Make sure to capture the app information in gust every 20 seconds.
vmware-toolbox-cmd config set appinfo poll-interval 20
sleep 15
appNumber3=$(vmware-rpctool "info-get guestinfo.appInfo" | wc -l)
# Check the app number in guest.
if [ "$appNumber3" -lt "2" ]; then
  LogMsg "INFO: The third time to set poll-interval to 20, appinfo collect passed. the app number is ${appNumber3}."
  UpdateSummary "INFO: The third time to set poll-interval to 20, appinfo collect passed. the app number is ${appNumber3}."
else
  LogMsg "FAILED: Failed to set poll-interval to 20 in the second time, app number is ${appNumber3}."
  UpdateSummary "FAILED: Failed to set poll-interval to 20 in the second time, app number is ${appNumber3}."
  SetTestStateFailed
  exit 1
fi


sleep 10


# Both below two commands should get the running appinfo in guest.
appNumber4=$(vmware-rpctool "info-get guestinfo.appInfo" | wc -l)
# Check the app number in guest
if [ "$appNumber4" -gt "100" ]; then
  LogMsg $appNumber4
  UpdateSummary "Info: Third time set poll-interval to 20, wait 25s, the app number is $appNumber4."
  SetTestStateCompleted
  exit 0
else
  LogMsg "Info : Test failed, $appNumber4."
  UpdateSummary "Test failed. Third time set poll-interval to 20, wait 25s,app number is $appNumber4."
  SetTestStateFailed
  exit 1
fi

