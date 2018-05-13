###############################################################################
##
## Description:
##  Check the VM could install on IDE disk. The framework installs two VMs
##  VM-A and VM-B, the VM-A is installed on scsi disk, another is installed on
##  IDE disk, if the script gets VM-B's IP, installation in IDE passes
##
## Revision:
##  v1.0.0 - ldu - 01/29/2018 - Build the script
##  v1.0.1 - boyang - 05/11/2018 - Enhance the script and exit 100 if false
##  v1.0.2 - boyang - 05/11/2018 - Enhance to avoid VM B to lost after boot
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
    "TestLogDir"   { $testLogDir = $fields[1].Trim() }
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


#
# The VM A and the VM B own the same part in names
# RHEL-7.4-20170711.0-x86_64-BIOS-A / RHEL-7.4-20170711.0-x86_64-BIOS-A
# RHEL-7.3-20161019.0-x86_64-EFI-A / RHEL-7.3-20161019.0-x86_64-EFI-B
#
$vmNameB = $vmName -replace "-A$","-B"
$vmObjectB = Get-VMHost -Name $hvServer | Get-VM -Name $vmNameB
if (-not $vmObjectB)
{
    Write-Host -F Red "ERROR: Unable to Get-VM with $vmNameB"
    Write-Output "ERROR: Unable to Get-VM with $vmNameB"
    DisconnectWithVIServer
	return $Aborted
}


# Confirm the VM B power state
$vmObjectBPowerState = $vmObjectB.PowerState
# Boot vmObjectB if its power state isn't PoweredOn and get its IP
if ($vmObjectBPowerState -ne "PoweredOn")
{
    Write-Host -F Red "INFO: Start to power on VM $vmObjectB"
    Write-Output "INFO: Start to power on VM $vmObjectB"
    $vmObjectBOn = Start-VM -VM $vmObjectB -Confirm:$False

    $timeout = 360
    while ($timeout -gt 0)
    {
        $vmTemp = Get-VMHost -Name $hvServer | Get-VM -Name $vmNameB
        if (-not $vmTemp)
        {
            Write-Host -F Red "ERROR: After start VM $vmTemp, lost it"
            Write-Output "ERROR: After start VM $vmTemp, lost it"
            DisconnectWithVIServer
        	return $Aborted
        }

        $vmTempPowerState = $vmTemp.PowerState
        if ($vmTempPowerState -eq "PoweredOn")
        {
            $ipv4B = GetIPv4 $vmNameB $hvServer
            if ($ipv4B -ne $null)
            {
                Write-Host -F Red "INFO: The VM B ipv4 is $ipv4B"
                Write-Output "INFO: The VM B ipv4 is $ipv4B"
                $vmObjectBOff = Stop-VM -VM $vmObjectB -Confirm:$False
                $retVal = $Passed
                break
            }
            else
            {
                Write-Host -F Red "WARNING: Can't get VMB's ipv4, try again"
                Write-Output "WARNING: Can't get VMB's ipv4, try again"
            }
        }

        # Can't power on VM B during 300
        Start-Sleep -S 6
        $timeout = $timeout - 6
        if ($timeout -eq 0)
        {
            Write-Host -F Red "ERROR: Timeout, and power off the VM B"
            Write-Output "ERROR: Timeout, and power off the VM B"
            $vmObjectBOff = Stop-VM -VM $vmObjectB -Confirm:$False
            DisconnectWithVIServer
            return $Aborted
        }
    }
}
else
{
    # VM B is PoweredOn, maybe IP is not ready
    $timeout = 60
    while ($timeout -gt 0)
    {
        $ipv4B = GetIPv4 $vmNameB $hvServer
        if ($ipv4B -eq $null)
        {
            Write-Host -F Red "WARNING: can't get VMB's ipv4, try again"
            Write-Output "WARNING: can't get VMB's ipv4, try again"
        }
        else
        {
            Write-Host -F "PASS: Complete to get VMB IP($ipv4B), will power off the VM B"
            Write-Output "PASS: Complete to get VMB IP($ipv4B), will power off the VM B"
            $vmObjectBOff = Stop-VM -VM $vmObjectB -Confirm:$False
            $retVal = $Passed
            break
        }

        Start-Sleep -S 6
        $timeout = $timeout - 6
        if ($timeout -eq 0)
        {
            Write-Host -F Red "FAIL: Timeout, and power off the VM B"
            Write-Output "FAIL: Timeout, and power off the VM B"
            $vmObjectBOff = Stop-VM -VM $vmObjectB -Confirm:$False
        }
    }
}


DisconnectWithVIServer
return $retVal
