###############################################################################
##
## Description:
## Hot plug and unplug the vmxnet3 network adapter
##
###############################################################################
##
## Revision:
## V1.0 - boyang - 08/23/2017 - Build script
##
###############################################################################

<#
.Synopsis
    Hot plug and unplug the vmxnet3 network adapter

.Description
    When VM alives, Hot plug and unplug vmxnet3, no crash

.Parameter vmName
    Name of the test VM.

.Parameter hvServer
    Name of the VIServer hosting the VM.

.Parameter testParams
    Semicolon separated list of test parameters.
#>

param([String] $vmName, [String] $hvServer, [String] $testParams)

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

#
# Parse test parameters
#
$rootDir = $null
$sshKey = $null
$ipv4 = $null
$logdir = $null

$params = $testParams.Split(";")
foreach ($p in $params) 
{
	$fields = $p.Split("=")
	switch ($fields[0].Trim()) 
	{
		"rootDir"		{ $rootDir = $fields[1].Trim() }
		"sshKey"		{ $sshKey = $fields[1].Trim() }
		"ipv4"			{ $ipv4 = $fields[1].Trim() }
		"TestLogDir"	{ $logdir = $fields[1].Trim()}
		default			{}
    }
}

#
# Check all parameters are valid
#
if (-not $rootDir)
{
	"Warn : no rootdir was specified"
}
else
{
	if ( (Test-Path -Path "${rootDir}") )
	{
		cd $rootDir
	}
	else
	{
		"Warn : rootdir '${rootDir}' does not exist"
	}
}

if ($null -eq $sshKey) 
{
	"FAIL: Test parameter sshKey was not specified"
	return $False
}

if ($null -eq $ipv4) 
{
	"FAIL: Test parameter ipv4 was not specified"
	return $False
}

if ($null -eq $logdir)
{
	"FAIL: Test parameter logdir was not specified"
	return $False
}

#
# Source tcutils.ps1
#
. .\setupscripts\tcutils.ps1
PowerCLIImport
ConnectToVIServer $env:ENVVISIPADDR `
                  $env:ENVVISUSERNAME `
                  $env:ENVVISPASSWORD `
                  $env:ENVVISPROTOCOL

###############################################################################
#
# Main Body
#
###############################################################################

$retVal = $Failed
# "VM Network" is default value in vSphere
$new_nic_name = "VM Network" 

#
# Confirm VM
#
$vmOut = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmOut)
{
    Write-Host -F Yellow "ABORT: Unable to get-vm with $vmName"
    Write-Output "ABORT: Unable to get-vm with $vmName"
    DisconnectWithVIServer
	return $Aborted
}

#
# Hot plug a new nic named $new_nic_name, DON'T test on original nic, nics counts will be 2
# Hot unplug this new nic named $new_nic_name, adapter count will be 1(original one)
#
$new_nic = New-NetworkAdapter -VM $vmOut -NetworkName $new_nic_name -WakeOnLan -StartConnected -Confirm:$false
Write-Host -F Gray "DONE. Get new NIC: $new_nic"
Write-Output "DONE. Get new NIC: $new_nice"

$all_nic_count = (Get-NetworkAdapter -VM $vmOut).Count
if ($all_nic_count -eq 2)
{
    Write-Host -F Gray "DONE. Hot plug the new vmxnet3 well"
    Write-Output "DONE: Hot plug the new vmxnet3 well"

    Write-Host -F Gray "NOW: Will hot unplug this NIC"
    Write-Output "NOW: Will hot unplug this NIC"
    #
    # As Powercli can't Remove-NetworkAdapter in poweredon state
    # So, Change its operation firstly and reconfig VM later
    #
    $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
    $devSpec = New-Object VMware.Vim.VirtualDeviceConfigSpec
    $devSpec.operation = "remove"
    $devSpec.device += $new_nic.ExtensionData
    $spec.deviceChange += $devSpec
    Start-Sleep -S 6    
    $vmOut.ExtensionData.ReconfigVM_Task($spec)

    Start-Sleep -S 6

    $all_nic_count = (Get-NetworkAdapter -VM $vmOut).Count
    if ($all_nic_count -eq 1)
    {
        Write-Host -F Green "PASS: Hot unplug this adapter successfully"
        Write-Output "PASS: Hot unplug this adapter successfully"
        $retVal = $Passed
    }
}
else
{
    Write-Host -F Green "FAIL: Unknow issue after hot plug NIC, check it manually"
    Write-Output "AFAIL: Unknow issue after hot plug NIC, check it manually"  
}

DisconnectWithVIServer

return $retVal