#!/bin/bash


########################################################################################
##	Description:
##		Check mtu value scope scripts. - BZ1503193.
##	Revision:
##		v1.0.0 - xinhu - 09/11/2019 - Build script.
########################################################################################


# Source utils.sh.
dos2unix utils.sh
. utils.sh || {
    echo "ERROR: unable to source utils.sh!"
    exit 1
}

UtilsInit


########################################################################################
## Main Body  
########################################################################################
# Function to reset mtu=1500 before check mtu scope.
function ResetMtu(){
    LogMsg "INFO: Set MTU default value 1500 before exit."
    UpdateSummary "INFO: Set MTU default value 1500 before exit."
    ifconfig ${1} mtu 1500

    systemctl restart NetworkManager
    # Must sleep to wait for NetworkManager restart finish
    sleep 6
}


# Function to set validmtu.
function SetValidMtu(){
    run=$(ifconfig ${2} mtu ${1}; echo $?)
    if [ $run -ne 0 ]; then
		LogMsg "ERROR: Failed to set MTU=${1}. Will reset its MTU to default value(1500)."
		UpdateSummary "ERROR: Failed to set MTU=${1}. Will reset its MTU to default value(1500)."
        ResetMtu ${2}

        SetTestStateFailed
        exit 1
    fi

    LogMsg "INFO: Success to set mtu=${1}."
    UpdateSummary "INFO: Success to set mtu=${1}."
}


# Function to set invalid MTU.
function SetInvalidMtu(){
    ifconfig ${2} mtu ${1}
    run=$(echo $?)
    if [ $run -eq 0 ]; then
		LogMsg "ERROR: MTU shouldn't be set to ${1}. But it worked! Will reset its default MTU value(1500)."
		UpdateSummary "ERROR: MTU shouldn't be set to ${1}. But it worked! Will reset its default MTU value(1500)."
        ResetMtu ${2}

        SetTestStateFailed
        exit 1
    fi

    LogMsg "INFO: MTU cannot be set to ${1} like what we expect."
    UpdateSummary "INFO: MTU cannot be set to ${1} like what we expect."
}


# Function to check is IPV4 exits.
function CheckIpv4(){
    # Get ipv4
    ipv4=$(ip add | grep e[tn][hosp] | grep inet | awk '{print $2}')
    LogMsg "DEBUG: ipv4: ${ipv4}"
    UpdateSummary "DEBUG: ipv4: ${ipv4}"

    # Check if 68 <= mtu <= 9000 
    if [ ${1} -ge 68 ] && [ ${1} -le 9000 ]; then
        if [ "x"$ipv4 == "x" ]; then   
            LogMsg "ERROR: Lost IP after set MTU=${1} which is a valid MTU value."
            UpdateSummary "ERROR: Lost IP after set MTU=${1} which is a valid MTU value."
            ResetMtu ${2}

            SetTestStateFailed
            exit 1
        fi

        LogMsg "INFO: IP exists after set mtu=${1} which is a valid MTU value."
        UpdateSummary "INFO: IP exists after set mtu=${1} which is a valid MTU value."
    else
        if [ "x"$ipv4 != "x" ]; then 
            LogMsg "ERROR: IP exists after set MTU=${1} which is a invalid MTU value."
            UpdateSummary "ERROR: ip exists after set MTU=${1} which is a invalid MTU value."
            ResetMtu ${2}

            SetTestStateFailed
            exit 1
        fi

        LogMsg "INFO: IP was lost soon after set mtu=${1} which is a invalid MTU value."
        UpdateSummary "INFO: IP was lost soon after set mtu=${1} which is a invalid MTU value."
    fi
}


# Confirm VM's NIC is a vmxnet3, and get NIC name.
lspci | grep -i Ethernet | grep -i vmxnet3
vmx=$(echo $?)
NIC=$(ls /sys/class/net/ | grep ^e[tn][hosp])

if [ "x"${NIC} == "x" ]; then
    LogMsg "ERROR: NIC name is null."
    UpdateSummary "ERROR: NIC name is null."

    SetTestStateAborted
    exit 1
fi

if [ ${vmx} -ne 0 ]; then
    LogMsg "ERROR: NIC is not vmxnet3."
    UpdateSummary "ERROR: NIC is not vmxnet3."
    ResetMtu ${NIC}

    SetTestStateAborted
    exit 1
fi
LogMsg "INFO: Confirm VM's NIC is a vmxnet3."
UpdateSummary "INFO: Confirm VM's NIC is a vmxnet3."


# Confirm mtu value is 1500 to make sure NIC work.
ResetMtu ${NIC}


# Set MTU value = 9000, and check if ip exits.
SetValidMtu 9000 ${NIC}
CheckIpv4 9000 ${NIC}
ResetMtu ${NIC}


# Set a invalid MTU value = 9001.
SetInvalidMtu 9001 ${NIC}


# Set a invalid MTU value = 59.
SetInvalidMtu 59 ${NIC}


# Set a MTU value = 67, and check if ip will lost soon.
SetValidMtu 67 ${NIC}
CheckIpv4 67 ${NIC}
ResetMtu ${NIC}


# Set a MTU value = 68, and check if ip exits.
SetValidMtu 68 ${NIC}
CheckIpv4 68 ${NIC}
ResetMtu ${NIC}


SetTestStateCompleted
exit 0
