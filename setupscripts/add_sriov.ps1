########################################################################################
## Description:
##  Add sriov nic 
##
## Revision:
##  v1.0.0 - ruqin - 08/08/2018 - Build the script
##  v1.0.1 - boyang - 08/28/209 - Add debug info
##  v1.1.0 - boyang - 10/16/2019 - Skip test in these hosts hw NO support.
########################################################################################


<#
.Synopsis
    Add sriov nic

.Description
    Add sriov nic in setup phrase

.Parameter vmName
    Name of the test VM

.Parameter hvServer
    Name of the ESXi server hosting the VM.

.Parameter testParams
    Semicolon separated list of test parameters

.Example
    <testparams>
        <param>mtuChange=True</param>
        <param>sriovNum=2</param>
    </testparams>
    
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
$sriovNum = $null
$mtuChange = $null

$params = $testParams.Split(";")
foreach ($p in $params) {
    $fields = $p.Split("=")
    switch ($fields[0].Trim()) {
        "rootDir" { $rootDir = $fields[1].Trim() }
        "sriovNum" { $sriovNum = $fields[1].Trim() }
        "mtuChange" { $mtuChange = $fields[1].Trim() }
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

# If not set this para, the default value is 1
if ($null -eq $sriovNum) {
    $sriovNum = 1
}

if ($null -eq $mtuChange) {
    $mtuChange = $false
}
else {
    $mtuChange = [System.Convert]::ToBoolean($mtuChange)
}

# Source the tcutils.ps1 file
. .\setupscripts\tcutils.ps1

PowerCLIImport
ConnectToVIServer $env:ENVVISIPADDR `
    $env:ENVVISUSERNAME `
    $env:ENVVISPASSWORD `
    $env:ENVVISPROTOCOL


########################################################################################
# Main Body
########################################################################################


$retVal = $Failed


# Check host version
$skip = SkipTestInHost $hvServer "6.0.0","6.5.0","6.7.0"
if($skip)
{
    return $Skipped
}


# Disable memory reserve
LogPrint "INFO: Disable memory reserver before add a SRIOV"
DisableMemoryReserve $vmName $hvServer
# HERE. NO checking of action


# Add a new sriov nic
for ($i = 0; $i -lt $sriovNum; $i++) {
    $status = AddSrIOVNIC $vmName $hvServer $mtuChange
    LogPrint "DEBUG: status: $status"
    if (-not $status[-1]) {
        LogPrint "INFO: Disable memory reserver after add a SRIOV failed"
        DisableMemoryReserve $vmName $hvServer
        # HERE. NO checking of action
        
        return $Failed
    }
}


$retVal = $Passed
return $retVal