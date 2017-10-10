###############################################################################
##
## Description:
## Check Host and Guest time sync after suspend
##
###############################################################################
##
## Revision:
## V1.0 - ldu - 10/10/2017 - Build script
##
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
# Confirm the VM power state is PoweredOn
#
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
$state = $vmObj.PowerState
if ($state -ne "PoweredOn")
{
    Write-Error -Message "ABORTED: $vmObj is not poweredOn, power state is $state" -Category ObjectNotFound -ErrorAction SilentlyContinue
    return $Aborted
}
Write-Host -F Red "DONE. VM Power state is $state"
Write-Output "DONE. VM Power state is $state"

#
# Enable timesync
#
$enable = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "vmware-toolbox-cmd timesync enable"
if ($enable -ne "Enabled")
{
    Write-Error -Message "timesync enable failed" -Category ObjectNotFound -ErrorAction SilentlyContinue
    return $Aborted
}

#
# Suspend the VM and confirm the power state
#
Write-Host -F Red "Now, will Suspend the VM......."
Write-Output "Now, will Suspend the VM......."
$suspend = Suspend-VM -VM $vmObj -Confirm:$False
Start-Sleep -S 60
# Get the new VM
$vmObjSuspend = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
$suspendState = $vmObjSuspend.PowerState
if ($suspendState -ne "Suspended")
{
    Write-Error -Message "ABORTED: $vmObj is not Suspended, power state is $suspendState" -Category ObjectNotFound -ErrorAction SilentlyContinue
    return $Aborted
}
else
{
    Start-Sleep 120
}
Write-Host -F Red "DONE. VM Power state is $suspendState......."
Write-Output "DONE. VM Power state is $suspendState"

#
# Power the VM, and confirm the power state
#
write-host -F Red "Now, will Power On the VM......."
Write-Output "Now, will Power On the VM"
$on = Start-VM -VM $vmObj -Confirm:$False
# Debug below function
$timeBefore = Get-Date
Write-Host -F Red "$timeBefore"
$ret = WaitForVMSSHReady $vmName $hvServer ${sshKey} 300
if ( $ret -eq $true )
{
    $timeAfter = Get-Date
    Write-Host -F Red "$timeAfter"
    $debug = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
    $debugState = $debug.PowerState
    write-host -F Red "vm status starts up, state is $debugState"
}
else
{
    $timeAfter = Get-Date
    Write-Host -F Red "$timeAfter"
    $debug = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
    $debugState = $debug.PowerState
    write-host -F Red "vm status starts up, state is $debugState"
    return $Aborted
}

# Get the new VM
$vmObjOn = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
$onState = $vmObjOn.PowerState
if ($onState -ne "PoweredOn")
{
    Write-Error -Message "ABORTED: $vmObj is not poweredOn, power state is $state" -Category ObjectNotFound -ErrorAction SilentlyContinue
    return $Aborted
}

#
# Execute the remote script to check the time sync after suspend
#
$result = SendCommandToVM $ipv4 $sshKey "cd /root && dos2unix ovt_check_suspend_timesync.sh && chmod u+x ovt_check_suspend_timesync.sh && ./ovt_check_suspend_timesync.sh"
if (-not $result)
{
	Write-Output "FAIL: Failed to execute ovt_check_suspend_timesync.sh in VM."
}
else
{
    $retVal = $Passed
}

DisconnectWithVIServer

return $retVal