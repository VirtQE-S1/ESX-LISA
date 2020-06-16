########################################################################################
## Description:
## Uninstall open-vm-tools-sdmp package and check the serviceDiscovery plugin gets removed
##
## Revision:
##  v1.0.0 - ldu - 06/11/2020 - Build the script
## 
########################################################################################


<#
.Synopsis
  Uninstall open-vm-tools-sdmp package and check the serviceDiscovery plugin gets removed
.Description

<test>
        <testName>ovt_uninstall_sdmp</testName>
        <testID>ESX-OVT-049</testID>
        <testScript>testscripts/ovt_uninstall_sdmp.ps1</testScript  >
        <files>remote-scripts/utils.sh</files>
        <testParams>
            <param>TC_COVERED=RHEL6-0000,RHEL-188056</param>
        </testParams>
        <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
        <timeout>1800</timeout>
        <onError>Continue</onError>
        <noReboot>False</noReboot>
    </test>
    
.Parameter vmName
    Name of the test VM.

.Parameter testParams
    Semicolon separated list of test parameters.
#>


param([String] $vmName, [String] $hvServer, [String] $testParams)


# Checking the input arguments
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
        "sshKey" { $sshKey = $fields[1].Trim() }
        "rootDir" { $rootDir = $fields[1].Trim() }
        "ipv4" { $ipv4 = $fields[1].Trim() }
        default {}
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
    LogPrint "ERROR: Unable to Get-VM with ${vmName}."
    DisconnectWithVIServer
    return $Aborted
}

# Get the Guest version
$DISTRO = GetLinuxDistro ${ipv4} ${sshKey}
LogPrint "DEBUG: DISTRO: ${DISTRO}."
if (-not $DISTRO) {
    LogPrint "ERROR: Guest OS version is NULL."
    DisconnectWithVIServer
    return $Aborted
}
LogPrint "INFO: Guest OS version is ${DISTRO}."


#Check the ovt version, if version old then 11, not support this feature skip it.
$version = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "rpm -qa open-vm-tools" 
$ver_num = $($version.split("-"))[3]
LogPrint "DEBUG: version: ${version} and ver_num is $ver_num."
if ($ver_num -ge 11.1) {
    LogPrint "Info: The OVT version is $ver_num."
}
else
{
    LogPrint "Info: The OVT version is $ver_num."
    LogPrint "ERROR: The OVT version older then 11.1, not support sdmp."
    DisconnectWithVIServer
    return $Skipped
}

$Command = "yum install lsof -y"
$status = SendCommandToVM $ipv4 $sshkey $command
if (-not $status) {
    LogPrint "ERROR : Install lsof failed"
    $retVal = $Aborted
}
else {
    LogPrint "INFO: Install lsof passed"
}


$Command = "yum erase open-vm-tools-sdmp -y"
$status = SendCommandToVM $ipv4 $sshkey $command
if (-not $status) {
    LogPrint "ERROR : Uninstall open-vm-tools-sdmp failed"
    $retVal = $Aborted
}
else {
    LogPrint "INFO: Uninstall open-vm-tools-sdmp passed"
}


#Check the serviceDiscovery plugin installed and vmtoolsd service unloads after uninstall open-vm-tools-sdmp
$service = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "lsof -p ``pidof vmtoolsd`` | grep libserviceDiscovery"
if ($null -eq $service)
{
    $retVal = $Passed
    LogPrint "INFO: vmtoolsd service unloads serviceDiscovery plugin successfully."
    
}
else 
{
    LogPrint "ERROR : vmtoolsd service unloads serviceDiscovery plugin failed. $service"
}

DisconnectWithVIServer
return $retVal
