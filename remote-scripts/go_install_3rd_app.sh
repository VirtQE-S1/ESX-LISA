#!/bin/bash

###############################################################################
##
## Description:
##  Test the guest works well after after install 3rd app.
##
###############################################################################
##
## Revision:
## v1.0.0 - ldu - 05/21/2020 - Build the script
##
################################################################################
#     <test>
#             <testName>go_install_3rd_app</testName>
#             <testID>ESX-GO-32</testID>
#             <testScript>go_install_3rd_app.sh</testScript>
#             <files>remote-scripts/go_install_3rd_app.sh</files>
#             <files>remote-scripts/utils.sh</files>
#             <testParams>
#                 <param>TC_COVERED=RHEL-174551</param>
#             </testParams>
#             <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
#             <timeout>600</timeout>
#             <onError>Continue</onError>
#             <noReboot>False</noReboot>
#     </test>



dos2unix utils.sh

# Source utils.sh
. utils.sh || {
	echo "Error: unable to source utils.sh!"
	exit 1
}

# Source constants.sh to get all paramters from XML <testParams>
. constants.sh || {
	echo "Error: unable to source constants.sh!"
	exit 1
}

# Source constants file and initialize most common variables
UtilsInit

###############################################################################
##
## Main
##
###############################################################################
#Check the new added Test disk exist.
yum install -y pcp pcp-pmda-perfevent
rpm -qa pcp pcp-pmda-perfevent
version=$(rpm -qa pcp pcp-pmda-perfevent)
LogMsg "$version"
if [ -n "$version" ]; then
        LogMsg "Intall the 3rd app pcp pcp-pmda-perfevent Failed."
        UpdateSummary "Failed. Intall the 3rd app pcp pcp-pmda-perfevent Failed."
        SetTestStateAborted
        exit 1
else
        LogMsg "Intall the 3rd app Passed."
fi

#Set PMCD communicate with the perfevent daemon via a pipe
cd /var/lib/pcp/pmdas/perfevent
./Install <<EOF
        pipe
EOF

#check the 3rd app service status.
service=$(systemctl status pmcd |grep running -c)
if [ "$service" = "1" ]; then
  LogMsg $service
  UpdateSummary "Test Successfully. service pmcd is running."
else
  LogMsg "Info : The service pmcd is not running'"
  UpdateSummary "Test Successfully. The service pmcd is not running."
  SetTestStateFailed
  exit 1
fi

log=$(dmesg |grep CallTrace)
if [ $service -ne $null ]; then
	LogMsg " Failed: After install 3rd app pcp, there is CallTrace in dmesg "
	UpdateSummary "Failed: After install 3rd app pcp, there is CallTrace in dmesg"
	SetTestStateFailed
	exit 1
else
	LogMsg "Passed: After install 3rd app pcp, no CallTrace and panic."
	UpdateSummary "Passed: After install 3rd app pcp, no CallTrace and panic."
	SetTestStateCompleted
	exit 0
fi

