###############################################################################
##
## Description:
##   Check modules in vm
##   Return passed, case is passed; return failed, case is failed
##
###############################################################################
##
## Revision:
## v1.0 - hhei - 1/6/2017 - Check modules in vm.
## v1.1 - hhei - 2/6/2017 - Remove TC_COVERED and update return value
##                          true is changed to passed,
##                          false is changed to failed.
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
    exit
}

if (-not $hvServer)
{
    "Error: hvServer cannot be null!"
    exit
}

if (-not $testParams)
{
    Throw "Error: No test parameters specified"
}

#
# Display the test parameters so they are captured in the log file
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
    default        {}
    }
}

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

$Result = $Failed
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj)
{
    Write-Error -Message "CheckModules: Unable to create VM object for VM $vmName" -Category ObjectNotFound -ErrorAction SilentlyContinue
}
else
{
    # Get guest version
    $DISTRO = ""
    $modules_array = ""
    $DISTRO = GetLinuxDistro ${ipv4} ${sshKey}
    if ( -not $DISTRO )
    {
        "Error : Guest OS version is NULL"
        $Result = $Failed
    }
    elseif ( $DISTRO -eq "RedHat6" )
    {
        $modules_array = $rhel6_modules.split(",")
        $Result = $Passed
    }
    elseif ( $DISTRO -eq "RedHat7" )
    {
        $modules_array = $rhel7_modules.split(",")
        $Result = $Passed
    }
    else
    {
        "Error : Guest OS version is $DISTRO"
        $Result = $Failed
    }

    "Info : Guest OS version is $DISTRO"

    if ( $Result -eq $Passed )
    {
        foreach ( $m in $modules_array )
        {
            $module = $m.Trim()
            $r = CheckModule $ipv4 $sshKey $module
            if ( $r -eq $true )
            {
                "Info : Check module '$module' successfully"
            }
            else
            {
                "Error : Check module '$module' failed"
                $Result = $Failed
            }
        }
    }
}

"Info : go_check_modules.ps1 script completed"
DisconnectWithVIServer
return $Result
