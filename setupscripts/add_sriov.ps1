###############################################################################
##
## Description:
## Add sriov nic 
##
###############################################################################
##
## Revision:
## V1.0.0 - ruqin - 8/8/2018 - Build the script
##
###############################################################################
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


# Check host version
$hvHost = Get-VMHost -Name $hvServer
if ($hvHost.Version -lt "6.5.0") {
    LogPrint "WARN: vSphere which less than 6.5.0 is not support RDMA"
    return $Skipped
}


# disable memory reserve
DisableMemoryReserve $vmName $hvServer
# Use function to add new sriov nic
for ($i = 0; $i -lt $sriovNum; $i++) {
    $status = AddSrIOVNIC $vmName $hvServer $mtuChange
    if ( -not $status[-1] ) {
        # disable memory reserve
        DisableMemoryReserve $vmName $hvServer
        return $Failed
    }
}


$retVal = $Passed
return $retVal
