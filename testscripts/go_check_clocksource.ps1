###############################################################################
##
## Description:
##  Check the guest clocksource after boot up.
##
##
## Revision:
##  v1.0.0 - ldu - 05/20/2020 - Build Scripts
##
###############################################################################


<#
.Synopsis
go_check_clocksource

.Description
    <test>
        <testName>go_check_clocksource</testName>
        <testID>ESX-GO-30</testID>
        <testScript>testscripts/go_check_clocksource.ps1</testScript  >
        <files>remote-scripts/utils.sh</files>
        <testParams>
            <param>TC_COVERED=RHEL6-0000,RHEL-186410</param>
        </testParams>
        <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
        <timeout>600</timeout>
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


$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj)
{
    LogPrint "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
	return $Aborted
}

# Check clock source in the guest.
$clocksource = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "cat /sys/devices/system/clocksource/clocksource0/available_clocksource"
if ("$clocksource" -cmatch "tsc hpet acpi_pm")
{
    $retVal = $Passed
    LogPrint "INFO: After boot, the clocksource match the baseline $clocksource."
}
else
{
    LogPrint "ERROR: After boot, the guest clocksource not match the baseline, $clocksource"
    
}


DisconnectWithVIServer
return $retVal
