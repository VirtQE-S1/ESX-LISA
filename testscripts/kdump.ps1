###############################################################################
## Description:
##	Push and execute kdump_config.sh, kdump_execute.sh in a VM
##	Trigger kdump successfully and get vmcore
##
## Revision:
##	v1.0.0 - boyang - 01/18/2017 - Build script
## 	v1.1.0 - boyang - 02/13/2017 - Remove kdump_result.sh
## 	v1.2.0 - boyang - 02/14/2107 - Cancle trigger kdump with at command
## 	v1.3.0 - boyang - 02/22/2017 - Check vmcore function into while
## 	v1.4.0 - boyang - 02/28/2017 - Send and execute kdump_execute.sh in while
## 	v1.5.0 - boyang - 02/03/2017 - Call WaitForVMSSHReady and Remove V1.4
## 	v1.6.0 - boyang - 03/07/2017 - Remove push files, framework will do it
## 	v1.7.0 - boyang - 03/22/2017 - Execute kdump_execute.sh in while again
## 	v1.8.0 - boyang - 06/29/2017 - Trigger kdump as a service
## 	v1.9.0 - boyang - 06/30/2017 - Remove kdump_execute.sh to kdump_prepare.sh
## 	v2.0.0 - boyang - 10/12/2017 - Start-Process places the service to trigger
## 	v2.1.0 - boyang - 08/23/2018 - Remove disconnect / connect again after trigger
##	v2.1.1 - boyang - 08/28/2018 - Sleep after trigger to aviod to detect VM
###############################################################################


<#
.Synopsis
    Trigger the target VM kdump

.Description
    Trigger target VM kdump based on different cases
	
.Parameter vmName
    Name of the test VM.

.Parameter hvServer
    Name of the VIServer hosting the VM.

.Parameter testParams
    Semicolon separated list of test parameters.
#>


param([String] $vmName, [String] $hvServer, [String] $testParams)


# Checking the input arguments
if (-not $vmName)
{
    "FAIL: VM name cannot be null!"
    return $Aborted
}

if (-not $hvServer)
{
    "FAIL: hvServer cannot be null!"
    return $Aborted
}

if (-not $testParams)
{
    Throw "FAIL: No test parameters specified"
}


# Output test parameters so they are captured in log file
"TestParams : '${testParams}'"


# Parse test parameters
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

# Check all parameters
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
		return $Aborted
	}
}

if ($null -eq $sshKey) 
{
	"FAIL: Test parameter sshKey was not specified"
	return $Aborted
}

if ($null -eq $ipv4) 
{
	"FAIL: Test parameter ipv4 was not specified"
	return $Aborted
}

if ($null -eq $crashkernel)
{
	"FAIL: Test parameter crashkernel was not specified"
	return $Aborted
}

if ($null -eq $logdir)
{
	"FAIL: Test parameter logdir was not specified"
	return $Aborted
}

# NMI is not supports now

if ($null -eq $tname)
{
	"FAIL: Test parameter tname was not specified"
	return $Aborted
}


