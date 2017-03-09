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
## V1.3 - boyang - 02/22/2017 - Check vmcore function into while
## V1.4 - boyang - 02/28/2017 - Send and execute kdump_execute.sh in while
## V1.5 - boyang - 02/03-2017 - Call WaitForVMSSHReady and Remove V1.4
## V1.6 - boyang - 03/07/2017 - Remove push files
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
$tname = $null

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
		"TName"			{ $tname = $fields[1].Trim()}		
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

# NMI is not supports now

if ($null -eq $tname)
{
	"FAIL: Test parameter tname was not specified"
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
# SendCommandToVM: execute kdump_config.sh in VM
#
Write-Output "Start to execute kdump_config.sh in VM."
Write-Host -F Cyan "kdump.ps1: Start to execute kdump_config.sh in VM......."
$retVal = SendCommandToVM $ipv4 $sshKey "cd /root && dos2unix kdump_config.sh && chmod u+x kdump_config.sh && ./kdump_config.sh $crashkernel"
if (-not $retVal)
{
	Write-Output "FAIL: Failed to execute kdump_config.sh in VM, and retVal is $retVal."
	Write-Host -F Red "kdump.ps1: FAIL: Failed to execute kdump_config.sh to VM, and retVal is $retVal......."
	
	#
	# Debug: GetFileFromVM: get kdump_config.summary to local
	#
	$retVal = GetFileFromVM $ipv4 $sshKey "/root/summary.log" "${tname}_fail_kdump_config.log"
	
	return $Failed
}
else
{
	Write-Output "PASS: Execute kdump_config.sh in VM."
	Write-Host -F Green "kdump.ps1: PASS: Execute kdump_config.sh in VM......."
	
	$retVal = $Passed
}

#
# Rebooting VM in order to apply the kdump settings
#
Write-Output "Start to reboot VM after kdump and grub changed."
Write-Host -F Cyan "kdump.ps1: Start to reboot VM after kdump and grub changed......."
$retVal = .\bin\plink -i ssh\${sshKey} root@${ipv4} "init 6"
if (-not $retVal)
{
	Write-Output "PASS: Rebooting."
	Write-Host -F Green "kdump.ps1: PASS: Rebooting......."

	$retVal = $Passed
}
else
{
	Write-Output "FAIL: Failed to reboot VM."
	Write-Host -F Red "kdump.ps1: FAIL: Failed to reboot VM......."

	return $Failed
}

#
# WaitForVMSSHReady
#
Write-Output "Wait for VM SSH ready."
Write-Host -F Cyan "kdump.ps1: Wait for VM SSH ready......."
$retVal = WaitForVMSSHReady $vmName $hvServer $sshKey 360
if (-not $retVal)
{
	Write-Output "PASS: Failed to ready SSH, and retVal is $retVal."
	Write-Host -F Red "kdump.ps1: FAIL: Failed to ready SSH, and retVal is $retVal........"

	return $Failed
}
else
{
	Write-Output "PASS: SSH is ready."
	Write-Host -F Green "kdump.ps1: PASS: SSH is ready......."

	$retVal = $Passed
}

#
# SendCommandToVM: execute kdump_execute.sh in while
#
Write-Output "Start to execute kdump_execute.sh in VM."
Write-Host -F Cyan "kdump.ps1: Start to execute kdump_execute.sh in VM........"
$retVal = SendCommandToVM $ipv4 $sshKey "cd /root && dos2unix kdump_execute.sh && chmod u+x kdump_execute.sh && ./kdump_execute.sh"
if (-not $retVal)
{
	Write-Output "FAIL: Failed to execute kdump_execute.sh in VM, and retVal is $retVal."
	Write-Host -F Yellow "kdump.ps1: FAIL: Failed to execute kdump_execute.sh in VM, and retVal is $retVal........"

	#
	# Debug: GetFileFromVM: get kdump_execute.summary to local
	#
	GetFileFromVM $ipv4 $sshKey "/root/summary.log" "${logdir}/${tname}_fail_kdump_execute.log"

	return $Failed
}
else
{
	Write-Output "PASS: Execute kdump_execute.sh to VM."
	Write-Host -F Green "kdump.ps1: PASS: Execute kdump_execute.sh in VM......."

	$retVal = $Passed
}

#
# Trigger the kernel panic
#
Write-Output "Trigger the kernel panic from PS."
Write-Host -F Cyan "kdump.ps1: Trigger the kernel panic from PS......."
if ($nmi -eq 1)
{
	# No function supports NMI trigger now
	Write-Output "Will use NMI to trigger kdump"
	Start-Sleep -S 6
}
else
{
	$retVal = SendCommandToVM $ipv4 $sshKey "echo 'echo c > /proc/sysrq-trigger' | at now + 1 minutes"
	if (-not $retVal)
	{
		Write-Output "Unkonw issue in trigger."
		Write-Host -F Cyan "kdump.ps1: Unkonw issue in trigger......."
		
		$retVal = $Failed
	}
	else
	{
		"Finished kdump trigger" | out-file -encoding ASCII -filepath ${logdir}/${tname}_Trigger_Done.log
	}
}

#
# WaitForVMSSHReady
#
Write-Output "Wait for VM SSH ready."
Write-Host -F Cyan "kdump.ps1: Wait for VM SSH ready......."
$retVal = WaitForVMSSHReady $vmName $hvServer $sshKey 360
if (-not $retVal)
{
	Write-Output "PASS: Failed to ready SSH."
	Write-Host -F Red "kdump.ps1: FAIL: Failed to ready SSH, and retVal is $retVal........"
	
	return $Failed
}
else
{
	Write-Output "PASS: SSH is ready."
	Write-Host -F Green "kdump.ps1: PASS: SSH is ready......."
	
	$retVal = $Passed
}

#
# Check vmcore after get VM IP
#
Write-Output "Start to check vmcore, SSH is ready, But maybe FS or vmcore is not ready."
Write-Host -F Cyan "kdump.ps1: Start to check vmcore, SSH is ready, But maybe FS or vmcore is not ready......."
$timeout = 360
while ($timeout -gt 0)
{
	$retVal = .\bin\plink -i ssh\${sshKey} root@${ipv4} "find /var/crash/*/vmcore* -type f -size +10M"
	if (-not $retVal)
	{
		Write-Output "FAIL: Failed to get vmcore from VM, try again after $timeout"
		Write-Host -F Yellow "kdump.ps1: FAIL: Failed to get vmcore from VM, try again after $timeout......."
		Start-Sleep -S 6
		$timeout = $timeout - 6
		if ($timeout -eq 0)
		{
			Write-Output "FAIL: After timeout, can't get vmcore."
			Write-Host -F Cyan "kdump.ps1: FAIL: After timeout, can't get vmcore......."
			
			#
			# Debug: GetFileFromVM: get vmore_checking.log to local
			#
			GetFileFromVM $ipv4 $sshKey "/root/summary.log" "${logdir}/${tname}_vmcore_checking.log"
			
			return $Failed
		}
	}
	else
	{
		Write-Output "PASS: Generates vmcore in VM."
		Write-Host -F Green "kdump.ps1: PASS: Generates vmcore in VM, and retVal is $retVal......."
		
		$retVal = $Passed

		break
	}
}

DisconnectWithVIServer

return $retVal