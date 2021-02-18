########################################################################################
## Description:
##  Check modules in the VM
##
## Revision:
##  v1.0.0 - hhei - 01/06/2017 - Check modules in the VM.
##  v1.0.1 - hhei - 02/06/2017 - Remove TC_COVERED and update return value.
##  v1.0.2 - boyang - 05/10/2018 - Enhance the script and exit 100 if false.
##  v1.1.0 - boyang - 07/06/2018 - Change Passed Condition to Make sure all module pass.
########################################################################################


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


# Checking the input arguments
param([String] $vmName, [String] $hvServer, [String] $testParams)
if (-not $vmName)
{
    "ERROR: VM name cannot be null!"
    exit 100
}

if (-not $hvServer)
{
    "ERROR: hvServer cannot be null!"
    exit 100
}

if (-not $testParams)
{
    Throw "ERROR: No test parameters specified"
}


# Output test parameters so they are captured in log file
"TestParams : '${testParams}'"


# Parse the test parameters
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
    "rhel8_modules" { $rhel9_modules = $fields[1].Trim()}
    default        {}
    }
}


# Check all parameters are valid
if (-not $rootDir)
{
    "WARNING: no rootdir was specified"
}
else
{
    if ( (Test-Path -Path "${rootDir}") )
    {
        cd $rootDir
    }
    else
    {
        "WARNING: rootdir '${rootDir}' does not exist"
        exit 100
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
## Main Body
########################################################################################
$retVal = $Failed
$modules_array = ""


$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj)
{
    LogPrint "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
	return $Aborted
}


# Get the Guest version.
$DISTRO = GetLinuxDistro ${ipv4} ${sshKey}
LogPrint "INFO: Guest OS version is $DISTRO"
if ($null -eq $DISTRO)
{
    LogPrint "ERROR: Guest OS version is NULL"
    DisconnectWithVIServer
	return $Aborted
}


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
elseif ($DISTRO -eq "RedHat9")
{
    $modules_array = $rhel9_modules.split(",")
}
else
{
    LogPrint "ERROR: Guest OS ($DISTRO) isn't supported, MUST UPDATE in Framework / XML / Script."
    DisconnectWithVIServer
	return $Aborted
}


# Check the modules in current Guest OS
foreach ($m in $modules_array)
{
    $module = $m.Trim()
    LogPrint "DEBUG: module: $module"

    $ret = CheckModule $ipv4 $sshKey $module
    LogPrint "DEBUG: ret: $ret"	
    if ($ret -ne $true)
    {
        LogPrint "ERROR: The check of $module failed."
        DisconnectWithVIServer
        return $retVal
    }
    else
    {
        LogPrint "INFO: Complete the check of $module"
    }
}


# Set return value as $Passed as all moudles have been checked well.
$retVal = $Passed


DisconnectWithVIServer
return $retVal
