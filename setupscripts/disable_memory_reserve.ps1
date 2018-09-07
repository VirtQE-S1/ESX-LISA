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


$status = DisableMemoryReserve $vmName $hvServer
if ( -not $status[-1]) {
    LogPrint "ERROR: Disable memory reserve error" 
}
else {
    $retVal = $Passed
}


return $retVal
