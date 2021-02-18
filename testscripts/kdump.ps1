########################################################################################
## Description:
##	Push and execute kdump_config.sh, kdump_execute.sh in a VM
##	Trigger kdump successfully and get vmcore
##
## Revision:
##	v1.0.0 - boyang - 01/18/2017 - Build script.
## 	v1.1.0 - boyang - 02/13/2017 - Remove kdump_result.sh.
## 	v1.2.0 - boyang - 02/14/2107 - Cancle trigger kdump with at command.
## 	v1.3.0 - boyang - 02/22/2017 - Check vmcore function into while.
## 	v1.4.0 - boyang - 02/28/2017 - Send and execute kdump_execute.sh in while.
## 	v1.5.0 - boyang - 02/03/2017 - Call WaitForVMSSHReady and Remove V1.4.
## 	v1.6.0 - boyang - 03/07/2017 - Remove push files, framework will do it.
## 	v1.7.0 - boyang - 03/22/2017 - Execute kdump_execute.sh in while again.
## 	v1.8.0 - boyang - 06/29/2017 - Trigger kdump as a service.
## 	v1.9.0 - boyang - 06/30/2017 - Remove kdump_execute.sh to kdump_prepare.sh.
## 	v2.0.0 - boyang - 10/12/2017 - Start-Process places the service to trigger.
## 	v2.1.0 - boyang - 08/23/2018 - Remove disconnect / connect again after trigger.
##	v2.1.1 - boyang - 08/28/2018 - Sleep after trigger to aviod to detect VM.
##	v2.2.1 - boyang - 02/09/2021 - File kudmp_results.sh for vmcore checking.
########################################################################################


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


# Checking the input arguments.
param([String] $vmName, [String] $hvServer, [String] $testParams)
if (-not $vmName) {
    "FAIL: VM name cannot be null!"
    return $Aborted
}

if (-not $hvServer) {
    "FAIL: hvServer cannot be null!"
    return $Aborted
}

if (-not $testParams) {
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
foreach ($p in $params)  {
	$fields = $p.Split("=")
	switch ($fields[0].Trim()) {
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
if (-not $rootDir) {
	"WARNING: no rootdir was specified."
}
else {
	if ((Test-Path -Path "${rootDir}")) {
		cd $rootDir
	}
	else {
		"WARNING: rootdir '${rootDir}' does not exist."
		return $Aborted
	}
}

if ($null -eq $sshKey) {
	"FAIL: Test parameter sshKey was not specified."
	return $Aborted
}

Write-Host -F Red "DEBUG: IP: $ipv4"
if ($null -eq $ipv4) {
	"FAIL: Test parameter ipv4 was not specified."
	return $Aborted
}

if ($null -eq $crashkernel) {
	"FAIL: Test parameter crashkernel was not specified."
	return $Aborted
}

if ($null -eq $logdir) {
	"FAIL: Test parameter logdir was not specified."
	return $Aborted
}

# NMI is not supports now.

if ($null -eq $tname) {
	"FAIL: Test parameter tname was not specified."
	return $Aborted
}


# Source tcutils.ps1.
. .\setupscripts\tcutils.ps1
PowerCLIImport
ConnectToVIServer $env:ENVVISIPADDR `
                  $env:ENVVISUSERNAME `
                  $env:ENVVISPASSWORD `
                  $env:ENVVISPROTOCOL
				  

########################################################################################
# Main Body
########################################################################################
$retVal = $Failed


# kdump_config.sh: configures kdump.config and grub.
LogPrint "INFO: Start to run kdump_config.sh with crashkernel=$crashkernel in the VM."
$ret_config = SendCommandToVM $ipv4 $sshKey "cd /root && dos2unix kdump_config.sh && chmod u+x kdump_config.sh && ./kdump_config.sh $crashkernel"
LogPrint "DEBUG: ret_config: ${ret_config}."
if (-not $ret_config) {
	LogPrint "ERROR: Failed to run kdump_config.sh in VM."
	DisconnectWithVIServer
	return $Aborted
}


# Rebooting the VM to apply the kdump settings.
LogPrint "INFO: Reboot the VM after kdump and grub changed."
bin\plink.exe -i ssh\${sshKey} root@${ipv4} "init 6"


# As the VM receives init 6, but its IP maybe still be detected.
# HERE. TODO. StopVMViaSSH, WaitForVMSSHReady
Start-Sleep -S 6


# kdump_prepare.sh: Confirms all configurations, services work.
$timeout = 180
while ($timeout -gt 0) {
	LogPrint "INFO: Start to run kdump_prepare.sh in the VM, timeout leaves ${timeout}."
	$ret_prepare = SendCommandToVM $ipv4 $sshKey "cd /root && dos2unix kdump_prepare.sh && chmod u+x kdump_prepare.sh && ./kdump_prepare.sh"
	LogPrint "DEBUG: ret_prepare: ${ret_prepare}."
	if ($ret_prepare) {
		break
	}
	else {
		LogPrint "WARNING: Re-run kdump_prepare.sh after 6 seconds."
		Start-Sleep -S 6
		$timeout = $timeout - 6
		if ($timeout -eq 0) {
			Logprint "ERROR: Failed to run kdump_prepare.sh."
			DisconnectWithVIServer			
			return $Aborted
		}
	}
}


# Trigger a kdump.
# DON'T put this CMD to a script to run.
LogPrint "INFO: Start a new process to triger a kdump."
$tmpCmd = "echo c > /proc/sysrq-trigger 2>/dev/null &"
Start-Process bin\plink -ArgumentList "-batch -i ssh\${sshKey} root@${ipv4} ${tmpCmd}" -WindowStyle Hidden


# As the VM receives kdump and rebooting, its IP maybe still be detected.
Start-Sleep -S 6


$timeout = 180
while ($timeout -gt 0) {
	LogPrint "INFO: Start to run kdump_result.sh in the VM to find out the vmcore."
	$ret_result = SendCommandToVM $ipv4 $sshKey "cd /root && dos2unix kdump_result.sh && chmod u+x kdump_result.sh && ./kdump_result.sh"
	LogPrint "DEBUG: ret_result: ${ret_result}."
	if ($ret_result) {
		$retVal = $Passed
		break
	}
	else {
		LogPrint "WARNING: Re-run kdump_result.sh after 6 seconds."
		Start-Sleep -S 6
		$timeout = $timeout - 6
		if ($timeout -eq 0) {
			Logprint "ERROR: Failed to run kdump_result.sh."
			DisconnectWithVIServer			
			return $Aborted
		}
	}
}


DisconnectWithVIServer
return $retVal

