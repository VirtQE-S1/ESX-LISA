#!/bin/bash


###############################################################################
##
## Description:
##  Checks open-vm-tools-debuginfo upgrade and downgrade.
##  The vmtoolsd status should be running after downgrade and upgrade.
##
## Revision:
##  v1.0.0 - ldu - 10/13/2017 - Draft script for case ESX-OVT-022
##  v1.0.1 - ldu - 01/21/2019 - Supports rhel8
##  v1.0.2 - boyang - 05/06/2019 - Grep incorrect OVT version value
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
distro_standard_version=`cat constants.sh | grep ${DISTRO}_standard_version | awk -F "=" '{print $2}'`
LogMsg "DEBUG: distro_standard_version: $distro_standard_version"
UpdateSummary "DEBUG: distro_standard_version: $distro_standard_version"


# Current DISTRO can't be supported
if [ -z $distro_standard_version ]; then
    LogMsg "ERROR: Current Guest DISTRO isn't supported, UPDATE XML for this DISTRO"
    UpdateSummary "ERROR: Current Guest DISTRO isn't supported, UPDATE XML for this DISTRO"
    SetTestStateAborted
    exit 1
fi

# Current Red Hat Enterprise Linux Server Release 6.X / (5.X) doesn't have OVT, it is VT
if [ $distro_standard_version == "NOOVT" ]; then
    LogMsg "WARNING: Current Guest $DISTRO doesn't have OVT, will skip it"
    UpdateSummary "WARNING: Current Guest $DISTRO doesn't have OVT, will skip it"
    SetTestStateSkipped
    exit 0
fi


# Install open-vm-tools-debuginfo for current Guest WITHOUT relationship of DISTR
yum install -y open-vm-tools-desktop
# HERE. Check result value
yum erase -y open-vm-tools-sdmp

systemctl restart vmtoolsd
service_status=$(systemctl status vmtoolsd | grep running -c)
if [ "$service_status" = "1" ]; then
    LogMsg "INFO: Service vmtoolsd is running"
    UpdateSummary "INFO: Service vmtoolsd is running"
else
    LogMsg "ERROR: The service vmtoolsd is not running"
    UpdateSummary "ERROR: The service vmtoolsd is not running"
    SetTestStateAborted
    exit 1
fi


# Get current version debuginfo version
url_prefix="http://download.eng.bos.redhat.com/brewroot/packages/open-vm-tools/"
standard_version=`cat constants.sh | grep ${DISTRO}_standard_version | awk -F "=" '{print $2}'`
LogMsg "DEBUG: standard_version: $standard_version"
UpdateSummary "DEBUG: standard_version: $standard_version"

standard_rpm=`cat constants.sh | grep ${DISTRO}_standard_rpm | awk -F "=" '{print $2}'`
LogMsg "DEBUG: standard_rpm: $standard_rpm"
UpdateSummary "DEBUG: standard_rpm: $standard_rpm"


# Download current version debuginfo OVT
wget -P /tmp/ $url_prefix$standard_rpm
# HERE. Check result value

yum install /tmp/*.rpm -y
# HERE. Check result value


debuginfo_standard=$(rpm -qa open-vm-tools-debuginfo)
LogMsg "DEBUG: debuginfo_standard: $debuginfo_standard"
UpdateSummary "DEBUG: debuginfo_standard: $debuginfo_standard"

if [ "$debuginfo_standard" == "$standard_version" ]; then
    LogMsg "INFO: After installation, the current open-vm-tools-debuginfo debuginfo version ($debuginfo_standard) is correct"
    UpdateSummary "INFO:  After installation, the current open-vm-tools-debuginfo debuginfo version ($debuginfo_standard) is correct"
else
    LogMsg "ERROR:  After install, the current open-vm-tools-debuginfo debuginfo version ($debuginfo_standard) is NOT correct"
    UpdateSummary "ERROR: After install, the current open-vm-tools-debuginfo debuginfo version ($debuginfo_standard) is NOT incorrect"
    SetTestStateAborted
    exit 1
fi


# Get OVT lower info
lower_version=`cat constants.sh | grep ${DISTRO}_lower_version | awk -F "=" '{print $2}'`
LogMsg "DEBUG: lower_version: $lower_version"
UpdateSummary "DEBUG: lower_version: $lower_version"

lower_rpm=`cat constants.sh | grep ${DISTRO}_lower_rpm | awk -F "=" '{print $2}'`
LogMsg "DEBUG: lower_rpm: $lower_rpm"
UpdateSummary "DEBUG: lower_rpm: $lower_rpm"


# Download lower version OVT
wget -P /root/ $url_prefix$lower_rpm
# HERE. Check result value


# Downgrade the open-vm-tools-debuginfo to a older version
yum downgrade /root/*.rpm -y
# HERE. Check result value


# Check the open-vm-tools-debuginfo version after downgrade
ovt_ver_after_downgrade=$(rpm -qa open-vm-tools-debuginfo)
LogMsg "DEBUG: ovt_ver_after_downgrade: $ovt_ver_after_downgrade"
UpdateSummary "DEBUG: ovt_ver_after_downgrade: $ovt_ver_after_downgrade"

if [ "$ovt_ver_after_downgrade" == "$lower_version" ]; then
    LogMsg "INFO: After downgrade, the open-vm-tools-debuginfo version ($ovt_ver_after_downgrade) is correct"
    UpdateSummary "INFO: After downgrade, the open-vm-tools-debuginfo version ($ovt_ver_after_downgrade) is correct"
else
    LogMsg "ERROR: After downgrade, the open-vm-tools-debuginfo version ($ovt_ver_after_downgrade) is NOT correct"
    UpdateSummary "ERROR: After downgrade, the open-vm-tools-debuginfo version ($ovt_ver_after_downgrade) is NOT correct"
    SetTestStateFailed
    exit 1
fi


# Upgrage the open-vm-tools-debuginfo to distro_standard_version
yum upgrade  /tmp/*.rpm -y
# HERE. Check result value


# Check the open-vm-tools-debuginfo version after upgrade
ovt_ver_after_upgrade=$(rpm -qa open-vm-tools-debuginfo)
LogMsg "DEBUG: ovt_ver_after_upgrade: $ovt_ver_after_upgrade"
UpdateSummary "DEBUG: ovt_ver_after_upgrade: $ovt_ver_after_upgrade"

if [ "$ovt_ver_after_upgrade" == "$standard_version" ]; then
    LogMsg "INFO: After upgrade, the open-vm-tools-debuginfo version ($ovt_ver_after_upgrade) is correct"
    UpdateSummary "INFO: After upgrade, the open-vm-tools-debuginfo version ($ovt_ver_after_upgrade) is correct"
    SetTestStateCompleted
    exit 0
else
    LogMsg "ERROR: After upgrade, the open-vm-tools-debuginfo version ($ovt_ver_after_upgrade) is incorrect"
    UpdateSummary "ERROR: After upgrade, the open-vm-tools-debuginfo version ($ovt_ver_after_upgrade) is incorrect"
    SetTestStateFailed
    exit 1
fi
