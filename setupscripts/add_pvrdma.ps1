########################################################################################
## Description:
##  Add pvRDMA nic 
##
## Revision:
##  v1.0.0 - ruqin - 08/13/2018 - Build the script.
##  v1.1.0 - boyang - 10/16/2019 - Skip test in these hosts hw NO support.
########################################################################################


<#
.Synopsis
    Add sriov nic

.Description
    Add pvRDMA nic in setup phrase (one VM could only attach one pvRDMA nic)

.Parameter vmName
    Name of the test VM

.Parameter hvServer
    Name of the ESXi server hosting the VM.

.Parameter testParams
    Semicolon separated list of test parameters
#>


# Checking the input arguments
param([String] $vmName, [String] $hvServer, [String] $testParams)
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


# Check host version.
$skip = SkipTestInHost $hvServer "6.0.0"
if($skip)
{
    return $Skipped
}


# Use function to add new RDMA nic.
$status = AddPVrdmaNIC -vmName $vmName -hvServer $hvServer
if ( -not $status[-1] ) {
    return $retVal
}
else
{
    $retVal = $Passed
}
return $retVal
