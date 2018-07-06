###############################################################################
##
## Description:
##  Check vscock modules version in the VM
##
## Revision:
##  v1.0.0 - ruqin - 7/6/2018 - Build the script
##
###############################################################################

<#
.Synopsis
    Demo script ONLY for test script.

.Description
   <test>
            <testName>vsock_version</testName>
            <testID>ESX-VSOCK-001</testID>
            <testScript>testscripts\vsock_check_version.ps1</testScript>
            <testParams>
                <param>rhel7_version=1.0.2.0-k,1.1.4.0-k,1.0.4.0-k</param>
                <param>rhel8_version=1.0.2.0-k,1.1.4.0-k,1.0.4.0-k</param>
                <param>TC_COVERED=RHEL-111195</param>
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
        "rhel7_version" { $rhel7_version = $fields[1].Trim()}
        "rhel8_version" { $rhel8_version = $fields[1].Trim()}
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
        cd $rootDir
    }
    else {
        "Warn : rootdir '${rootDir}' does not exist"
    }
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
$modules_array = ""



$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj) {
    Write-Host -F Red "ERROR: Unable to Get-VM with $vmName"
    Write-Output "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
    return $Aborted
}


# Get the Guest version
$DISTRO = GetLinuxDistro ${ipv4} ${sshKey}
Write-Host -F Red "DEBUG: DISTRO: $DISTRO"
Write-Output "DEBUG: DISTRO: $DISTRO"
if (-not $DISTRO) {
    Write-Host -F Red "ERROR: Guest OS version is NULL"
    Write-Output "ERROR: Guest OS version is NULL"
    DisconnectWithVIServer
    return $Aborted
}
Write-Host -F Red "INFO: Guest OS version is $DISTRO"
Write-Output "INFO: Guest OS version is $DISTRO"


# Different Guest DISTRO, different modules
if ($DISTRO -eq "RedHat6") {
    Write-Host -F Red "INFO: RHEL6 is not supported"
    Write-Output "INFO: RHEL6 is not supported"
    DisconnectWithVIServer
    return $Skipped
}
elseif ($DISTRO -eq "RedHat7") {
    $modules_array = $rhel7_version.split(",")
}
elseif ($DISTRO -eq "RedHat8") {
    $modules_array = $rhel8_version.split(",")
}
else {
    Write-Host -F Red "ERROR: Guest OS ($DISTRO) isn't supported, MUST UPDATE in Framework / XML / Script"
    Write-Output "ERROR: Guest OS ($DISTRO) isn't supported, MUST UPDATE in Framework / XML / Script"
    DisconnectWithVIServer
    return $Aborted
}


# Check the modules version in current Guest OS
$modules = "vsock", "vmw_vmci", "vmw_vsock_vmci_transport"

$count = 0

foreach ($m in $modules) {
    
    $module = $m.Trim()
    $ret = CheckModule $ipv4 $sshKey $module
    if ($ret -eq $true) {
        $version = GetModuleVersion $ipv4 $sshKey $module
        if ([version]$version.Split('-')[0] -ge [version]$modules_array[$count].Trim().Split('-')[0]) {

            Write-Host -F Red "PASS: Complete the check version of $($module) $version"
            Write-Output "PASS: Complete the check version of $($module) $version"
        }
        else {

            Write-Host -F Red "FAIL: The check version of $($module) $version failed"
            Write-Output "FAIL: The check version of $($module) $version failed"
            $retVal = $Failed
            return $retVal

        }
    } else {

        Write-Host -F Red "FAIL: The check of $($module) $version failed"
        Write-Output "FAIL: The check of $($module) $version failed"
        $retVal = $Failed
        return $retVal

    }
    $count += 1
    $retVal = $Passed
}


DisconnectWithVIServer
return $retVal
