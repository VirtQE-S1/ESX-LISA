#######################################################################################
## Description:
##  Stop the test VM and then reset it to a snapshot.
##
## Revision:
##	v1.0.0 - ruqin - 07/27/2018 - Draft the script.
#######################################################################################


<#
 .Synopsis
    Make sure the test VM is stopped

 .Description
    Stop the test VM and then reset it to a snapshot.
    This ensures the VM starts the test run in a
    known good state.

.Parameter vmName
    Name of the VM to remove disk from.

.Parameter hvServer
    Name of the ESXi server hosting the VM.

.Parameter testParams
    Semicolon separated list of test parameters.
#>


# Checking the input arguments.
param([string] $vmName, [string] $hvServer, [string] $testParams)
if (-not $vmName) {
    "FAIL: VM name cannot be null!"
    exit 1
}

if (-not $hvServer) {
    "FAIL: hvServer cannot be null!"
    exit 1
}

if (-not $testParams) {
    Throw "FAIL: No test parameters specified"
}


# Output test parameters so they are captured in log file.
"TestParams : '${testParams}'"


. .\setupscripts\tcutils.ps1


#######################################################################################
# Main Body
#######################################################################################
$retVal = $Failed


# Get VM
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj) {
    LogPrint "ERROR: Unable to Get-VM with $vmName"
    return $Aborted
}


# Get Guest-B VM Name
$testVMName = $vmObj.Name.Split('-')
$testVMName[-1] = "B"
$testVMName = $testVMName -join "-"
$vmBName = $testVMName


if (-not $vmBName -or -not $hvServer) {
    LogPrint "ERROR: ResetVM was passed an bad vmBName or bad hvServer."
    return $Aborted
}


LogPrint "INFO: ResetVM( $($vmBName) )."
$vmBObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmBName
if (-not $vmBObj) {
    LogPrint "ERROR: ResetVM cannot find the VM $($vmBName)"
    return $Aborted
}


# If the VM is not stopped, try to stop it.
if ($vmBObj.PowerState -ne "PoweredOff") {
    LogPrint "Info : $($vmBName) is not in a stopped state - stopping VM"
    $outStopVm = Stop-VM -VM $vmBObj -Confirm:$false -Kill
    if ($outStopVm -eq $false -or $outStopVm.PowerState -ne "PoweredOff") {
        LogPrint "Error : ResetVM is unable to stop VM $($vmBName). VM has been disabled"
        return $Aborted
    }
}


# Reset the VM to a snapshot to put the VM in a known state.  The default name is
# ICABase.  This can be overridden by the global.defaultSnapshot in the global section
# and then by the vmSnapshotName in the VM definition.
$snapshotName = "ICABase"


# Find the snapshot we need and apply the snapshot.
$snapshotFound = $false
$vmBObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmBName
$snapsOut = Get-Snapshot -VM $vmBObj
if ($snapsOut) {
    foreach ($s in $snapsOut) {
        if ($s.Name -eq $snapshotName) {
            LogPrint "INFO: $($vmBName) is being reset to snapshot $($s.Name)"
            $setsnapOut = Set-VM -VM $vmBObj -Snapshot $s -Confirm:$false
            if ($setsnapOut) {
                $snapshotFound = $true
                break
            }
            else {
                LogPrint "ERROR: ResetVM is unable to revert VM $($vmBName) to snapshot $($s.Name). VM has been disabled"
                return $Aborted
            }
        }
    }
}


# Make sure the snapshot left the VM in a stopped state.
if ($snapshotFound) {
    # If a VM is in the Suspended (Saved) state after applying the snapshot,
    # the following will handle this case
    $vmBObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmBName
    if ($vmBObj) {
        if ($vmBObj.PowerState -eq "Suspended") {
            LogPrint "INFO: $($vmBName) - resetting to a stopped state after restoring a snapshot"
            $stopvmOut = Stop-VM -VM $vmBObj -Confirm:$false -Kill
            if ($stopvmOut -or $stopvmOut.PowerState -ne "PoweredOff") {
                LogPrint "Error : ResetVM is unable to stop VM $($vmBName). VM has been disabled"
                return $Aborted
            }
        }
    }
    else {
        LogPrint "ERROR: ResetVM cannot find the VM $($vmBName)"
        return $Aborted
    }
}
else {
    LogPrint "ERROR: There's no snapshot with name $snapshotName found in VM $($vmBName). Making a new one now."
    $newSnap = New-Snapshot -VM $vmBObj -Name $snapshotName
    if ($newSnap) {
        $snapshotFound = $true
        LogPrint "Info : $($vmBName) made a snapshot $snapshotName."
    }
    else {
        LogPrint "Error : ResetVM is unable to make snapshot for VM $($vmBName)."
        return $Aborted
    }
}

$retVal = $Passed
return $retVal