# Source tcutils.ps1
. .\setupscripts\tcutils.ps1
PowerCLIImport
ConnectToVIServer $env:ENVVISIPADDR `
                  $env:ENVVISUSERNAME `
                  $env:ENVVISPASSWORD `
                  $env:ENVVISPROTOCOL

				  
###############################################################################
# Main Body
###############################################################################
$retVal = $Failed

# kdump_config.sh: configures kdump.config / grub
Write-Host -F Red "INFO: Start to execute kdump_config.sh in VM"
Write-Output "INFO: Start to execute kdump_config.sh in VM"
$result = SendCommandToVM $ipv4 $sshKey "cd /root && sleep 1 && dos2unix kdump_config.sh && sleep 1 && chmod u+x kdump_config.sh && sleep 1 && ./kdump_config.sh $crashkernel"
if (-not $result)
{
	Write-Host -F Red "ERROR: Failed to execute kdump_config.sh in VM"
	Write-Output "ERROR: Failed to execute kdump_config.sh in VM"
	DisconnectWithVIServer
	return $Aborted
}

# Rebooting the VM to apply the kdump settings
Write-Host -F Red "INFO: Start to reboot VM after kdump and grub changed"
Write-Output "INFO: Start to reboot VM after kdump and grub changed"
bin\plink.exe -i ssh\${sshKey} root@${ipv4} "init 6"

# Confirm enough time, below kdump_prepare.sh execution starts well after 60s
# As the VM receives init 6, but its IP maybe still be detected
# HERE. TODO. StopVMViaSSH, WaitForVMSSHReady
Start-Sleep -S 60

# kdump_prepare.sh: Confirms all configurations works
$timeout = 60
while ($timeout -gt 0)
{
	Write-Host -F Red "INFO: Start to execute kdump_prepare.sh in VM, timeout leaves [ $timeout ]"
	Write-Output "INFO: Start to execute kdump_prepare.sh in VM, timeout leaves [ $timeout ]"
	$result = SendCommandToVM $ipv4 $sshKey "cd /root && dos2unix kdump_prepare.sh && chmod u+x kdump_prepare.sh && ./kdump_prepare.sh"
	if ($result)
	{
		Write-Host -F Red "INFO: Execute kdump_prepare.sh to VM"
		Write-Output "INFO: Execute kdump_prepare.sh to VM"
		break
	}
	else
	{
    	Write-Host -F Gray "WARNING: Failed to execute kdump_prepare.sh in VM, try again"
		Write-Output "WARNING: Failed to execute kdump_prepare.sh in VM, try again"
		Start-Sleep -S 6
		$timeout = $timeout - 6
		if ($timeout -eq 0)
		{
        	Write-Host -F Red "ERROR: Failed to execute kdump_prepare.sh in VM"
			Write-Output "ERROR: Failed to execute kdump_prepare.sh in VM"
			DisconnectWithVIServer			
			return $Aborted
		}
	}
}

# Trigger the kernel panic with subprocess
Write-Host -F Red "INFO: Start a new process to triger kdump"
Write-Output "INFO: Start a new process to triger kdump"
$tmpCmd = "echo c > /proc/sysrq-trigger 2>/dev/null &"
Start-Process bin\plink -ArgumentList "-i ssh\${sshKey} root@${ipv4} ${tmpCmd}" -WindowStyle Hidden

# Confirm enough time to complete vmcore save and reboot
# As maybe the VM IP still be detected and go to the next 120s while loop
# HERE. TODO. Poweredoff
Start-Sleep -S 60

# Check vmcore after trigger complete and reboot
$timeout = 120
while ($timeout -gt 0)
{
	Write-Host -F Red "INFO: Start to check vmcore, maybe vmcore is not ready, timeout leaves [ $timeout ]"
	Write-Output "INFO: Start to check vmcore, maybe vmcore is not ready, timeout leaves [ $timeout ]"
	
	$ret = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "find /var/crash/ -name vmcore -type f -size +10M"
	if ($null -ne $ret)
	{
    	Write-Host -F Red "INFO: Generates vmcore in VM"
		Write-Output "INFO: Generates vmcore in VM"
		Write-Host -F Red "DEBUG:  ret: [ $ret ]"
		$retVal = $Passed
		break	
	}
	else
	{
		Write-Host -F Gray "WARNING: Failed to get vmcore from VM, try again"    
		Write-Output "WARNING: Failed to get vmcore from VM, try again"
		Start-Sleep -S 6
		$timeout = $timeout - 6
		if ($timeout -eq 0)
		{
			Write-Host -F Red "FAIL: After timeout, can't get vmcore"
			Write-Output "FAIL: After timeout, can't get vmcore"
			DisconnectWithVIServer			
			$retVal = $Failed
		}
	}
}


DisconnectWithVIServer

return $retVal
