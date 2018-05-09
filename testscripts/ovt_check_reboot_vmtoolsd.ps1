###############################################################################
##
## Description:
##   Check service vmtoolsd status after reboot in vm
##   Return passed, case is passed; return failed, case is failed
##
###############################################################################
##
## Revision:
## v1.0 - ldu - 07/19/2017 - Check reboot in vm,Draft script for case ESX-OVT-012.
##
###############################################################################

<#
.Synopsis
    reboot in vm.

.Description
    Check reboot in vm.

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

$retVal = $Failed

#
# OVT is skipped in RHEL6
#
$OS = GetLinuxDistro  $ipv4 $sshKey
if ($OS -eq "RedHat6")
{
    DisconnectWithVIServer
    return $Skipped
}

$vmOut = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmOut)
{
    Write-Error -Message " Unable to create VM object for VM $vmName" -Category ObjectNotFound -ErrorAction SilentlyContinue
}
else
{
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} 'init 6'

    # Note: start sleep for few seconds to wait for vm to stop first
    Start-Sleep -seconds 6

    # wait for vm to Start
    $ret = WaitForVMSSHReady $vmName $hvServer ${sshKey} 300
    if ( $ret -eq $true )
    {
        $ret = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "systemctl status vmtoolsd |grep running"
        if ($ret -ne $null)
        {
            Write-Output "PASS: vm status is running."
            $retVal = $Passed
        }
        else
        {
            Write-Output "Failed: Failed to get vmtoolsd status from VM."
        }
    }
}

DisconnectWithVIServer
return $retVal

