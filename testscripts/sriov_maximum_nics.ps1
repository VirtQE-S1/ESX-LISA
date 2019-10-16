########################################################################################\
## Description:
##  Add the MAX SR-IOV NICs in a Guest
##
## Revision:
##  v1.0.0 - ruqin - 8/9/2018 - Build the script
##  v1.1.0 - boyang - 10/16.2019 - Skip test when host hardware hasn't RDMA NIC.
########################################################################################


<#
.Synopsis
    Add the MAX SR-IOV NICs in a Guest

.Description
       <test>
            <testName>sriov_maximum_nics</testName>
            <testID>ESX-SRIOV-006</testID>
            <setupScript>
                <file>setupscripts\add_sriov.ps1</file>
            </setupScript>
            <cleanupScript>
                <file>setupscripts\disable_memory_reserve.ps1</file>
            </cleanupScript> 
            <testScript>testscripts\sriov_maximum_nics.ps1</testScript>
            <testParams>
                <param>TC_COVERED=RHEL-115200,RHEL6-49173</param>
                <param>mtuChange=False</param>
                <param>sriovNum=10</param>
            </testParams>
            <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
            <timeout>240</timeout>
            <onError>Continue</onError>
            <noReboot>False</noReboot>
        </test>

.Parameter vmName
    Name of the test VM.

.Parameter testParams
    Semicolon separated list of test parameters.
#>


param([String] $vmName, [String] $hvServer, [String] $testParams)


#
# Checking the input arguments
#
if (-not $vmName) {
    "Error: VM name cannot be null!"
    exit 100
}

if (-not $hvServer) {
    "Error: hvServer cannot be null!"
    exit 100
}

if (-not $testParams) {
    Throw "Error: No test parameters specified"
}


#
# Output test parameters so they are captured in log file
#
"TestParams : '${testParams}'"


#
# Parse the test parameters
#
$rootDir = $null
$sshKey = $null
$ipv4 = $null
$sriovNum = $null

$params = $testParams.Split(";")
foreach ($p in $params) {
    $fields = $p.Split("=")
    switch ($fields[0].Trim()) {
        "sshKey" { $sshKey = $fields[1].Trim() }
        "rootDir" { $rootDir = $fields[1].Trim() }
        "ipv4" { $ipv4 = $fields[1].Trim() }
        "sriovNum" { $sriovNum = $fields[1].Trim() }
        default {}
    }
}


#
# Check all parameters are valid
#
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

if ($null -eq $sshKey) {
    "FAIL: Test parameter sshKey was not specified"
    return $False
}

if ($null -eq $ipv4) {
    "FAIL: Test parameter ipv4 was not specified"
    return $False
}

if ($null -eq $sriovNum) {
   LogPrint "FAIL: SR-IOV NICs number is not specified" 
   return $False
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


########################################################################################
# Main Body
########################################################################################


$retVal = $Failed


$skip = SkipTestInHost $hvServer "6.0.0","6.5.0","6.7.0"
if($skip)
{
    return $Skipped
}


$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj) {
    LogPrint "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
    return $Aborted
}


# Get the Guest version
$DISTRO = GetLinuxDistro ${ipv4} ${sshKey}
LogPrint "DEBUG: DISTRO: $DISTRO"
if (-not $DISTRO) {
    LogPrint "ERROR: Guest OS version is NULL"
    DisconnectWithVIServer
    return $Aborted
}
LogPrint "INFO: Guest OS version is $DISTRO"


# Different Guest DISTRO
if ($DISTRO -ne "RedHat7" -and $DISTRO -ne "RedHat8" -and $DISTRO -ne "RedHat6") {
    LogPrint "ERROR: Guest OS ($DISTRO) isn't supported, MUST UPDATE in Framework / XML / Script"
    DisconnectWithVIServer
    return $Skipped
}


# Find out new add Sriov nic
$nics += @($(FindAllNewAddNIC $ipv4 $sshKey))
if ($null -eq $nics -or $nics.Count -ne $sriovNum) {
    LogPrint "ERROR: Cannot find all new add SR-IOV NIC" 
    DisconnectWithVIServer
    return $Failed
}


# Check Call Trace
$status = CheckCallTrace $ipv4 $sshKey
if ($null -eq $status -or -not $status[-1]) {
    LogPrint "ERROR: Failed on dmesg Call Trace"
    DisconnectWithVIServer
    return $Failed
}
else {
    $retVal = $Passed
}


DisconnectWithVIServer
return $retVal
