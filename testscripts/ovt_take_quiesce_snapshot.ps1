###############################################################################
##
## Description:
## Take snapshot after restart service vmtoolsd.
##
###############################################################################
##
## Revision:
## V1.0 - ldu - 10/12/2017 - Take snapshot after restart service vmtoolsd.
## RHEL7-50878
###############################################################################

<#
.Synopsis
    Check Host and Guest time sync after suspend
.Description
    Check Host and Guest time sync after suspend
.Parameter vmName
    Name of the test VM.
.Parameter hvServer
    Name of the VIServer hosting the VM.
.Parameter testParams
    Semicolon separated list of test parameters.
#>

param([String] $vmName, [String] $hvServer, [String] $testParams)

#
# Checking the input arguments
#
if (-not $vmName)
{
    "FAIL: VM name cannot be null!"
    exit
}

if (-not $hvServer)
{
    "FAIL: hvServer cannot be null!"
    exit
}

if (-not $testParams)
{
    Throw "FAIL: No test parameters specified"
}

#
# Output test parameters so they are captured in log file
#
"TestParams : '${testParams}'"

#
# Parse test parameters
#
$rootDir = $null
$sshKey = $null
$ipv4 = $null
$logdir = $null

$params = $testParams.Split(";")
foreach ($p in $params)
{
	$fields = $p.Split("=")
	switch ($fields[0].Trim())
	{
		"rootDir"		{ $rootDir = $fields[1].Trim() }
		"sshKey"		{ $sshKey = $fields[1].Trim() }
		"ipv4"			{ $ipv4 = $fields[1].Trim() }
		"TestLogDir"	{ $logdir = $fields[1].Trim()}
		default			{}
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

if ($null -eq $sshKey)
{
	"FAIL: Test parameter sshKey was not specified"
	return $False
}

if ($null -eq $ipv4)
{
	"FAIL: Test parameter ipv4 was not specified"
	return $False
}

if ($null -eq $logdir)
{
	"FAIL: Test parameter logdir was not specified"
	return $False
}

#
# Source tcutils.ps1
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
# Get the VM 
#
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName

#
# Take snapshot and select quiesce option
#
$snapshotTargetName = "snapquiesce"
$new_sp = New-Snapshot -VM $vmObj -Name $snapshotTargetName -Quiesce:$true -Confirm:$false
$newSPName = $new_sp.Name
if ($new_sp)
{
    if ($newSPName -eq $snapshotTargetName)
    {
        Write-Host -F Red "The snapshot $newSPName with Quiesce is created successfully"
        Write-Output "The snapshot $newSPName with Quiesce is created successfully"
        $retVal = $Passed
    }
    else
    {
        Write-Output "The snapshot with Quiesce is created Failed"
    }
}

#
# Remove SP created
#
$remove = Remove-Snapshot -Snapshot $new_sp -RemoveChildren -Confirm:$false
$snapshots = Get-Snapshot -VM $vmObj -Name $new_sp
if ($snapshots -eq $null)
{
    Write-Host -F Red "The snapshot has been removed successfully"
    Write-Output "The snapshot has been removed successfully"
}
else
{
    Write-Host -F Red "The snapshot removed failed"
    Write-Output "The snapshot removed failed"
    return $Aborted
}

DisconnectWithVIServer

return $retVal

