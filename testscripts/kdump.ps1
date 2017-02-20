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
$tcCovered = "undefined"
$retVal = $false

$params = $testParams.Split(";")
foreach ($p in $params) {
    $fields = $p.Split("=")
    switch ($fields[0].Trim()) {
        "rootDir"   { $rootDir = $fields[1].Trim() }
        "sshKey" { $sshKey  = $fields[1].Trim() }
        "ipv4"   { $ipv4    = $fields[1].Trim() }
        "crashkernel"   { $crashkernel    = $fields[1].Trim() }
        "TestLogDir" {$logdir = $fields[1].Trim()}
        "NMI" {$nmi = $fields[1].Trim()}
        "TC_COVERED"   { $tcCovered = $fields[1].Trim() }
        default  {}
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

if ($null -eq $sshKey) {
    "FAIL: Test parameter sshKey was not specified"
    return $False
}

if ($null -eq $ipv4) {
    "FAIL: Test parameter ipv4 was not specified"
    return $False
}

if ($null -eq $crashkernel) {
    "FAIL: Test parameter crashkernel was not specified"
    return $False
}

if ($null -eq $logdir) {
    "FAIL: Test parameter logdir was not specified"
    return $False
}

if ($null -eq $tcCovered) {
    "FAIL: Test parameter tcCovered was not specified"
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
# Send kdump_config.sh script to VM for configuring kdump.conf and grub.conf
#
Write-Host -F DarkGray "kdump.ps1: Start to send kdump_config.sh to VM......."
$retVal = SendFileToVM $ipv4 $sshKey ".\remote-scripts\kdump_config.sh" "/root/kdump_config.sh"
if (-not $retVal)
{
    Write-Output "FAIL: Failed to send kdump_config.sh to VM."
    Write-Host -F Red "FAIL: Failed to send kdump_config.sh to VM."
    return $false
}
Write-Output "SUCCESS: Send kdump_config.sh to VM."
Write-host -F Green "kdump.ps1: SUCCESS: Send kdump_config.sh to VM......."

#
# SendCommandToVM: execute kdump_config.sh
#
Write-Host -F DarkGray "kdump.ps1: Start to execute kdump_config.sh in VM......."
$retVal = SendCommandToVM $ipv4 $sshKey "cd /root && dos2unix kdump_config.sh && chmod u+x kdump_config.sh && ./kdump_config.sh $crashkernel"
if (-not $retVal)
{
    Write-Host -F Red "FAIL: Failed to execute kdump_config.sh to VM."
    Write-Output "FAIL: Failed to execute kdump_config.sh in VM."
    return $false
}
Write-Output "SUCCESS: Execute kdump_config.sh in VM."
Write-host -F Green "kdump.ps1: SUCCESS: Execute kdump_config.sh in VM......."

#
# Get kdump_config_summary.log
#
Write-Host -F DarkGray "kdump.ps1: Start to get summary.log from VM......."
$retVal = GetFileFromVM $ipv4 $sshKey "summary.log" $logdir\${tcCovered}_kdump_config_summary.log
if (-not $retVal)
{
    Write-Host -F Red "FAIL: Failed to get config summary.log to VM."
    Write-Output "FAIL: Failed to get config summary.log from VM."
    return $false
}
Write-Output "SUCCESS: Get ${tcCovered}_kdump_config_summary.log from VM."
Write-Host -F Green "SUCCESS: Get ${tcCovered}_kdump_config_summary.log from VM."


#
# Rebooting the VM in order to apply the kdump settings
#
#$vmobj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
$retVal = Restart-VM -VM $vmName -Confirm:$false
if (-not $retVal)
{
    Write-Host -F Red "FAIL: Failed to reboot."
    return $retVal
}
else
{
	Write-Output "Rebooting the VM."
	Write-host -F Green "kdump.ps1: SUCCESS: Reboot VM......."
}

#
# Waiting the VM to start up
#
Write-Output "Waiting the VM to have a connection."
Write-Host -F DarkGray "kdump.ps1: Waiting the VM to have a connection......."
#WaitForVMToStartSSH $ipv4 120 ---> Seem it doesn't work, Will failed below function
$timeout = 120
while ($timeout -gt 0)
{
	
	Write-Output "During Reboot, now start to call GetIPv4 to get IP..."
	Write-Host -F Yellow "kdump.ps1: During reboot, now start to call GetIPv4 to get IP..."
	$retVal = GetIPv4 $vmName $hvServer
	if (-not $retVal)
	{
		Write-Host -F Red "WARNING: GetIPv4 failed, will check again..."
		Write-Host -F Red "Now, Will check again after 10s..."
		Start-Sleep -S 10
		$timeout = $timeout - 10
	}
	else
	{
		Write-Host -F Green "kdump.ps1: GetIPv4 return $retVal..."
		break
	}	
}

#
# Send kdump_execute.sh script to VM for checking kdump status after reboot
#
Write-Host -F DarkGray "kdump.ps1: Start to send kdump_execute.sh to VM......."
$retVal = SendFileToVM $ipv4 $sshKey ".\remote-scripts\kdump_execute.sh" "/root/kdump_execute.sh"
if (-not $retVal)
{
    Write-Host -F Red "FAIL: Failed to send kdump_execute,.sh to VM."
    Write-Output "FAIL: Failed to send kdump_execute.sh to VM."
    return $false
}
Write-Output "SUCCESS: Send kdump_execute.sh to VM."
Write-host -F Green "kdump.ps1: SUCCESS: Send kdump_execute.sh to VM......."

#
# SendCommandToVM: execute kdump_config.sh
#
Write-Host -F DarkGray "kdump.ps1: Start to execute kdump_execute.sh in VM......."
$retVal = SendCommandToVM $ipv4 $sshKey "cd /root && dos2unix kdump_execute.sh && chmod u+x kdump_execute.sh && ./kdump_execute.sh"
if (-not $retVal)
{
    Write-Host -F Red "FAIL: Failed to execute send kdump_execute.sh in VM."
    Write-Output "FAIL: Failed to execute kdump_execute.sh in VM."
    return $false
}
Write-Output "SUCCESS: Execute kdump_execute.sh to VM."
Write-host -F Green "kdump.ps1: SUCCESS: Execute kdump_execute.sh in VM......."

#
# Get kdump_execute_summary.log
#
Write-Host -F DarkGray "kdump.ps1: Start to get summary.log from VM......."
$retVal = GetFileFromVM $ipv4 $sshKey "summary.log" $logdir\${tcCovered}_kdump_execute_summary.log
if (-not $retVal)
{
    Write-Host -F Red "FAIL: Failed to get execute summary.log from VM."
    Write-Output "FAIL: Failed to get execute summary.log from VM."
    return $false
}
Write-Output "SUCCESS: Get ${tcCovered}_kdump_execute_summary.log from VM."
Write-Host -F Green "SUCCESS: Get ${tcCovered}_kdump_execute_summary.log from VM."

#
# Trigger the kernel panic
#
Write-Output "Trigger the kernel panic..."
Write-Host -F DarkGray "kdump.ps1: Trigger the kernel panic from PS......."
if ($nmi -eq 1){
    Write-Output "Will use NMI to trigger kdump"
    # No function supports NMI trigger
    Start-Sleep -S 70
}
else {
    Write-Host -F DarkGray "echo c to trigger kdump  from PS......."
    $retVal = SendCommandToVM $ipv4 $sshKey "echo 'echo c > /proc/sysrq-trigger' | at now + 1 minutes"
    if (-not $retVal)
    {
        Write-Output "FAIL: Failed to trigger kdump in VM."
        return $false
    }
    Write-Output "SUCCESS: Trigger kdump well in VM."
    Write-host -F Green "kdump.ps1: SUCCESS: Trigger kdump well in VM......"
}

#
# Give the host a few seconds to record the event
#
Write-Output "Waiting 180 seconds to record the kdump event..."
Write-Host -F DarkGray "kdump.ps1: Waiting 120 seconds to record the kdump event..."
Start-Sleep -S 120

#
# Waiting the VM to have a connection; Or will use function WaiForVMToStartSSH()
#
Write-Output "Checking the VM connection after kernel panic..."
Write-Host -F DarkGray "kdump.ps1: Checking the VM connection after kernel panic......."
#WaitForVMToStartSSH $ipv4 120 ---> Seem it doesn't work, Will failed below function
$timeout = 120
while ($timeout -gt 0)
{
	
	Write-Output "During Reboot, now start to call GetIPv4 to get IP..."
	Write-Host -F Yellow "kdump.ps1: During reboot, now start to call GetIPv4 to get IP..."
	$retVal = GetIPv4 $vmName $hvServer
	if (-not $retVal)
	{
		Write-Output "WARNING: GetIPv4 failed..."
		Write-Host -F Red "WARNING: GetIPv4 failed, will check again..."
		Write-Host -F Red "Now, Will check again after 10s..."
		Start-Sleep -S 10
		$timeout = $timeout - 10
	}
	else
	{
		Write-Host -F Green "kdump.ps1: GetIPv4 return $retVal..."
		break
	}	
}

#
# Verifying if the kernel panic process creates a vmcore file of size 10M+
#
Write-Host -F DarkGray "Connection to VM is good. Checking the result..."
$vmobj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
$sta = $vmobj.PowerState
if ($sta -eq "PoweredOn") {
	#
	# Send kdump_execute.sh script to VM for checking kdump status after reboot
	#
	Write-Host -F DarkGray "kdump.ps1: Start to send kdump_result.sh to VM......."
	$retVal = SendFileToVM $ipv4 $sshKey ".\remote-scripts\kdump_result.sh" "/root/kdump_result.sh"
	if (-not $retVal)
	{
	    Write-Output "FAIL: Failed to send kdump_result.sh to VM."
	    Write-Output "FAIL: Failed to send kdump_result.sh to VM."
	    return $false
	}
	Write-Output "SUCCESS: send kdump_result.sh to VM."
	Write-host -F Green "kdump.ps1: SUCCESS: send kdump_result.sh to VM......."
	
	#
	# SendCommandToVM: execute kdump_result.sh
	#
	Write-Host -F DarkGray "kdump.ps1: Start to Execute kdump_result.sh......."
	$retVal = SendCommandToVM $ipv4 $sshKey "cd /root && dos2unix kdump_result.sh && chmod u+x kdump_result.sh && ./kdump_result.sh"
	if (-not $retVal)
	{
	    Write-Output "FAIL: Failed to execute kdump_result in VM."
	    Write-Output "FAIL: Failed to execute kdump_result.sh in VM."
	    return $false
	}
	Write-Output "SUCCESS: execute kdump_result.sh in VM."
	Write-host -F Green "SUCCESS: execute kdump_result.sh in VM......."

	#
	# Get kdump_execute_summary.log
	#
	Write-Host -F DarkGray "kdump.ps1: Start to get summary.log from VM......."
	$retVal = GetFileFromVM $ipv4 $sshKey "summary.log" $logdir\${tcCovered}_kdump_result_summary.log
	if (-not $retVal)
	{
	    Write-Output "FAIL: Failed to get result summary.log from VM."
	    Write-Host -F Red "FAIL: Failed to get result summary.log from VM."
	    return $false
	}
	Write-Output "SUCCESS: Get ${tcCovered}_kdump_result_result.log from VM."
	Write-Host -F Green "SUCCESS: Get ${tcCovered}_kdump_result_summary.log from VM."

}

return $retVal
