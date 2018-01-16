###############################################################################
##
## Description:
##   Check vm, because vm is already installed by iso, so only check vm exists
##   and disklength is equal with 1.
##
###############################################################################
##
## Revision:
## v1.0 - ldu - 12/28/2017 - Check vm installed with scsi disk.
## RHEL7-50908
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
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
$diskLength = (Get-HardDisk -VM $vmObj).Length

if ($diskLength -eq 1)
{
    Write-Host -F Red "The disklength is $diskLength"
    Write-Output "DONE: Install guest with scsi disk successfully!"
    $retVal = $Passed
}
else
{
    Write-Host -F Red "The disklength is $diskLength"
    Write-Output "FAIL:Install guest with scsi disk failed!"
}

DisconnectWithVIServer
return $retVal
