###############################################################################
##
## Description:
##  Check modules in the VM
##
## Revision:
##  v1.0.0 - hhei - 1/6/2017 - Check modules in the VM
##  v1.0.1 - hhei - 2/6/2017 - Remove TC_COVERED and update return value
##  v1.0.2 - boyang - 05/10/2018 - Enhance the script and exit 100 if false
##  v1.1.0 - ruqin - 7/6/2018 - Change Passed Condition Make sure all module pass and then test passes
##
###############################################################################


<#
.Synopsis
    Demo script ONLY for test script.

.Description
    A demo for Powershell script as test script.

.Parameter vmName
    Name of the test VM.

.Parameter testParams
    Semicolon separated list of test parameters.
#>


param([String] $vmName, [String] $hvServer, [String] $testParams)


#
# Checking the input arguments
#
if (-not $vmName)
{
    "Error: VM name cannot be null!"
    exit 100
}

if (-not $hvServer)
{
    "Error: hvServer cannot be null!"
    exit 100
}

if (-not $testParams)
{
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
foreach ($p in $params)
{
    $fields = $p.Split("=")
    switch ($fields[0].Trim())
    {
    "sshKey"       { $sshKey = $fields[1].Trim() }
    "rootDir"      { $rootDir = $fields[1].Trim() }
    "ipv4"         { $ipv4 = $fields[1].Trim() }
    "rhel6_modules" { $rhel6_modules = $fields[1].Trim()}
    "rhel7_modules" { $rhel7_modules = $fields[1].Trim()}
    "rhel8_modules" { $rhel8_modules = $fields[1].Trim()}
    default        {}
    }
}


#
# Check all parameters are valid
#
if (-not $rootDir)
{
    "Warn : no rootdir was specified"
}
else
{
    if ( (Test-Path -Path "${rootDir}") )
    {
        cd $rootDir
    }
    else
    {
        "Warn : rootdir '${rootDir}' does not exist"
        exit 100
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
if (-not $vmObj)
{
    Write-Host -F Red "ERROR: Unable to Get-VM with $vmName"
    Write-Output "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
	return $Aborted
}


# Get the Guest version
$DISTRO = GetLinuxDistro ${ipv4} ${sshKey}
Write-Host -F Red "DEBUG: DISTRO: $DISTRO"
Write-Output "DEBUG: DISTRO: $DISTRO"
if (-not $DISTRO)
{
    Write-Host -F Red "ERROR: Guest OS version is NULL"
    Write-Output "ERROR: Guest OS version is NULL"
    DisconnectWithVIServer
	return $Aborted
}
Write-Host -F Red "INFO: Guest OS version is $DISTRO"
Write-Output "INFO: Guest OS version is $DISTRO"


# Different Guest DISTRO, different modules
if ($DISTRO -eq "RedHat6")
{
    $modules_array = $rhel6_modules.split(",")
}
elseif ($DISTRO -eq "RedHat7")
{
    $modules_array = $rhel7_modules.split(",")
}
elseif ($DISTRO -eq "RedHat8")
{
    $modules_array = $rhel8_modules.split(",")
}
else
{
    Write-Host -F Red "ERROR: Guest OS ($DISTRO) isn't supported, MUST UPDATE in Framework / XML / Script"
    Write-Output "ERROR: Guest OS ($DISTRO) isn't supported, MUST UPDATE in Framework / XML / Script"
    DisconnectWithVIServer
	return $Aborted
}


# Check the modules in current Guest OS
foreach ($m in $modules_array)
{
    $module = $m.Trim()
    Write-Host -F Red "DEBUG: go_check_modules.ps1: module: $module"
    Write-Output "DEBUG: go_check_modules.ps1: module: $module"

    $ret = CheckModule $ipv4 $sshKey $module
    if ($ret -ne $true)
    {
        Write-Host -F Red "FAIL: The check of $module failed"
        Write-Output "FAIL: The check of $module failed"
        DisconnectWithVIServer
        return $retVal
    }
    else
    {
        Write-Host -F Red "PASS: Complete the check of $module"
        Write-Output "PASS: Complete the check of $module"
    }
    $retVal = $Passed
}


DisconnectWithVIServer
return $retVal
