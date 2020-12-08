########################################################################################
##	Description:
##		Check vscock modules version in the VM.
##
##	Revision:
##		v1.0.0 - ruqin - 07/06/2018 - Build the script.
##		v2.0.0 - boyang - 12/08/2020 - Support RHEL-9.0.0.
########################################################################################


<#
.Synopsis
    Demo script ONLY for test script.
.Description
    Demo script ONLY for test script.
.Parameter vmName
    Name of the test VM.
.Parameter testParams
    Semicolon separated list of test parameters.
#>


# Checking the input arguments.
param([String] $vmName, [String] $hvServer, [String] $testParams)
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
        "rhel7_version" { $rhel7_version = $fields[1].Trim()}
        "rhel8_version" { $rhel8_version = $fields[1].Trim()}
        "rhel9_version" { $rhel9_version = $fields[1].Trim()}
        default {}
    }
}


# Check all parameters are valid.
if (-not $rootDir) {
    "WARNING: no rootdir was specified"
}
else {
    if ( (Test-Path -Path "${rootDir}") ) {
        cd $rootDir
    }
    else {
        "WARNING: rootdir '${rootDir}' does not exist"
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
$modules_array = ""


$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj) {
    LogPrint "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
    return $Aborted
}


# Get the Guest version.
$DISTRO = GetLinuxDistro ${ipv4} ${sshKey}
LogPrint "DEBUG: DISTRO: $DISTRO"
if (-not $DISTRO) {
    LogpPrint "ERROR: Guest OS version is NULL"
    DisconnectWithVIServer
    return $Aborted
}
LogpPrint "INFO: Guest OS version is $DISTRO"


# Different Guest DISTRO, different modules
if ($DISTRO -eq "RedHat6") {
    LogpPrint "INFO: RHEL6 is not supported"
    DisconnectWithVIServer
    return $Skipped
}
elseif ($DISTRO -eq "RedHat7") {
    $modules_array = $rhel7_version.split(",")
}
elseif ($DISTRO -eq "RedHat8") {
    $modules_array = $rhel8_version.split(",")
}
elseif ($DISTRO -eq "RedHat9") {
    $modules_array = $rhel9_version.split(",")
}
else {
    LogpPrint "ERROR: Guest OS ($DISTRO) isn't supported, MUST UPDATE in Framework / XML / Script"
    DisconnectWithVIServer
    return $Aborted
}


# Check the modules version in current Guest OS.
$modules = "vsock", "vmw_vmci", "vmw_vsock_vmci_transport"
$count = 0

foreach ($m in $modules) {
    $module = $m.Trim()
    $ret = CheckModule $ipv4 $sshKey $module
    if ($ret -eq $true) {
        $version = GetModuleVersion $ipv4 $sshKey $module
        if ([version]$version.Split('-')[0] -ge [version]$modules_array[$count].Trim().Split('-')[0]) {
            LogpPrint "PASS: Complete the check version of $($module) $version"
        }
        else {
            LogpPrint "FAIL: The check version of $($module) $version failed"
            $retVal = $Failed
            return $retVal
        }
    } else {
        LogpPrint "FAIL: The check of $($module) $version failed"
        $retVal = $Failed
        return $retVal
    }
    $count += 1
    $retVal = $Passed
}


DisconnectWithVIServer
return $retVal
