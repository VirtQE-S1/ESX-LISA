###############################################################################
##
## Description:
##  Push and execute kdump_config.sh, kdump_execute.sh in VM
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
## V1.6 - boyang - 03/07/2017 - Remove push files, framework will do it
## V1.7 - boyang - 03/22/2017 - Execute kdump_execute.sh in while again
## V1.8 - boyang - 06/29/2017 - Trigger kdump as a service to reduce rate of framework can't detect vm
## V1.9 - boyang - 06/30/2017 - Remove kdump_execute.sh to kdump_prepare.sh
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
# Output test parameters so they are captured in log file
#
"TestParams : '${testParams}'"

#
# Parse test parameters
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

$retVal = $Failed

#
# SendCommandToVM: Just push kdump_trigger_service.sh Service to vm. Will be executed after kdump_execute.sh
# kdump_trigger_service.sh: As a service with booting, will off and del itself firstly to voide trigger forever. then trigger kdump
# If framework triggers kdump, mostly times, framework will not connect the target vm and timeout
#
Write-Output "Start to chmod kdump_trigger_service.sh in VM."
$result = SendCommandToVM $ipv4 $sshKey "cd /root && dos2unix kdump_trigger_service.sh && chmod a+x kdump_trigger_service.sh"
if (-not $result)
{
	Write-Output "FAIL: Failed to chmod kdump_trigger_service.sh in VM."
	DisconnectWithVIServer
	return $Aborted
}

#
# SendCommandToVM: push and execute kdump_config.sh
# kdump_config.sh: configures kdump.config / grub
#
Write-Output "Start to execute kdump_config.sh in VM."
$result = SendCommandToVM $ipv4 $sshKey "cd /root && dos2unix kdump_config.sh && chmod u+x kdump_config.sh && ./kdump_config.sh $crashkernel"
if (-not $result)
{
	Write-Output "FAIL: Failed to execute kdump_config.sh in VM."
	DisconnectWithVIServer
	return $Aborted
}

#
# Rebooting VM to apply the kdump settings
#
Write-Output "Start to reboot VM after kdump and grub changed."
bin\plink.exe -i ssh\${sshKey} root@${ipv4} "init 6"

#
# SendCommandToVM: Push and execute kdump_prepare.sh in while, in case kdump_prepare.sh fail after reboot
# kdump_prepare.sh: Confirms all configurations works and setup kdump_trigger_service.sh as a service
#
$timeout = 240
while ($timeout -gt 0)
{
	Write-Host -F Yellow "kdump.ps1: Start to execute kdump_prepare.sh in VM, timeout leaves $timeout......."
	Write-Output "Start to execute kdump_prepare.sh in VM, timeout leaves $timeout."
	$result = SendCommandToVM $ipv4 $sshKey "cd /root && dos2unix kdump_prepare.sh && chmod u+x kdump_prepare.sh && ./kdump_prepare.sh"
	if ($result)
	{
		Write-Host -F Green "kdump.ps1: PASS: Execute kdump_prepare.sh to VM......."
		Write-Output "PASS: Execute kdump_prepare.sh to VM."
		break
	}
	else
	{
		Write-Output "WARNING: Failed to execute kdump_prepare.sh in VM, try again."
		Write-Host -F Yellow "kdump.ps1: WARNING: Failed to execute kdump_prepare.sh in VM, try again........"
		Start-Sleep -S 6
		$timeout = $timeout - 6
		if ($timeout -eq 0)
		{
			Write-Output "FAIL: Failed to execute kdump_prepare.sh in VM."
			Write-Host -F Red "kdump.ps1: FAIL: Failed to execute kdump_prepare.sh in VM......."
			DisconnectWithVIServer			
			return $Aborted
		}
	}
}

#
# Rebooting VM to trigger kdump
#
Write-Output "Reboot VM, kdump_trigger_service will be executed to trigger kdump."
bin\plink.exe -i ssh\${sshKey} root@${ipv4} "init 6"

#
# Check vmcore after get VM IP
#
$timeout = 240
while ($timeout -gt 0)
{
	Write-Host -F Yellow "kdump.ps1: Start to check vmcore, but maybe FS or vmcore is not ready, timeout leaves $timeout......."
	Write-Output "Start to check vmcore, but maybe FS or vmcore is not ready, timeout leaves $timeout"
	$result = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "find /var/crash/ -name vmcore -type f -size +10M"
	if ($result -ne $null)
	{
		Write-Output "PASS: Generates vmcore in VM."
		Write-Host -F Green "kdump.ps1: PASS: Generates vmcore in VM, resutl is $result......."
		$retVal = $Passed
		break	
	}
	else
	{
		Write-Output "WARNING: Failed to get vmcore from VM, try again."
		Write-Host -F Yellow "kdump.ps1: WARNING: Failed to get vmcore from VM, try again......."
		Start-Sleep -S 6
		$timeout = $timeout - 6
		if ($timeout -eq 0)
		{
			Write-Output "FAIL: After timeout, can't get vmcore."
			Write-Host -F Cyan "kdump.ps1: FAIL: After timeout, can't get vmcore......."
			DisconnectWithVIServer			
			$retVal = $Failed
		}
	}
}

DisconnectWithVIServer

return $retVal