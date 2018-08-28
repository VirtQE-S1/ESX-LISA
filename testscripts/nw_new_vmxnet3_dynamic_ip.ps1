###############################################################################
#
# Description:
#	Config new vmxnet3 dynamic_ip
#
# Revision:
# v1.0.0 - boyang - 01/18/2017 - Build script
# v1.0.1 - boyang - 04/02/2018 - Comment in Notice
# v1.0.2 - boyang - 04/03/2018 - Use $DISTRO to identify different operations
# V2.0.0 - ruqin  - 08/28/2018 - Use powershell instead of bash shell
#
###############################################################################



<#
.Synopsis
    Change the MTU of a SR-IOV

.Description

         <test>
            <testName>nw_new_vmxnet3_dynamic_ip</testName>
            <testID>ESX-NW-014</testID>
            <setupscript>setupscripts\add_vmxnet3.ps1</setupscript>
            <testScript>testscripts\nw_new_vmxnet3_dynamic_ip.ps1</testScript>
            <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
            <timeout>600</timeout>
            <testParams>
                <param>TC_COVERED=RHEL6-34942,RHEL7-50922</param>
            </testParams>
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

$params = $testParams.Split(";")
foreach ($p in $params) {
    $fields = $p.Split("=")
    switch ($fields[0].Trim()) {
        "sshKey" { $sshKey = $fields[1].Trim() }
        "rootDir" { $rootDir = $fields[1].Trim() }
        "ipv4" { $ipv4 = $fields[1].Trim() }
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


# Find new add vmxnet3 nic
$nics = FindAllNewAddNIC $ipv4 $sshKey
if ($null -eq $nics) {
    LogPrint "ERROR: Cannot find new add NIC" 
    DisconnectWithVIServer
    return $Failed
}
else {
    $vmxnetNic = $nics[-1]
}
LogPrint "INFO: New NIC is $vmxnetNic"


# Config new NIC
if ( -not (ConfigIPforNewDevice $ipv4 $sshKey $vmxnetNic)) {
    LogPrint "ERROR : Config IP Failed"
    DisconnectWithVIServer
    return $Failed
} else {
    $retVal = $Passed
}
LogPrint "INFO: vmxnet3 NIC IP setup successfully"


DisconnectWithVIServer
return $retVal
