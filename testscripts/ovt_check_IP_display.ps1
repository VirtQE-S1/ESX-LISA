###############################################################################
##
## Description:
##   Check guest's IP address is display correctly on vCenter UI.
##   Return passed, case is passed; return failed, case is failed
##
###############################################################################
##
## Revision:
## v1.0 - ldu - 10/30/2017 - Check VM IP address,Draft script for case ESX-OVT-024.
## RHEL7-57929
##
###############################################################################

<#
.Synopsis
  Check guest's IP address is display correctly on vCenter UI.


.Description
<test>
    <testName>ovt_check_IP_display</testName>
    <testID>ESX-OVT-024</testID>
    <testScript>testscripts/ovt_check_IP_display.ps1</testScript>
    <files>remote-scripts/utils.sh</files>
    <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
    <testParams>
      <param>TC_COVERED=RHEL6-34917,RHEL7-57929</param>
    </testParams>
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

###############################################################################
#
# Main Body
#
###############################################################################

$retVal = $Failed

# OVT is skipped in RHEL6
$OS = GetLinuxDistro $ipv4 $sshKey
if ($OS -eq "RedHat6")
{
    DisconnectWithVIServer
    return $Skipped
}

#
# Get ip from vSphere UI
#
Start-Sleep -S 30
$get_IP = Get-VMHost -Name $hvServer | Get-VM -Name $vmName | Get-View | Select Name,@{Name="ip";Expression={$_.guest.ipAddress}}
$ipaddress=$get_IP.ip
write-host -F Red "IP address from UI is $ipaddress"
Write-Output "IP address from UI is $ipaddress"
if ($ipaddress -eq $ipv4)
{
    Write-Host -F Red "PASS: IP from UI is the same with IP from Guest OS"
    Write-Output "PASS: IP from UI is the same with IP from Guest OS"
    $retVal = $Passed
}
else
{
    Write-Host -F Red "FAIL: IP from UI isn't the same with IP from Guest OS"
    Write-Output "FAIL: IP from UI isn't the same with IP from Guest OS"
}

DisconnectWithVIServer
return $retVal

