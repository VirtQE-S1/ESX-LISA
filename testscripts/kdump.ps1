###############################################################################
##
## Description:
##  Push and execute kdump_config.sh, kdump_execute.sh in VM
##  Trigger kdump successfully and get vmcore
##
###############################################################################
##
## Revision:
## v1.0.0 - boyang - 01/18/2017 - Build script
## v1.1.0 - boyang - 02/13/2017 - Remove kdump_result.sh
## v1.2.0 - boyang - 02/14/2107 - Cancle trigger kdump with at command
## v1.3.0 - boyang - 02/22/2017 - Check vmcore function into while
## v1.4.0 - boyang - 02/28/2017 - Send and execute kdump_execute.sh in while
## v1.5.0 - boyang - 02/03/2017 - Call WaitForVMSSHReady and Remove V1.4
## v1.6.0 - boyang - 03/07/2017 - Remove push files, framework will do it
## v1.7.0 - boyang - 03/22/2017 - Execute kdump_execute.sh in while again
## v1.8.0 - boyang - 06/29/2017 - Trigger kdump as a service to reduce rate of framework can't detect vm
## v1.9.0 - boyang - 06/30/2017 - Remove kdump_execute.sh to kdump_prepare.sh
## v2.0.0 - boyang - 10/12/2017 - Remove a server to trigger kdump, using Start-Process
## v2.1.0 - boyang - 08/23/2018 - Remove disconnect / connect again after trigger
##
###############################################################################

<#
.Synopsis
    Trigger the target VM kdump

.Description
    Trigger target VM kdump based on different cases
	
	<test>
		<testName>kdump_crash_mixed_disk</testName>
		<testID>ESX-KDUMP-005</testID>
		<setupScript>
			<file>setupscripts\change_cpu.ps1</file>
			<file>setupScripts\change_memory.ps1</file>
			<file>SetupScripts\add_hard_disk.ps1</file>
		</setupScript>
		<testScript>testscripts\kdump.ps1</testScript>
		<files>remote-scripts\utils.sh</files>
		<files>remote-scripts\kdump_config.sh</files>
		<files>remote-scripts\kdump_prepare.sh</files>
		<testParams>
			<param>crashkernel=128M</param>
			<param>VCPU=2</param>
			<param>VMMemory=4GB</param>
			<param>DiskType=SCSI</param>
			<param>StorageFormat=Thin</param>
			<param>CapacityGB=3</param>
			<param>fileSystems=(ext4 ext3 xfs btrfs)</param>
			<param>TName=kdump_crash_mixed_disk</param>
			<param>TC_COVERED=RHEL6-34886,RHEL7-50870</param>
		</testParams>
		<RevertDefaultSnapshot>True</RevertDefaultSnapshot>
		<timeout>900</timeout>
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
# SendCommandToVM: Push and execute kdump_config.sh
# kdump_config.sh: configures kdump.config / grub
#
Write-Host -F Gray "Start to execute kdump_config.sh in VM......."
Write-Output "Start to execute kdump_config.sh in VM"
$result = SendCommandToVM $ipv4 $sshKey "cd /root && sleep 1 && dos2unix kdump_config.sh && sleep 1 && chmod u+x kdump_config.sh && sleep 1 && ./kdump_config.sh $crashkernel"
if (-not $result)
{
	Write-Output "FAIL: Failed to execute kdump_config.sh in VM."
	DisconnectWithVIServer
	return $Aborted
}


#
# Rebooting VM to apply the kdump settings
#
Write-Host -F Gray "Start to reboot VM after kdump and grub changed......."
Write-Output "Start to reboot VM after kdump and grub changed"
bin\plink.exe -i ssh\${sshKey} root@${ipv4} "init 6"


#
# SendCommandToVM: Push / execute kdump_prepare.sh in while, in case kdump_prepare.sh fail
# kdump_prepare.sh: Confirms all configurations works
#
$timeout = 360
while ($timeout -gt 0)
{
	Write-Host -F Gray "Start to execute kdump_prepare.sh in VM, timeout leaves $timeout......."
	Write-Output "Start to execute kdump_prepare.sh in VM, timeout leaves $timeout"
	$result = SendCommandToVM $ipv4 $sshKey "cd /root && dos2unix kdump_prepare.sh && chmod u+x kdump_prepare.sh && ./kdump_prepare.sh"
	if ($result)
	{
		Write-Host -F Green "PASS: Execute kdump_prepare.sh to VM......."
		Write-Output "PASS: Execute kdump_prepare.sh to VM"
		break
	}
	else
	{
    	Write-Host -F Gray "WARNING: Failed to execute kdump_prepare.sh in VM, try again......."
		Write-Output "WARNING: Failed to execute kdump_prepare.sh in VM, try again"
		Start-Sleep -S 6
		$timeout = $timeout - 6
		if ($timeout -eq 0)
		{
        	Write-Host -F Red "FAIL: Failed to execute kdump_prepare.sh in VM......."
			Write-Output "FAIL: Failed to execute kdump_prepare.sh in VM"
			DisconnectWithVIServer			
			return $Aborted
		}
	}
}


