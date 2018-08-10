###############################################################################
##
## Description:
##  Boot a Guest with SR-IOV NIC and check SR-IOV NIC
##
## Revision:
##  v1.0.0 - ruqin - 8/9/2018 - Build the script
##
###############################################################################


<#
.Synopsis
    Check NIC name after unload and load vmxnet3

.Description
       <test>
            <testName>sriov_boot_check</testName>
            <testID>ESX-SRIOV-001</testID>
            <setupScript>
                <file>setupscripts\add_sriov.ps1</file>
            </setupScript>
            <testScript>testscripts\sriov_boot_check.ps1</testScript>
            <testParams>
                <param>TC_COVERED=RHEL-113876</param>
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

# Get Old Adapter Name of VM
$Command = "ip a|grep `$(echo `$SSH_CONNECTION| awk '{print `$3}')| awk '{print `$(NF)}'"
$Old_Adapter = Write-Output y | bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command

if ( $null -eq $Old_Adapter) {
    LogPrint "ERROR : Cannot get Server_Adapter from first adapter"
    DisconnectWithVIServer
    return $Aborted
}

# Get sriov nic
$Command = "ls /sys/class/net | grep e | grep -v $Old_Adapter | awk 'NR==1'"
$sriovNIC = Write-Output y | bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command
if ( $null -eq $sriovNIC) {
    LogPrint "ERROR : Cannot get sriovNIC from guest"
    DisconnectWithVIServer
    return $Aborted
}

# Get sriov nic driver 
$Command = "ethtool -i $sriovNIC | grep driver | awk '{print `$2}'"
$driver = Write-Output y | bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command
# mellanox 40G driver and intel 40G NIC maybe different
if ($driver -ne "ixgbevf") {
    LogPrint "ERROR : Sriov driver Error or unsupported driver"
    DisconnectWithVIServer
    return $Aborted 
}
else
{
    $retVal = $Passed
}

DisconnectWithVIServer
return $retVal

