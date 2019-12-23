########################################################################################
## Description:
##  Boot guest with no pvrdma NIC, then add pvrdma NIC to the guest
##
## Revision:
##  v1.0.0 - ruqin - 8/16/2018 - Build the script.
##  v1.1.0 - boyang - 10/16.2019 - Skip test when host hardware hasn't RDMA NIC.
########################################################################################


<#
.Synopsis
    Boot guest with no pvrdma NIC, then add pvrdma NIC to the guest

.Description
       <test>
            <testName>rdma_hot_add_nic</testName>
            <testID>ESX-RDMA-003</testID>
            <testScript>testscripts\rdma_hot_add_nic.ps1</testScript>
            <testParams>
                <param>TC_COVERED=RHEL-111934</param>
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


$skip = SkipTestInHost $hvServer "6.0.0"
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


# Check host version
$hvHost = Get-VMHost -Name $hvServer
if ($hvHost.Version -lt "6.5.0") {
    LogPrint "WARN: vSphere which less than 6.5.0 is not support RDMA"
    return $Skipped
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


# Hot add RDMA nic
$status = AddPVrdmaNIC $vmName $hvServer
if (-not $status) {
    LogPrint "ERROR: Hot add RDMA nic failed"
    DisconnectWithVIServer
    return $Failed
}


# Find out new add RDMA nic
$nics += @($(FindAllNewAddNIC $ipv4 $sshKey))
Write-Output "DEBUG: nics: ${nics}."
Write-Host -F Red "DEBUG: nics: ${nics}."
if ($null -eq $nics) {
    LogPrint "ERROR: Cannot find new add RDMA NIC." 
    DisconnectWithVIServer
    return $Failed
}
else {
    $rdmaNIC = $nics[-1]
}
LogPrint "INFO: Found the new NIC - ${rdmaNIC}."


# Assign a new IP addr to new RDMA nic
$IPAddr = "172.31.1." + (Get-Random -Maximum 254 -Minimum 2)
if ( -not (ConfigIPforNewDevice $ipv4 $sshKey $rdmaNIC ($IPAddr + "/24"))) {
    LogPrint "ERROR : Config IP Failed maybe IP address conflit."
    DisconnectWithVIServer
    return $Failed
}


# Check new IP is reachable
$Command = "ping $IPAddr -c 10 -W 15  | grep ttl > /dev/null"
$status = SendCommandToVM $ipv4 $sshkey $command
if (-not $status) {
    LogPrint "ERROR : Ping test Failed."
    DisconnectWithVIServer
    return $Failed
}
else {
    $retVal = $Passed
}


DisconnectWithVIServer
return $retVal
