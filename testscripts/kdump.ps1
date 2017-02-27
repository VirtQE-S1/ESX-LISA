###############################################################################
##
## Description:
##  Push and execute kdump_config.sh, kdump_execute.sh, kdump_result.sh in VM
##  Trigger kdump successfully and get vmcore
##
###############################################################################
##
## Revision:
## V1.0 - boyang - 01/18/2017 - Build script
## V1.1 - boyang - 02/13/2017 - Remove kdump_result.sh
## V1.2 - boyang - 02/14/2107 - Cancle trigger kdump with at command
## V1.3 - boyang - 02/22/2017 - Move check vmcore function into while
##
###############################################################################

<#
.Synopsis
    Trigger target VM kdump.

.Description
    Trigger target VM kdump based on different cases.

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
# Display the test parameters so they are captured in the log file
#
"TestParams : '${testParams}'"

#
# Parse the test parameters
#
$rootDir = $null
$sshKey = $null
$ipv4 = $null
$crashkernel = $null
$logdir = $null
$nmi = $null

$params = $testParams.Split(";")
foreach ($p in $params) 
{
	$fields = $p.Split("=")
	switch ($fields[0].Trim()) 
	{
		"rootDir"		{ $rootDir = $fields[1].Trim() }
		"sshKey"		{ $sshKey = $fields[1].Trim() }
		"ipv4"			{ $ipv4 = $fields[1].Trim() }
		"crashkernel"	{ $crashkernel = $fields[1].Trim() }
		"TestLogDir"	{ $logdir = $fields[1].Trim()}
		"NMI"			{ $nmi = $fields[1].Trim()}
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

if ($null -eq $crashkernel)
{
	"FAIL: Test parameter crashkernel was not specified"
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

#
# SendFileToVM: send kdump_config.sh script to VM for configuring kdump.conf and grub.conf
#
Write-Output "Start to send kdump_config.sh to VM."
Write-Host -F Cyan "kdump.ps1: Start to send kdump_config.sh to VM......."
$retVal = SendFileToVM $ipv4 $sshKey ".\remote-scripts\kdump_config.sh" "/root/kdump_config.sh"
if (-not $retVal)
{
	Write-Output "FAIL: Failed to send kdump_config.sh to VM."
	Write-Host -F Red "FAIL: Failed to send kdump_config.sh to VM, and retVal is $retVal........"
	return $Failed
}
else
{
	Write-Output "PASS: Send kdump_config.sh to VM."
	Write-Host -F Green "kdump.ps1: PASS: Send kdump_config.sh to VM......."
	$retVal = $Passed
}

#
# SendCommandToVM: execute kdump_config.sh
#
Write-Output "Start to execute kdump_config.sh in VM."
Write-Host -F Cyan "kdump.ps1: Start to execute kdump_config.sh in VM......."
$retVal = SendCommandToVM $ipv4 $sshKey "cd /root && dos2unix kdump_config.sh && chmod u+x kdump_config.sh && ./kdump_config.sh $crashkernel"
if (-not $retVal)
{
	Write-Output "FAIL: Failed to execute kdump_config.sh in VM."
	Write-Host -F Red "FAIL: Failed to execute kdump_config.sh to VM, and retVal is $retVal......."
	return $Failed
}
else
{
	Write-Output "PASS: Execute kdump_config.sh in VM."
	Write-Host -F Green "kdump.ps1: PASS: Execute kdump_config.sh in VM......."
	$retVal = $Passed
}


#
# Debug: GetFileFromVM: get kdump_config.summary to local
#
$date_string = [DateTime]::Now.ToString("yyyyMMdd-HHmmss")
$retVal = GetFileFromVM $ipv4 $sshKey "/root/summary.log" "$logdir/${date_string}_config_summary.log"

#
# Rebooting VM in order to apply the kdump settings
#
$retVal = Restart-VM -VM $vmName -Confirm:$false
if (-not $retVal)
{
	Write-Output "FAIL: Failed to reboot."
	Write-Host -F Red "kdump.ps1:FAIL: Failed to reboot......."
	return $Failed
}
else
{
	Write-Output "PASS: Rebooting the VM well."
	Write-Host -F Green "kdump.ps1: PASS: Rebootint the VM well......."
	$retVal = $Passed
}

#
# Waiting the VM to start up
#
Write-Output "Waiting VM to have a connection."
Write-Host -F Cyan "kdump.ps1: Waiting VM to have a connection......."
$timeout = 600
while ($timeout -gt 0)
{
	Write-Output "During Reboot, now start to call GetIPv4 to get IP."
	Write-Host -F Cyan "kdump.ps1: During reboot, now start to call GetIPv4 to get IP......."
	$retVal = GetIPv4 $vmName $hvServer
	if (-not $retVal)
	{
		Write-Output "WARNING: GetIPv4 failed, will check again and again every 6s."
		Write-Host -F Red "WARNING: GetIPv4 failed, will check again and again every 6s......."
		Start-Sleep -S 6
		$timeout = $timeout - 6
	}
	else
	{
		Write-Output "PASS: GetIPv4 and return $retVal."
		Write-Host -F Green "kdump.ps1: PASS: GetIPv4 and return IP: $retVal......."
		$retVal = $Passed
		break
	}
}

#
# SendFileToVM: send kdump_execute.sh script to VM for checking kdump status after reboot
#
Write-Output "Start to send kdump_execute.sh to VM."
Write-Host -F Cyan "kdump.ps1: Start to send kdump_execute.sh to VM......."
$retVal = SendFileToVM $ipv4 $sshKey ".\remote-scripts\kdump_execute.sh" "/root/kdump_execute.sh"
if (-not $retVal)
{
	Write-Output "FAIL: Failed to send kdump_execute.sh to VM."
	Write-Host -F Red "FAIL: Failed to send kdump_execute.sh to VM, and retVal is $retVal......."
	return $Failed
}
else
{
	Write-Output "PASS: Send kdump_execute.sh to VM."
	Write-Host -F Green "kdump.ps1: PASS: Send kdump_execute.sh to VM......."
	$retVal = $Passed
}

#
# SendCommandToVM: execute kdump_execute.sh
#
Write-Output "Start to execute kdump_execute.sh in VM."
Write-Host -F Cyan "kdump.ps1: Start to execute kdump_execute.sh in VM......."
$retVal = SendCommandToVM $ipv4 $sshKey "cd /root && dos2unix kdump_execute.sh && chmod u+x kdump_execute.sh && ./kdump_execute.sh"
if (-not $retVal)
{
	Write-Output "FAIL: Failed to execute kdump_execute.sh in VM."
	Write-Host -F Red "FAIL: Failed to execute send kdump_execute.sh in VM, and retVal is $retVal......."
	#
	# Debug: GetFileFromVM: get kdump_execute.summary to local
	#
	$date_string = [DateTime]::Now.ToString("yyyyMMdd-HHmmss")
	$retVal = GetFileFromVM $ipv4 $sshKey "/root/summary.log" "$logdir/${date_string}_fail_execute_summary.log"
	return $Failed
}
else
{
	Write-Output "PASS: Execute kdump_execute.sh to VM, and retVal is $retVal......."
	Write-Host -F Green "kdump.ps1: PASS: Execute kdump_execute.sh in VM......."
	$retVal = $Passed
}

#
# Debug: GetFileFromVM: get kdump_execute.summary to local
#
$date_string = [DateTime]::Now.ToString("yyyyMMdd-HHmmss")
$retVal = GetFileFromVM $ipv4 $sshKey "/root/summary.log" "$logdir/${date_string}_execute_summary.log"

#
# Trigger the kernel panic
#
Write-Output "Trigger the kernel panic."
Write-Host -F Cyan "kdump.ps1: Trigger the kernel panic from PS......."
if ($nmi -eq 1)
{
	# No function supports NMI trigger in Linux
	Write-Output "Will use NMI to trigger kdump"
	Start-Sleep -S 12
}
else
{
	Write-Output "echo c to trigger kdump  from PS."
	Write-Host -F Cyan "kdump.ps1: echo c to trigger kdump  from PS......."
	#$retVal = SendCommandToVM $ipv4 $sshKey "echo 'echo c > /proc/sysrq-trigger' | at now + 1 minutes"
	$retVal = SendCommandToVM $ipv4 $sshKey "echo c > /proc/sysrq-trigger &"
}

#
# Check vmcore after get VM IP
#
Write-Output "Checking VM's connection after kernel panic."
Write-Host -F Cyan "kdump.ps1: Checking VM's connection after kernel panic......."
$timeout = 600
while ($timeout -gt 0)
{
	Write-Output "During booting, start to call GetIPv4 to get IP."
	Write-Host -F Cyan "kdump.ps1: During booting, start to call GetIPv4 to get IP......."
	$retVal = GetIPv4 $vmName $hvServer
	if (-not $retVal)
	{
		Write-Output "WARNING: GetIPv4 failed, will check again after 6s."
		Write-Host -F Yellow "kdump.ps1: WARNING: GetIPv4 failed, will check again after 6s......."
		Start-Sleep -S 6
		$timeout = $timeout - 6
		if ($timeout -eq 0)
		{
			Write-Output "FAIL: After $timeout, can't get IP."
			Write-Host -F Cyan "FAIL: After $timeout, can't get IP......."
			return $Failed
		}
	}
	else
	{
		Write-Output "PASS: GetIPv4, Connection is good, return $retVal."
		Write-Host -F Green "kdump.ps1: GetIPv4, Connection is good, return $retVal..."
		# After get IP, maybe can't get vmcore as FS or vmcore isn't prepared ready
		Write-Output "Will check vmcore after get IP. But it's early for OS booting or parepare FS and vmcore."
		Write-Host -F Cyan "kdump.ps1: Will check vmcore after get IP. But it's early for OS booting or parepare FS and vmcore......."
		$retVal = SendCommandToVM $ipv4 $sshKey "find /var/crash/*/vmcore -type f -size +10M"
		if (-not $retVal)
		{
			Write-Output "WARNING: Failed to get vmcore from VM, will try again after 6s"
			Write-Host -F Yellow "kdump.ps1: WARNING: Failed get vmcore from VM, will try again after 6s......."
			Start-Sleep -S 6
			$timeout = $timeout - 6
			if ($timeout -eq 0)
			{
				Write-Output "FAIL: After $timeout, can't get IP."
				Write-Host -F Red "FAIL: After $timeout, can't get IP......."
				return $Failed
			}
		}
		else
		{
			Write-Output "PASS: Generates mcore in VM."
			Write-Host -F Green "kdump.ps1: PASS: Generates vmcore in VM, and retVal is $retVal......."
			$retVal = $Passed
			break
		}	
	}
}

DisconnectWithVIServer

return $retVal