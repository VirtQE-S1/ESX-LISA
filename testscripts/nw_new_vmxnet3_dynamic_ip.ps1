########################################################################################
# Description:
#	Config new vmxnet3 dynamic_ip
#
# Revision:
# 	v1.0.0 - boyang - 01/18/2017 - Build script
# 	v1.0.1 - boyang - 04/02/2018 - Comment in Notice
# 	v1.0.2 - boyang - 04/03/2018 - Use $DISTRO to identify different operations
# 	v2.0.0 - ruqin  - 08/28/2018 - Use powershell instead of bash shell
########################################################################################


<#
.Synopsis
	Config new vmxnet3 dynamic_ip
.Description
	Config new vmxnet3 dynamic_ip
.Parameter vmName
    Name of the test VM.
.Parameter testParams
    Semicolon separated list of test parameters.
#>


# Checking the input arguments
param([String] $vmName, [String] $hvServer, [String] $testParams)
if (-not $vmName) {
    "ERROR: VM name cannot be null!"
    exit 100
}

if (-not $hvServer) {
    "ERROR: hvServer cannot be null!"
    exit 100
}

if (-not $testParams) {
    Throw "ERROR: No test parameters specified"
}


# Output test parameters so they are captured in log file
"TestParams : '${testParams}'"


# Parse the test parameters
$rootDir = $null
$sshKey = $null
$ipv4 = $null

$params = $testParams.Split(";")
foreach ($p in $params) {
    $fields = $p.Split("=")
    switch ($fields[0].Trim()) {
        "sshKey" 	{ $sshKey = $fields[1].Trim() }
        "rootDir" 	{ $rootDir = $fields[1].Trim() }
        "ipv4" 		{ $ipv4 = $fields[1].Trim() }
        default 	{}
    }
}


# Check all parameters are valid
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


$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj) {
    LogPrint "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
    return $Aborted
}


# Find new add vmxnet3 nic.
$nics += @($(FindAllNewAddNIC $ipv4 $sshKey))
LogPrint "DEBUG: nics: $nics."
if ($null -eq $nics) {
    LogPrint "ERROR: Cannot find new add NIC." 
    DisconnectWithVIServer
    return $Failed
}
else {
    $vmxnetNic = $nics[-1]
}
LogPrint "INFO: Found New NIC - ${vmxnetNic}."


# Config new NIC
$status = ConfigIPforNewDevice $ipv4 $sshKey $vmxnetNic
if ( $null -eq $status -or -not $status[-1]) {
    LogPrint "ERROR : Config IP Failed."
    DisconnectWithVIServer
    return $Failed
}
else {
    $retVal = $Passed
}
LogPrint "INFO: vmxnet3 NIC IP setup successfully."


DisconnectWithVIServer
return $retVal
