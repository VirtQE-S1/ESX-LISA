###############################################################################
##
## Description:
##   This script will remove vmxnet3 from VM
###############################################################################
##
## Revision:
## v1.0 - boyang - 08/23/2017 - Draft script for remove vmxnet3.
##
###############################################################################
<#
.Synopsis
    This script will remove vmxnet3 from VM.

.Description
    The script will remove vmxnet3 from VM.

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
if (-not $vmName)
{
    "FAIL: VM name cannot be null!"
    exit
}

if (-not $hvServer)
{
    "FAIL: hvServer cannot be null!"
    exit
}

if (-not $testParams)
{
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

#
# VM is in powered off status, as a setup script to remove vmxnet3
#
$vmOut = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmOut)
{
    Write-Error -Message "nw_ping.ps1: Unable to create VM object for VM $vmName" -Category ObjectNotFound -ErrorAction SilentlyContinue
    return $Aborted
}

#
# MUST add a e1000e NIC to connect VIServer
#
$e1000e = New-NetworkAdapter -VM $vmOut -NetworkName "VM Network" -Type e1000e -WakeOnLan -StartConnected -Confirm:$false
if ($e1000e)
{
    Write-Output "PASS: New-NetworkAdapter E1000E well."
    $current_nic = Get-NetworkAdapter -VM $vmOut
    Write-Host -F red "Debug: Current NICs are: $current_nic"    
}
else
{
    Write-Error "FAIL: New-NetworkAdapter E1000E failed."
    return $Aborted
}

$nics = Get-NetworkAdapter -VM $vmOut
foreach ($nic in $nics)
{
    Write-Host -F red nic is ${nic} , nic.Type is ${nic}.Type
    if (${nic}.Type -eq "Vmxnet3")
    {
        $result = Remove-NetworkAdapter -NetworkAdapter $nic -Confirm:$false
        if ($result -eq $null)
        {
            Write-Output "PASS: Remove-NetworkAdapter well"
            $retVal = $true
        }
        else
        {
            Write-Host -F red nic.Type is ${nic}.Type
            write-output "FAIL: Remove-NetworkAdapter Failed"
        }
    }
}

return $retVal