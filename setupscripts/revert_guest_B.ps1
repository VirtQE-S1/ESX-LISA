###############################################################################
##
## Description:
## Stop the test VM and then reset it to a snapshot.
##
## Revision:
##	v1.0.0 - ruqin - 07/27/2018 - Draft the script for Stop the test VM and then reset it to a snapshot
##
###############################################################################
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

param([string] $vmName, [string] $hvServer, [string] $testParams)

#
# Checking the input arguments
#
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

#
# Output test parameters so they are captured in log file
#
"TestParams : '${testParams}'"

. .\setupscripts\tcutils.ps1

###############################################################################
#
# Main Body
#
###############################################################################

$retVal = $Failed

# Get VM
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj) {
    LogPrint "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
    return $Aborted
}


# Get Guest-B VM Name
$testVMName = $vmObj.Name.Split('-')
# Get another VM by change Name
$testVMName[-1] = "B"
$testVMName = $testVMName -join "-"
$vmName = $testVMName

if (-not $vmName -or -not $hvServer) {
    LogPrint "Error : ResetVM was passed an bad vmName or bad hvServer"
    return $Aborted
}

LogPrint "Info : ResetVM( $($vmName) )"

$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj) {
    LogPrint "Error : ResetVM cannot find the VM $($vmName)"
    return $Aborted
}

#
# If the VM is not stopped, try to stop it
#
if ($vmObj.PowerState -ne "PoweredOff") {
    LogPrint "Info : $($vmName) is not in a stopped state - stopping VM"
    $outStopVm = Stop-VM -VM $vmObj -Confirm:$false -Kill
    if ($outStopVm -eq $false -or $outStopVm.PowerState -ne "PoweredOff") {
        LogPrint "Error : ResetVM is unable to stop VM $($vmName). VM has been disabled"
        return $Aborted
    }
}

#
# Reset the VM to a snapshot to put the VM in a known state.  The default name is
# ICABase.  This can be overridden by the global.defaultSnapshot in the global section
# and then by the vmSnapshotName in the VM definition.
#
$snapshotName = "ICABase"

#
# Find the snapshot we need and apply the snapshot
#
$snapshotFound = $false
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
$snapsOut = Get-Snapshot -VM $vmObj
if ($snapsOut) {
    foreach ($s in $snapsOut) {
        if ($s.Name -eq $snapshotName) {
            LogPrint "Info : $($vmName) is being reset to snapshot $($s.Name)"
            $setsnapOut = Set-VM -VM $vmObj -Snapshot $s -Confirm:$false
            if ($setsnapOut) {
                $snapshotFound = $true
                break
            }
            else {
                LogPrint "Error : ResetVM is unable to revert VM $($vmName) to snapshot $($s.Name). VM has been disabled"
                return $Aborted
            }
        }
    }
}

#
# Make sure the snapshot left the VM in a stopped state.
#
if ($snapshotFound) {
    #
    # If a VM is in the Suspended (Saved) state after applying the snapshot,
    # the following will handle this case
    #
    $vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
    if ($vmObj) {
        if ($vmObj.PowerState -eq "Suspended") {
            LogPrint "Info : $($vmName) - resetting to a stopped state after restoring a snapshot"
            $stopvmOut = Stop-VM -VM $vmObj -Confirm:$false -Kill
            if ($stopvmOut -or $stopvmOut.PowerState -ne "PoweredOff") {
                LogPrint "Error : ResetVM is unable to stop VM $($vmName). VM has been disabled"
                return $Aborted
            }
        }
    }
    else {
        LogPrint "Error : ResetVM cannot find the VM $($vmName)"
        return $Aborted
    }
}
else {
    LogPrint "Warn : There's no snapshot with name $snapshotName found in VM $($vmName). Making a new one now."
    $newSnap = New-Snapshot -VM $vmObj -Name $snapshotName
    if ($newSnap) {
        $snapshotFound = $true
        LogPrint "Info : $($vmName) made a snapshot $snapshotName."
    }
    else {
        LogPrint "Error : ResetVM is unable to make snapshot for VM $($vmName)."
        return $Aborted
    }
}

$retVal = $Passed
return $retVal
