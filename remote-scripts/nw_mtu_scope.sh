#!/bin/bash


#######################################################################################
## Description:
##  Check mtu value scope scripts
#######################################################################################
## Revision:
##  v1.0.0 - xinhu - 09/11/2019 - Build script, current version won't test ifup / ifdown
#######################################################################################

dos2unix utils.sh

# Source utils.sh
. utils.sh || {
    echo "Error: unable to source utils.sh!"
    exit 1
}

UtilsInit


###############################################################################
## Main Body  
###############################################################################
# Function to reset mtu=1500 before check mtu scope
function ResetMtu(){
    LogMsg "Info: Set MTU default value 1500 before exit "
    UpdateSummary "Info: Set MTU default value 1500 before exit "
    ifconfig ${1} mtu 1500
    systemctl restart NetworkManager
    # Must sleep to wait for NetworkManager restart finish
    sleep 3
}


# Function to set validmtu
function SetValidMtu(){
    run=$(ifconfig ${2} mtu ${1}; echo $?)
    if [ $run -ne 0 ]; then
        LogMsg "Error: failed to set MTU=${1} "
        UpdateSummary "Error: failed to set MTU=${1} "
        ResetMtu ${2}
        SetTestStateFailed
        exit 1
    fi
    LogMsg "Info: success to set mtu=${1} "
    UpdateSummary "Info: success to set mtu=${1} "
}


# Function to set invalidmtu
function SetInvalidMtu(){
    ifconfig ${2} mtu ${1}
    run=$(echo $?)
    if [ $run -eq 0 ]; then
        LogMsg "Error: MTU can be set to ${1}"
        UpdateSummary "Error: MTU can be set to ${1}"
        ResetMtu ${2}
        SetTestStateFailed
        exit 1
    fi
    LogMsg "Info: MTU cannot be set to ${1} "
    UpdateSummary "Info: MTU cannot be set to ${1} "
}


# Function to check is IPV4 exits
function CheckIpv4(){
    # Get ipv4
    ipv4=$(ip add | grep e[tn][hosp] | grep inet | awk '{print $2}')
    # Check if 68 <= mtu <= 9000 
    if [ ${1} -ge 68 ] && [ ${1} -le 9000 ]; then
        if [ "x"$ipv4 == "x" ]; then   
            LogMsg "Error:lost ip after set MTU=${1}"
            UpdateSummary "Error: lost ip after set MTU=${1}"
            ResetMtu ${2}
            SetTestStateFailed
            exit 1
        fi
        LogMsg "Info: ip exists after set mtu=${1} "
        UpdateSummary "Info: ip exists after set mtu=${1} "
    else
        if [ "x"$ipv4 != "x" ]; then 
            LogMsg "Error: ip exists after set MTU=${1}"
            UpdateSummary "Error: ip exists after set MTU=${1}"
            ResetMtu ${2}
            SetTestStateFailed
            exit 1
        fi
        LogMsg "Info: ip will lost soon after set mtu=${1}"
        UpdateSummary "Info: ip will lost soon after set mtu=${1} "
    fi
}


# Confirm VM's NIC is vmxnet3, and get NIC name
lspci | grep -i Ethernet | grep -i vmxnet3
vmx=$(echo $?)
NIC=$(ls /sys/class/net/ | grep ^e[tn][hosp])

if [ "x"${NIC} == "x" ]; then
    LogMsg "Error: NIC name is null"
    UpdateSummary "Error: NIC name is null"
    SetTestStateAborted
    exit 1
fi

if [ ${vmx} -ne 0 ]; then
    LogMsg "Error: NIC is not vmxnet3"
    UpdateSummary "Error: NIC is not vmxnet3"
    ResetMtu ${NIC}
    SetTestStateAborted
    exit 1
fi
LogMsg "Confirm VM's NIC is vmxnet3 "
UpdateSummary "Confirm VM's NIC is vmxnet3 "
# Confirm mtu value is 1500 to make sure NIC work
ResetMtu ${NIC}

# Set MTU value = 9000, and check if ip exits
SetValidMtu 9000 ${NIC}
CheckIpv4 9000 ${NIC}
ResetMtu ${NIC}


# Set MTU value = 60, and check if ip will lost soon
SetValidMtu 60 ${NIC}
CheckIpv4 60 ${NIC}
ResetMtu ${NIC}


# Set invalid MTU value = 9001
SetInvalidMtu 9001 ${NIC}
# Set invalid MTU value = 59
SetInvalidMtu 59 ${NIC}


# Set MTU value = 67, and check if ip will lost soon
SetValidMtu 67 ${NIC}
CheckIpv4 67 ${NIC}
ResetMtu ${NIC}


# Set MTU value = 68, and check if ip exits
SetValidMtu 68 ${NIC}
CheckIpv4 68 ${NIC}
ResetMtu ${NIC}


SetTestStateCompleted
exit 0
