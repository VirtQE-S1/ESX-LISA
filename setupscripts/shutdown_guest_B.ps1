###############################################################################
##
## Description:
## Shutdown and revert Guest B
##
###############################################################################
##
## Revision:
## V1.0.0 - ruqin - 8/23/2018 - Build the script
##
###############################################################################
<#
.Synopsis
    Shutdown and revert Guest B

.Description
    Shutdown and revert Guest B. Have option to disable memory reserve

.Parameter vmName
    Name of the test VM

.Parameter hvServer
    Name of the ESXi server hosting the VM.

.Parameter testParams
    Semicolon separated list of test parameters

#>

param([String] $vmName, [String] $hvServer, [String] $testParams)
#
# Checking the input arguments
#
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

#
# Display the test parameters so they are captured in the log file
#
"TestParams : '${testParams}'"

#
# Parse the test parameters
#
$rootDir = $null
$memoryReserve = $null
$revertSnapshot = $null


$params = $testParams.Split(";")
foreach ($p in $params) {
    $fields = $p.Split("=")
    switch ($fields[0].Trim()) {
        "rootDir" { $rootDir = $fields[1].Trim() }
        "memoryReserve" { $memoryReserve = $fields[1].Trim() }
        "revertSnapshot" { $revertSnapshot = $fields[1].Trim() }
        default {}
    }
}


if (-not $rootDir) {
    "Warn : no rootdir was specified"
}
else {
    if ( (Test-Path -Path "${rootDir}") ) {
        Set-Location $rootDir
    }
    else {
        "Warn : rootdir '${rootDir}' does not exist"
    }
}


# By default, do not need to disable memory reserve
if (-not $memoryReserve) {
    $memoryReserve = $false
}
else {
    $memoryReserve = [System.Convert]::ToBoolean($memoryReserve)
}


# By default, revert guest B snapshot
if (-not $revertSnapshot) {
    $revertSnapshot = $true 
}
else {
    $revertSnapshot = [System.Convert]::ToBoolean($revertSnapshot)
}


#
# Source the tcutils.ps1 file
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
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj) {
    LogPrint "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
    return $Aborted
}


# Get another vmName
$GuestBName = $vmObj.Name.Split('-')
# Get another VM by change Name
$GuestBName[-1] = "B"
$GuestBName = $GuestBName -join "-"


# revert snapshot 
if ($revertSnapshot) {
    $status = RevertSnapshotVM $GuestBName $hvServer 
    if (-not $status[-1]) {
        LogPrint "ERROR: Revert snapshot failed" 
        return $Failed
    }
}
else {
    # Do not revert snapshot but shutdown system
    $GuestB = Get-VMHost -Name $hvServer | Get-VM -Name $GuestBName
    # Shutdown another VM
    Stop-VM $GuestB -Confirm:$False -RunAsync:$true
    if (-not $?) {
        LogPrint "ERROR : Cannot stop VM $GuestBName"
        return $Failed
    }
}


# disable memory revese
if ($memoryReserve) {
    $status = DisableMemoryReserve $GuestBName $hvServer
    if ( -not $status[-1]) {
        LogPrint "ERROR: Disable memory reserve error" 
    }
    else {
        $retVal = $Passed
    }
}
else {
    $retVal = $Passed
}


return $retVal
