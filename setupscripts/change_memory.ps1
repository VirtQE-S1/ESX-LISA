###############################################################################
##
## Description:
##   Change memory of vm
##
###############################################################################
##
## Revision:
## v1.0.0 - hhei  - 01/04/2017 - Change memory of vm
## v2.0.0 - ruqin - 09/17/2018 - Rewrite by new format and add memory reserve
##                                function
##
###############################################################################
<#
.Synopsis
    Modify the memory of a VM .

.Description
    Modify the memory of a VM, must use with disable memory reserve

.Parameter vmName
    Name of the VM to modify.

.Parameter hvServer
    Name of the ESXi server hosting the VM.

.Parameter testParams
    A semicolon separated list of test parameters.

.Example
    .\change_memory.ps1 "testVM" "localhost" "VMMemory=2GB"
#>

param([String] $vmName, [String] $hvServer, [String] $testParams)


# Checking the input arguments
if (-not $vmName) {
    "Error: VM name cannot be null!"
    exit 1
}


if (-not $hvServer) {
    "Error: hvServer cannot be null!"
    exit 1
}


if (-not $testParams) {
    Throw "Error: No test parameters specified"
}


# Display the test parameters so they are captured in the log file
"TestParams : '${testParams}'"


# Source the tcutils.ps1 file
. .\setupscripts\tcutils.ps1


# Parse the test parameters
$rootDir = $null
$VMMemory = $null
$memoryReserve = $null


$params = $testParams.Split(";")
foreach ($p in $params) {
    $fields = $p.Split("=")
    switch ($fields[0].Trim()) {
        "rootDir" { $rootDir = $fields[1].Trim() }
        "VMMemory" { $VMMemory = $fields[1].Trim() }
        "memoryReserve" { $memoryReserve = $fields[1].Trim() }
        default {}
    }
}


if (-not $rootDir) {
    LogPrint "Warn : no rootdir was specified"
}
else {
    if ( (Test-Path -Path "${rootDir}") ) {
        Set-Location $rootDir
    }
    else {
        LogPrint "Warn : rootdir '${rootDir}' does not exist"
    }
}


# Check VMMemory parameter
if ($null -eq $VMMemory) {
    LogPrint "ERROR: Target memory is not set"
    return $Aborted
}


# Default disable memory reserve
if ($null -eq $memoryReserve) {
    $memoryReserve = $false
}
else {
    $memoryReserve = [System.Convert]::ToBoolean($memoryReserve)
}


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
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj) {
    LogPrint "ERROR: Unable to Get-VM with $vmName"
    return $Aborted
}


# Change String to int format
try {
    $VMMemory = $VMMemory / 1GB
}
catch {
    $ERRORMessage = $_ | Out-String
    LogPrint "ERROR: Cannot convert string to required int"
    LogPrint $ERRORMessage
    return $Aborted
}


# Update VMMemory on the VM
Set-VM $vmObj -MemoryGB $VMMemory -Confirm:$false
if (-not $?) {
    LogPrint "ERROR: Set memory failed"
    return $Failed
}
else {
    LogPrint "INFO: Successfully update memory to $VMMemory"
    $retVal = $Passed
}


if ($memoryReserve) {
    # Lock all memory
    try {
        # Enable reserve all memory option
        $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
        $spec.memoryReservationLockedToMax = $true
        $vmObj.ExtensionData.ReconfigVM_Task($spec)
    }
    catch {
        $ERRORMessage = $_ | Out-String
        LogPrint "ERROR: Lock all memory ERROR, please check it manually"
        LogPrint $ERRORMessage
        return $Failed
    } 
}


return $retVal
