###############################################################################
##
## Description:
##	Add a vmxnet3 to VM in setup pharse
##
## Revision:
##	v1.0.0 - boyang - 03/24/2018 - Draft the script for add a vmxnet3
##
###############################################################################
<#
.Synopsis
    Add a vmxnet3 to VM in setup pharse

.Description
    Add a vmxnet3 to VM in setup pharse

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

###############################################################################
#
# Main Body
#
###############################################################################


$retVal = $Failed


$vmOut = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmOut) {
    Write-Error -Message "Unable to create a VM object for VM $vmName" -Category ObjectNotFound -ErrorAction SilentlyContinue
    return $Aborted
}


$old_nics = Get-NetworkAdapter -vm $vmOut

#
# Add a vmxnet3 NIC to VM
#
$new_vmxnet3 = New-NetworkAdapter -VM $vmOut -NetworkName "VM Network" -Type vmxnet3 -WakeOnLan -StartConnected -Confirm:$false
if ($new_vmxnet3) {
    Write-Host -F red "DONE: New-NetworkAdapter VMXNET3($new_vmxnet3) well"
    Write-Output "DONE: New-NetworkAdapter VMXNET3($new_vmxnet3) well"
    $current_nic = Get-NetworkAdapter -VM $vmOut
    Write-Host -F red "DEBUG: Current NICs are: $current_nic"
    Write-Output "DEBUG: Current NICs are: $current_nic"

}
else {
    Write-Host -F red "WARNING: New-NetworkAdapter VMXNET3($new_vmxnet3) failed"
    Write-Output "WARNING: New-NetworkAdapter VMXNET3($new_vmxnet3) failed"
    return $Aborted
}

$nics = Get-NetworkAdapter -VM $vmOut

if ( ( $nics.length - $old_nics.length) -eq 1 -and $new_vmxnet3.Type -eq "vmxnet3") {
    Write-Host -F red "PASS: NIC counts and new VMXNET3 type: $new_vmxnet3 are correct"
    Write-Output "PASS: NIC counts: $nics.length and new VMXNET3 type: $new_vmxnet3 are correct"
    $retVal = $Passed
}


return $retVal