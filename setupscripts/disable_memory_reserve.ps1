###############################################################################
##
## Description:
## Disable memory reserve settings 
##
###############################################################################
##
## Revision:
## V1.0.0 - ruqin - 8/15/2018 - Build the script
##
###############################################################################
<#
.Synopsis
    Disable memory reserve settings

.Description
    Disable memory reserve settings which is not reset by snapshot

.Parameter vmName
    Name of the test VM

.Parameter hvServer
    Name of the Hyper-V server hosting the VM.

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

$params = $testParams.Split(";")
foreach ($p in $params) {
    $fields = $p.Split("=")
    switch ($fields[0].Trim()) {
        "rootDir" { $rootDir = $fields[1].Trim() }
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


#Get Current VM
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj) {
    Write-ERROR -Message "CheckModules: Unable to create VM object for VM $vmName" -Category ObjectNotFound -ERRORAction SilentlyContinue
    return $Aborted
} 


try {
    # Disable reserve all memory option (snapshot will not totally revert this option)
    $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
    $spec.memoryReservationLockedToMax = $false
    $vmObj.ExtensionData.ReconfigVM($spec)


    # This command make VM refresh their reserve memory option (snapshot will not revert this option)
    Get-VMResourceConfiguration -VM $vmObj | Set-VMResourceConfiguration -MemReservationMB 0
    if ( -not $?) {
        LogPrint "WARN: Reset memory lock failed" 
        return $Failed
    }
}
catch {
    $ERRORMessage = $_ | Out-String
    LogPrint "ERROR: Lock all memory ERROR, please check it manually"
    LogPrint $ERRORMessage
    return $falFailedse
}


$retVal = $Passed
return $retVal
