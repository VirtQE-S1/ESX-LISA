#!/bin/bash


###############################################################################
##
## Description:
##  Checks open-vm-tools upgrade and downgrade.
##  The vmtoolsd status should be running after downgrade and upgrade.
##
## Revision:
##  v1.0.0 - ldu - 10/13/2017 - Draft script for case ESX-OVT-022
##  v1.0.1 - boyang - 05/15/2018 - Supports rhel8
##
###############################################################################


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


#######################################################################
#
# Main script body
#
#######################################################################


# If current Guest is supported in the XML <testParams>
# "cat constant.sh | grep $DISTRO" will get the standard OVT version of $DISTRO
distro_standard_version=`cat constants.sh | grep ${DISTRO}_standard | awk -F "=" '{print $2}'`
LogMsg "DEBUG: distro_standard_version: $distro_standard_version"
UpdateSummary "DEBUG: distro_standard_version: $distro_standard_version"
if [ -z $distro_standard_version ]; then
    LogMsg "ERROR: Current Guest DISTRO isn't supported, UPDATE XML for this DISTRO"
    UpdateSummary "ERROR: Current Guest DISTRO isn't supported, UPDATE XML for this DISTRO"
    SetTestStateAborted
    exit 1
fi


# Known: Red Hat Enterprise Linux Server Release 6.X / (5.X) doesn't have OVT, it is VT
if [ $distro_standard_version == "NOOVT" ]; then
    LogMsg "WARNING: Current Guest $DISTRO doesn't have OVT, will skip it"
    UpdateSummary "WARNING: Current Guest $DISTRO doesn't have OVT, will skip it"
    SetTestStateSkipped
    exit 0
fi


#
# Install open-vm-tools-desktop for current Guest WITHOUT relationship of DISTR
#
yum install -y open-vm-tools-desktop
systemctl restart vmtoolsd
service_status=$(systemctl status vmtoolsd |grep running -c)
if [ "$service_status" = "1" ]; then
    LogMsg "INFO: Service vmtoolsd is running"
    UpdateSummary "INFO: Service vmtoolsd is running"
else
    LogMsg "ERROR: The service vmtoolsd is not running"
    UpdateSummary "ERROR: The service vmtoolsd is not running"
    SetTestStateAborted
    exit 1
fi


# Get OVT lower info
url_prefix="http://download.eng.bos.redhat.com/brewroot/packages/open-vm-tools/"
lower_version=`cat constants.sh | grep ${DISTRO}_lower_version | awk -F "=" '{print $2}'`
LogMsg "DEBUG: lower_version: $lower_version"
UpdateSummary "DEBUG: lower_version: $lower_version"
lower_rpm=`cat constants.sh | grep ${DISTRO}_lower_rpm | awk -F "=" '{print $2}'`
LogMsg "DEBUG: lower_rpm: $lower_rpm"
UpdateSummary "DEBUG: lower_rpm: $lower_rpm"
lower_dsk_rpm=`cat constants.sh | grep ${DISTRO}_lower_dsk_rpm | awk -F "=" '{print $2}'`
LogMsg "DEBUG: lower_dsk_rpm: $lower_dsk_rpm"
UpdateSummary "DEBUG: lower_dsk_rpm: $lower_dsk_rpm"


# Download lower version OVT
wget -P /root/ $url_prefix$lower_rpm
# Download lower version desktop OVT
wget -P /root/ $url_prefix$lower_dsk_rpm
# Downgrade the open-vm-tools to a older version
yum downgrade /root/*.rpm -y
# Check the open-vm-tools version after downgrade
ovt_ver_after_downgrade=$(rpm -qa open-vm-tools)
LogMsg "DEBUG: ovt_ver_after_downgrade: $ovt_ver_after_downgrade"
UpdateSummary "DEBUG: ovt_ver_after_downgrade: $ovt_ver_after_downgrade"
if [ "$ovt_ver_after_downgrade" == "$lower_version" ]; then
    LogMsg "INFO: After downgrade, the open-vm-tools version ($ovt_ver_after_downgrade) is correct"
    UpdateSummary "INFO: After downgrade, the open-vm-tools version ($ovt_ver_after_downgrade) is correct"
else
    LogMsg "INFO: After downgrade, the open-vm-tools version ($ovt_ver_after_downgrade) is incorrect"
    UpdateSummary "INFO: After downgrade, the open-vm-tools version ($ovt_ver_after_downgrade) is incorrect"
    SetTestStateFailed
    exit 1
fi


# Upgrage the open-vm-tools to distro_standard_version
yum upgrade open-vm-tools-desktop open-vm-tools -y
# Check the open-vm-tools version after upgrade
ovt_ver_after_upgrade=$(rpm -qa open-vm-tools)
UpdateSummary "print the upgrade version $version"
if [ "$ovt_ver_after_upgrade" == "$distro_standard_version" ]; then
    LogMsg "PASS: After upgrade, the open-vm-tools version ($ovt_ver_after_downgrade) is correct"
    UpdateSummary "PASS: After upgrade, the open-vm-tools version ($ovt_ver_after_downgrade) is correct"
    SetTestStateCompleted
    exit 0
else
    LogMsg "INFO: After upgrade, the open-vm-tools version ($ovt_ver_after_downgrade) is incorrect"
    UpdateSummary "INFO: After upgrade, the open-vm-tools version ($ovt_ver_after_downgrade) is incorrect"
    SetTestStateFailed
    exit 1
fi
