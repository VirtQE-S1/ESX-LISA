###############################################################################
##
## Description:
##   Check the VM could install on IDE disk.Now the Auto framework will install
##   two vm VMA and VMB, the VMA is installed on scsi disk, and VMB is installed on
##   IDE disk, this script will get VMB's IP to check the installation is successfully.
##
###############################################################################
##
## Revision:
## v1.0 - ldu - 01/29/2018 - Build the script
##
###############################################################################
<#-
.Synopsis
    Check the VM could install on IDE disk.
.Description
<test>
    <testName>go_install_ide_disk</testName>
    <testID>ESX-GO-011</testID>
    <testScript>testscripts/go_install_ide_disk.ps1</testScript>
    <files>remote-scripts/utils.sh</files>
    <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
    <timeout>600</timeout>
    <testparams>
        <param>TC_COVERED=RHEL6-34880,RHEL7-79776</param>
    </testparams>
    <onError>Continue</onError>
</test>
.Parameter vmName
    Name of the VM to add disk.

.Parameter hvServer
    Name of the ESXi server hosting the VM.

.Parameter testParams
    Test data for this test case
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
    "TestLogDir"   { $testLogDir = $fields[1].Trim() }
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

#
# The VM A and the VM B own the same part in names
# RHEL-7.4-20170711.0-x86_64-BIOS-A / RHEL-7.4-20170711.0-x86_64-BIOS-A
# RHEL-7.3-20161019.0-x86_64-EFI-A / RHEL-7.3-20161019.0-x86_64-EFI-B
#
$vmNameB = $vmName -replace "-A$","-B"
$vmObjectB = Get-VMHost -Name $hvServer | Get-VM -Name $vmNameB
Write-Host -F Gray "The VM B is $vmObjectB"
Write-Output "The VM B is $vmObjectB"

# Confirm the VM B power state
$vmObjectBPowerState = $vmObjectB.PowerState
Write-Host -F Gray "The VM B power state is $vmObjectBPowerState"
Write-Output "The VM B power state is $vmObjectBPowerState"
# Boot vmObjectB if its power state isn't PoweredOn and get its IP
if ($vmObjectBPowerState -ne "PoweredOn")
{
    Write-Host -F Gray "Start to power on VM $vmObjectB"
    Write-Output "Start to power on VM $vmObjectB"
    $vmObjectBOn = Start-VM -VM $vmObjectB -Confirm:$False
    $timeout = 360
    while ($timeout -gt 0)
    {
        $vmTemp = Get-VMHost -Name $hvServer | Get-VM -Name $vmNameB
        $vmTempPowerState = $vmTemp.PowerState
        Write-Host -F Gray "The VM B power state is $vmTempPowerState"
        Write-Output "The VM B power state is $vmTempPowerState"
        if ($vmTempPowerState -eq "PoweredOn")
        {
            $ipv4B = GetIPv4 $vmNameB $hvServer
            Write-Host -F Gray "The VM B ipv4 is $ipv4B"
            Write-Output "The VM B ipv4 is $ipv4B"

            if ($ipv4B -ne $null)
            {
                $retVal = $Passed
                $vmObjectBOff = Stop-VM -VM $vmObjectB -Confirm:$False
                break
            }
        }
        Start-Sleep -S 6
        $timeout = $timeout - 6
        if ($timeout -eq 0)
        {
            Write-Host -F Yellow "WARNING: Timeout, and power off the VM B"
            Write-Output "WARNING: Timeout, and power off the VM B"
            $vmObjectBOff = Stop-VM -VM $vmObjectB -Confirm:$False
            return $Aborted
        }
    }
}
# If its power state is PoweredOn, get its IP
else
{
    $ipv4B = GetIPv4 $vmNameB $hvServer
    Write-Host -F Gray "The VM B ipv4 is $ipv4B"
    Write-Output "The VM B ipv4 is $ipv4B"
    if ($ipv4B -eq $null)
    {
        Write-Host -F Yellow "WARNING: can't get VMB's ipv4, abort. And powered off the VM B"
        Write-Output "WARNING: can't get VMB's ipv4, abort. And powered off the VM B"
        $vmObjectBOff = Stop-VM -VM $vmObjectB -Confirm:$False
        return $Aborted
    }
    else
    {
        $retVal = $Passed
        Write-Host -F "Get VMB IP successfully,power off the VMB"
        Write-Output "Get VMB IP successfully,power off the VMB"
        $vmObjectBOff = Stop-VM -VM $vmObjectB -Confirm:$False
    }
}

DisconnectWithVIServer
return $retVal
