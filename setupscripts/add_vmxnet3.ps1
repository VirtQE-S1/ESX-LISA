########################################################################################
## Description:
##	Add a vmxnet3 to VM in setup pharse
##
## Revision:
##	v1.0.0 - boyang - 03/24/2018 - Draft the script for add a vmxnet3.
##  v1.1.0 - boyang - 01/08/2020 - Check params is null or not.
########################################################################################


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
if (-not $vmName) {
    "ERROR: VM name cannot be null!"
    exit 1
}

if (-not $hvServer) {
    "ERROR: hvServer cannot be null!"
    exit 1
}

if (-not $testParams) {
    Throw "FAIL: No test parameters specified"
}


# Output test parameters so they are captured in log file
"TestParams : '${testParams}'"


# Parse the test parameters
$rootDir = $null
$nicName = $null

$params = $testParams.Split(";")
foreach ($p in $params) {
    $fields = $p.Split("=")
    switch ($fields[0].Trim()) {
        "rootDir"   { $rootDir = $fields[1].Trim() }
        "nicName"   { $nicName = $fields[1].Trim() }
        default     {}
    }
}

# Check all parameters
if (-not $rootDir)
{
	"ERROR: no rootdir was specified"
}
else
{
	if ( (Test-Path -Path "${rootDir}") )
	{
		cd $rootDir
	}
	else
	{
		"ERROR: rootdir '${rootDir}' does not exist"
		return $Failed
	}
}

if ($null -eq $nicName) {
	"ERROR: Test parameter nicName was not specified"
	return $Failed
}


########################################################################################
# Main Body
########################################################################################
$retVal = $Failed


$vmOut = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmOut) {
    Write-Error -Message "Unable to create a VM object for VM $vmName" -Category ObjectNotFound -ErrorAction SilentlyContinue
    return $Failed
}


$old_nics = Get-NetworkAdapter -vm $vmOut
if ($null -eq $old_nics) {
    LogMsg 0 "ERROR: VM hasn't a NIC before starting."
    return $Failed
}


# Add a vmxnet3 NIC to VM
LogMsg 0 "DEBUG: nicName: $nicName"
$new_vmxnet3 = New-NetworkAdapter -VM $vmOut -NetworkName $nicName -Type vmxnet3 -WakeOnLan -StartConnected -Confirm:$false
LogMsg 0 "DEBUG: new_vmxnet3: $new_vmxnet3"
if ($null -ne $new_vmxnet3) {
    LogMsg 0 "INFO: New-NetworkAdapter VMXNET3($new_vmxnet3) well"
    $current_nic = Get-NetworkAdapter -VM $vmOut
    LogMsg 0 "DEBUG: Current NICs: $current_nic"
}
else {
    LogMsg 0 "ERROR: New-NetworkAdapter VMXNET3($new_vmxnet3) failed"
    return $Failed
}


$nics = Get-NetworkAdapter -VM $vmOut
if (( $nics.length - $old_nics.length) -eq 1 -and $new_vmxnet3.Type -eq "vmxnet3") {
    LogMsg 0 "INFO: NIC counts: $nics.length and new VMXNET3 type: $new_vmxnet3 are correct"
    $retVal = $Passed
}


return $retVal