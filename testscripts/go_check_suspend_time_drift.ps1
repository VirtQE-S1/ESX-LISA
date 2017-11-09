###############################################################################
##
## Description:
## Check Guest time drift after suspend
##
###############################################################################
##
## Revision:
## V1.0 - boyang - 08/11/2017 - Build the script
##
###############################################################################

<#
.Synopsis
    Check Guest time drift after suspend
.Description
    Check Guest time drift after suspend
    
    <test>
    <testName>go_check_suspend_time_drift</testName>
    <testID>ESX-GO-010</testID>                   
    <testScript>testscripts\go_check_suspend_time_drift.ps1</testScript>
    <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
    <timeout>480</timeout>
    <testParams>                           
        <param>TC_COVERED=RHEL6-38514,RHEL7-80223</param>
    </testParams>
    <onError>Continue</onError>
    <noReboot>False</noReboot>
    </test>
    
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
# Target offset as 1 sec, after ntpdate, offset should be less than $minOffset
$minOffset = 1

# Confirm the VM power state is PoweredOn
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
# Stop time rysnc service with different methods for RHEL 6 or RHEL7 / RHEL8 
#
$linuxOS = GetLinuxDistro $ipv4 $sshKey
if ($linuxOS -eq "RedHat6")
{
    $ntpdDisable = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "service ntpd stop"
    $ntpdStatus = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "service ntpd status"
    Write-Host -F Red "ntpdstatus is $ntpdStatus"
    if ($ntpdStatus -ne "ntpd is stopped")
    {
        Write-Error -Message "ntpd disable failed" -Category ObjectNotFound -ErrorAction SilentlyContinue
        return $Aborted
    }
}
else
{
    $ntpdStop = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "systemctl stop ntpd"
    $ntpdDisable = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "systemctl disable ntpd"
	$result = SendCommandToVM $ipv4 $sshKey "systemctl status ntpd | grep running"
    Write-Host -F Red "result is $result"
    if ($result -ne $False)
    {
        Write-Error -Message "ntpd disable failed" -Category ObjectNotFound -ErrorAction SilentlyContinue
        return $Aborted
    }
    
    $ntpdStop = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "systemctl stop chronyd"
    $ntpdDisable = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "systemctl disable chronyd"
	$result = SendCommandToVM $ipv4 $sshKey "systemctl status chronyd | grep running"
    Write-Host -F Red "result is $result"    
    if ($result -ne $False)
    {
        Write-Error -Message "chronyd disable failed" -Category ObjectNotFound -ErrorAction SilentlyContinue
        return $Aborted
    }
    
    $ntpSet = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "timedatectl set-ntp 0"
}

#
# Before suspend, check offset which should be less than $minOffset
#
$offset_temp = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ntpdate -q clock.redhat.com | awk 'NR == 5 {print `$10`}'"
Write-Host -F Red "Before suspend offset_temp is $offset_temp"
Write-Output "Before suspend offset_temp is $offset_temp"
# Get offset_temp abs
$offset = [Math]::Abs($offset_temp)
Write-Host -F Red "Before suspend offset is $offset"
Write-Output "Before suspend offset is $offset"
if ($offset -gt $minOffset)
{
    Write-Host -F Red "offset is wrong before suspend"
    Write-Output "offset is wrong before suspend"
    Write-Error -Message "offset is wrong before suspend" -Category ObjectNotFound -ErrorAction SilentlyContinue
    DisconnectWithVIServer
    return $Aborted
}

#
# Suspend the VM and confirm the power state
#
Write-Host -F Red "Now, will Suspend the VM......."
Write-Output "Now, will Suspend the VM......."
$suspend = Suspend-VM -VM $vmObj -Confirm:$False
Start-Sleep -S 60
# Get the new VM power status
$vmObjSuspend = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
$suspendState = $vmObjSuspend.PowerState
if ($suspendState -ne "Suspended")
{
    Write-Error -Message "ABORTED: $vmObj is not Suspended, power state is $suspendState" -Category ObjectNotFound -ErrorAction SilentlyContinue
    DisconnectWithVIServer
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
if ( $ret -eq $True )
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
    DisconnectWithVIServer
    return $Aborted
}

# Get the new VM power status
$vmObjOn = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
$onState = $vmObjOn.PowerState
if ($onState -ne "PoweredOn")
{
    Write-Error -Message "ABORTED: $vmObj is not poweredOn, power state is $state" -Category ObjectNotFound -ErrorAction SilentlyContinue
    DisconnectWithVIServer
    return $Aborted
}

#
# After power on, check offset which should be less than $minOffset
#
$offset_temp = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ntpdate -q clock.redhat.com | awk 'NR == 5 {print `$10`}'"
Write-Host -F Red "Before suspend offset_temp is $offset_temp"
Write-Output "Before suspend offset_temp is $offset_temp"
# Get offset_temp abs
$offset = [Math]::Abs($offset_temp)
Write-Host -F Red "Before suspend offset is $offset"
Write-Output "Before suspend offset is $offset"
if ($offset -gt $minOffset)
{
    Write-Error -Message "offset is wrong before suspend" -Category ObjectNotFound -ErrorAction SilentlyContinue
}
else
{
    $retVal = $Passed
}

DisconnectWithVIServer

return $retVal