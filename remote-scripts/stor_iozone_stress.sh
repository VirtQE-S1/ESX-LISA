#!/bin/bash

###############################################################################
##
## Description:
##  Test the guest with IO stress tool iozone.
##
###############################################################################
##
## Revision:
## v1.0.0 - ldu - 8/06/2018 - Build the script
##
###############################################################################
# <test>
#     <testName>stor_IO_stress</testName>
#     <testID>ESX-Stor-017</testID>
#     <!-- <setupScript>
#         <file>SetupScripts\change_memory.ps1</file>
#     </setupScript> -->
#     <testScript>stor_IO_stress.sh</testScript>
#     <files>remote-scripts/stor_iozone_stress.sh</files>
#     <files>remote-scripts/utils.sh</files>
#     <testParams>
#         <!-- <param>VMMemory=4GB</param> -->
#         <param>TC_COVERED=RHEL6-49148,TC_COVERED=RHEL7-111403</param>
#     </testParams>
#     <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
#     <timeout>60000</timeout>
#     <onError>Continue</onError>
#     <noReboot>False</noReboot>
# </test>

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
# Install required package for compil iozone.Download iozon form offical website
yum install make gcc -y
if [ ! "$?" -eq 0 ]; then
    LogMsg "ERROR: YUM install make, gcc failed"
    UpdateSummary "ERROR: YUM install make, gcc failed"
    SetTestStateAborted
    exit 1
fi

wget http://www.iozone.org/src/current/iozone3_482.tar
if [ ! "$?" -eq 0 ]; then
    LogMsg "ERROR: WGET failed as iozone address is unavailable"
    UpdateSummary "ERROR: WGET failed as iozone address is unavailable"
    SetTestStateAborted
    exit 1
fi

tar xvf iozone3_482.tar
cd /root/iozone3_482/src/current
make linux
if [ ! "$?" -eq 0 ]; then
    LogMsg "Test Failed.iozone install failed."
    UpdateSummary "Test failed.iozone install failed."
    SetTestStateAborted
    exit 1
else
    LogMsg " iozone install  successfully."
    UpdateSummary "iozone install  successfully."
fi

# Execute IOZONE
# ./iozone -a -g 4G -n 1024M -s 2048M -f /root/io_file -Rab /root/aiozon.wks
./iozone -g 1G
if [ ! "$?" -eq 0 ]; then
    LogMsg "Test Failed. iozone run failed."
    UpdateSummary "Test failed.iozone run failed."
    SetTestStateFailed
    exit 1
else
    LogMsg " iozone run successfully."
    UpdateSummary "iozone run successfully."
fi
# Check for call trace log

CheckCallTrace
if [ "$?" = "0" ]; then
    LogMsg "No call trace during testing"
    UpdateSummary "No call trace during testing"
    SetTestStateCompleted
    exit 0
else
    LogMsg "Call trace exists during testing"
    UpdateSummary "Call trace exists during testing"
    SetTestStateFailed
    exit 1
fi