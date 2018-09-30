###############################################################################
##
## Description:
## Reset guests back to original host if migrated
##
###############################################################################
##
## Revision:
##  V1.0.0 - ruqin - 9/21/2018 - Build the script
##
###############################################################################
<#
.Synopsis
    Reset guests back to original host if migrated

.Description
    Reset guests back to original host if migrated. This case is used for cases 
which have migration

.Parameter vmName
    Name of the test VM

.Parameter hvServer
    Name of the ESXi server hosting the VM.

.Parameter testParams
    Semicolon separated list of test parameters

.Example
    <param>dstHost6.7=10.73.196.95,10.73.196.97</param>
    <param>dstHost6.5=10.73.199.191,10.73.196.230</param>
    <param>dstDatastore=freenas</param>

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


# Parse the test parameters
$rootDir = $null
$dstHost6_7 = $null
$dstHost6_5 = $null
$dstHost6_0 = $null


$params = $testParams.Split(";")
foreach ($p in $params) {
    $fields = $p.Split("=")
    switch ($fields[0].Trim()) {
        "rootDir" { $rootDir = $fields[1].Trim() }
        "dstHost6.7" { $dstHost6_7 = $fields[1].Trim()}
        "dstHost6.5" { $dstHost6_5 = $fields[1].Trim()}
        "dstHost6.0" { $dstHost6_0 = $fields[1].Trim()}
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


if (-not $dstHost6_7 -or -not $dstHost6_5 -or -not $dstHost6_0) {
    "INFO: dstHost 6.7 is $dstHost6_7"
    "INFO: dstHost 6.5 is $dstHost6_5"
    "INFO: dstHost 6.0 is $dstHost6_0"
    "Warn : Not all dstHost was specified"
}


# Source the tcutils.ps1 file
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


# Get another VM by change Name
$GuestBName = $vmName.Split('-')
$GuestBName[-1] = "B"
$GuestBName = $GuestBName -join "-"


# Specify dst host
$dstHost = FindDstHost -hvServer $hvServer -Host6_0 $dstHost6_0 -Host6_5 $dstHost6_5 -Host6_7 $dstHost6_7
if ($null -eq $dstHost) {
    LogPrint "ERROR: Cannot find required Host"    
    DisconnectWithVIServer
    return $Aborted
}
LogPrint "INFO: Another Host is $dstHost"


# Find Guest A
$guestAHost = $hvServer
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj) {
    LogPrint "ERROR: Unable to Get-VM with $vmName on $hvServer"
    $guestAHost = $dstHost
    $vmObj = Get-VMHost -Name $dstHost| Get-VM -Name $vmName
    if (-not $vmObj) {
        LogPrint "ERROR: Unable to Get-VM with $vmName on $dstHost"
        return $Aborted
    }
}


# Find Guest B
$guestBHost = $hvServer
$GuestB = Get-VMHost -Name $hvServer | Get-VM -Name $GuestBName
if (-not $GuestB) {
    LogPrint "ERROR: Unable to Get-VM with $GuestBName on $hvServer"
    $guestBHost = $dstHost
    $GuestB = Get-VMHost -Name $dstHost| Get-VM -Name $GuestBName
    if (-not $GuestB) {
        LogPrint "ERROR: Unable to Get-VM with $GuestBName on $dstHost"
        return $Aborted
    }
}


# Stop Guest A
if ($vmObj.PowerState -ne "PoweredOff") {
    $status = Stop-VM $vmObj -Confirm:$False
    if (-not $?) {
        LogPrint "ERROR: Cannot stop VM $vmName, $status"
        return $Aborted
    }
}


# Stop Guest B
if ($GuestB.PowerState -ne "PoweredOff") {
    $status = Stop-VM $GuestB -Confirm:$False
    if (-not $?) {
        LogPrint "ERROR: Cannot stop VM $GuestB, $status"
        return $Aborted
    }
}


# Refresh VM
$vmObj = Get-VMHost -Name $guestAHost | Get-VM -Name $vmName
$GuestB = Get-VMHost -Name $guestBHost | Get-VM -Name $GuestBName


# Find old datastore
$oldDatastore = Get-Datastore -Name "datastore-*" -VMHost $hvServer
if (-not $oldDatastore) {
    LogPrint "ERROR: Unable to Get required original datastore $oldDatastore"
    return $Aborted
}


# Move Guest A back to host
Move-VM -VMotionPriority High -VM $vmObj -Destination (Get-VMHost $hvServer) `
    -Datastore $oldDatastore -Confirm:$false -ErrorAction SilentlyContinue
if (-not $?) {
    LogPrint "ERROR: Cannot Move $vmName back to $oldDatastore and $hvServer in reset process"
    return $Aborted
}
LogPrint "INFO: Move $vmName back to $oldDatastore and $hvServer in reset process"



# Move Guest B back to host
Move-VM -VMotionPriority High -VM $GuestB -Destination (Get-VMHost $hvServer) `
    -Datastore $oldDatastore -Confirm:$false -ErrorAction SilentlyContinue
if (-not $?) {
    LogPrint "ERROR: Move $GuestBName back to $oldDatastore and $hvServer in reset process"
    return $Aborted
}
LogPrint "INFO: Move $GuestBName back to $oldDatastore and $hvServer in reset process"


# Check Guest A and Guest B host
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
$GuestB = Get-VMHost -Name $hvServer | Get-VM -Name $GuestBName
if (-not $vmObj -and -not $GuestB) {
    LogPrint "ERROR: Reset VM failed"
    return $Aborted
}
else {
    $retVal = $Passed
}

return $retVal
