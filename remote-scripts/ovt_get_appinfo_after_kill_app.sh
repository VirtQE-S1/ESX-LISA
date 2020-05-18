  v1.1.0 - ldu - 05/18/2020 - update the #!/bin/bash

###############################################################################
##
## Description:
##   This script check appinfo after kill some running app
##
###############################################################################
##
## Revision:
##  v1.0.0 - ldu - 04/15/2020 - Build scripts.
##  v1.1.0 - ldu - 05/18/2020 - update the check kill app methond.
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
service=$(vmware-rpctool "info-get guestinfo.appInfo" | grep crond)
#check the app status in guest
if [ "$service" = "" ]; then
  LogMsg "Info : Test failed, can not found service crond in guest $service ."
  UpdateSummary "Test failed. can not found service crond in guest."
  SetTestStateFailed
  exit 1
else
  LogMsg $service
  UpdateSummary "Info: the service $service is running status."
fi

#Kill running app crond
pkill crond

sleep 1
service=$(vmware-rpctool "info-get guestinfo.appInfo" | grep crond)
#check the app status in guest if exist
if [ "$service" = "" ]; then
  LogMsg app is $service.
  UpdateSummary "Test Successfully. The appinfo could not detect by appinfo plugin after kill it."
  SetTestStateCompleted
  exit 0
else
  LogMsg "Info : Test failed, $service."
  UpdateSummary "Test failed. The appinfo plugin captures crond after kill it, service is $service."
  SetTestStateFailed
  exit 1
fi