#
# Trigger the kernel panic
#
Write-Host -F Gray "Start a new process to triger kdump......."
Write-Output "Start a new process to triger kdump"
$tmpCmd = "echo c > /proc/sysrq-trigger 2>/dev/null &"
Start-Process bin\plink -ArgumentList "-i ssh\${sshKey} root@${ipv4} ${tmpCmd}" -WindowStyle Hidden


#
# ISSUE: 
# 	After kdump trigger, even though, sometimes, vmcore is generated, reboot well, VM powerstate is on, IP is correct
# 	But can't find the vmcore, manual to check vmocre, it is here!
# WORKAROUND:
#   So try to disconnect / connect VIServer again as a workround
#	Add more debuginfo to debug issue can't find vmcore:
#		$ipv4 -ne $null              -> Process of kdump is finsihed and reboot well
#		ls /root                     -> Confirm script can find VM, communication works in /root
#		touch /var/crash/kdump.txt   -> Confirm /var/crash folder is prepared well
#		ls /var/crash                -> No above two issues, vmcore should be generated, if not, confirm vmcore isn't generated
#


#				  
# Based on WORKAROUND to confirm vmcore	  
#
$timeout = 180
while ($timeout -gt 0)
{
	$vmTemp = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
	$vmTempPowerState = $vmTemp.PowerState
	Write-Host -F Green "The VM power state is $vmTempPowerState"        
	Write-Output "The VM power state is $vmTempPowerState"
	if ($vmTempPowerState -eq "PoweredOn")
	{
		$ipv4 = GetIPv4 $vmName $hvServer
		Write-Host -F Green "The VM ipv4 is $ipv4"            
		Write-Output "The VM ipv4 is $ipv4"            
		if ($ipv4 -ne $null)
		{
			Start-Sleep -S 30
			$debug = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ls /root/"
			Write-Host -F Green "Debug: debug is $debug"         
			Write-Output "Debug: debug is $debug"	

			$debug2 = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ls /var/crash"
			Write-Host -F Green "Debug: debug2 is $debug2"            
			Write-Output "Debug: debug2 is $debug2" 
			
			$debug3 = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "touch /var/crash/kdump.txt && ls /var/crash/"
			Write-Host -F Green "Debug: debug3 is $debug3"  	
			Write-Output "Debug debug3 is $debug3"			

			break
		}
	}
	Start-Sleep -S 6
	$timeout = $timeout - 6
	if ($timeout -eq 0)
	{
		Write-Host -F Yellow "WARNING: Timeout, and power off the VM"
		Write-Output "WARNING: After trigger kdump, disconnect / connect viserver, still can't find VM"
		return $Aborted
	}
}


#
# Check vmcore size after it is generated
#
$timeout = 180
while ($timeout -gt 0)
{
	Write-Host -F Gray "Start to check vmcore, maybe vmcore is not ready, timeout leaves $timeout......."
	Write-Output "Start to check vmcore, maybe vmcore is not ready, timeout leaves $timeout"
	
	$result = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "find /var/crash/ -name vmcore -type f -size +10M"
	if ($result -ne $null)
	{
    	Write-Host -F Green "PASS: Generates vmcore in VM, resutl is $result......."
		Write-Output "PASS: Generates vmcore in VM, resutl is $result"
		$retVal = $Passed
		break	
	}
	else
	{
		Write-Host -F Gray "WARNING: Failed to get vmcore from VM, try again......."    
		Write-Output "WARNING: Failed to get vmcore from VM, try again"
		Start-Sleep -S 6
		$timeout = $timeout - 6
		if ($timeout -eq 0)
		{
			Write-Host -F Red "FAIL: After timeout, can't get vmcore......."
			Write-Output "FAIL: After timeout, can't get vmcore"
			DisconnectWithVIServer			
			$retVal = $Failed
		}
	}
}


DisconnectWithVIServer

return $retVal
