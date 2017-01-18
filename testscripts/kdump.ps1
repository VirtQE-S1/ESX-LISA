###############################################################################
##
## Fork from github.com/LIS/lis-test, make it work with VMware ESX testing
##
## All rights reserved.
## Licensed under the Apache License, Version 2.0 (the ""License"");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##     http://www.apache.org/licenses/LICENSE-2.0
##
## THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS
## OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
## ANY IMPLIED WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR
## PURPOSE, MERCHANTABLITY OR NON-INFRINGEMENT.
##
## See the Apache Version 2.0 License for specific language governing
## permissions and limitations under the License.
##
###############################################################################
##
## Revision:
## v1.0 - boyang - 01/03/2017 - Crash_Single_Size, Crash_SMP, Crash_Auto_Size
## v1.1 - boyang - 01/06/2017 - Valid all test parameters.
## V1.2 - boyang - 01/08/2017 - Add new case Test Crash_Diff_size
## V1.3 - boyang - 01/09/2017 - Add description for kdump.ps1
## V1.4 - boyang - 01/10/2017 - Use WaitForVMToStartSSH and GetFileFromVM
##
###############################################################################

###############################################################################
##
## Description:
##  Push and execute kdump_config.sh, kdump_execute.sh, kdump_results.sh in VM
##  Trigger kdump successfully and get vmcore
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
    "Error: VM name cannot be null!"
    exit
}

if (-not $hvServer)
{
    "Error: hvServer cannot be null!"
    exit
}

if (-not $testParams)
{
    Throw "Error: No test parameters specified"
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
    "Error: Test parameter sshKey was not specified"
    return $False
}

if ($null -eq $ipv4) {
    "Error: Test parameter ipv4 was not specified"
    return $False
}

if ($null -eq $crashkernel) {
    "Error: Test parameter crashkernel was not specified"
    return $False
}

if ($null -eq $logdir) {
    "Error: Test parameter logdir was not specified"
    return $False
}

if ($null -eq $tcCovered) {
    "Error: Test parameter tcCovered was not specified"
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
# Put your test script here
# NOTES:
# 1. Please check testParams first according to your case requirement
# 2. Please close VI Server connection at the end of your test but
#    before return cmdlet by useing function - DisconnectWithVIServer
#
###############################################################################

#
# Sending required scripts to VM for generating kernel panic with appropriate permissions
#
Write-Host -F DarkGray "kdump.ps1: Start to send kdump_config.sh to VM......."
$retVal = SendFileToVM $ipv4 $sshKey ".\remote-scripts\kdump_config.sh" "/root/kdump_config.sh"
if (-not $retVal)
{
    Write-Output "Error: Failed to send kdump_config.sh to VM."
    return $false
}
Write-Output "Success: Send kdump_config.sh to VM."
Write-host -F Green "kdump.ps1: Success: Send kdump_config.sh to VM......."

#
# SendCommandToVM: execute kdump_config.sh
#
Write-Host -F DarkGray "kdump.ps1: Start to execute kdump_config.sh in VM......."
$retVal = SendCommandToVM $ipv4 $sshKey "cd /root && dos2unix kdump_config.sh && chmod u+x kdump_config.sh && ./kdump_config.sh $crashkernel"
if (-not $retVal)
{
    Write-Output "Error: Failed to execute kdump_config.sh in VM."
    return $false
}
Write-Output "Success: Execute kdump_config.sh in VM."
Write-host -F Green "kdump.ps1: Success: Execute kdump_config.sh in VM......."

#
# Rebooting the VM in order to apply the kdump settings
#
$retVal = SendCommandToVM $ipv4 $sshKey "reboot"
if (-not $retVal)
{
    Write-Output "Error: Failed to reboot VM."
    return $false
}
Write-Output "Rebooting the VM."

#
# Waiting the VM to start up
#
Write-Output "Waiting the VM to have a connection..."
Write-Host -F DarkGray "kdump.ps1: Waiting the VM to have a connection......."
#WaitForVMToStartSSH $ipv4 180 -> Will failed below function
Start-Sleep -S 240

#
# Sending required scripts to VM for generating kernel panic with appropriate permissions
#
Write-Host -F DarkGray "kdump.ps1: Start to send kdump_execute.sh to VM......."
$retVal = SendFileToVM $ipv4 $sshKey ".\remote-scripts\kdump_execute.sh" "/root/kdump_execute.sh"
if (-not $retVal)
{
    Write-Output "Error: Failed to send kdump_execute.sh to VM."
    return $false
}
Write-Output "Success: Send kdump_execute.sh to VM."
Write-host -F Green "kdump.ps1: Success: Send kdump_execute.sh to VM......."

#
# SendCommandToVM: execute kdump_config.sh
#
Write-Host -F DarkGray "kdump.ps1: Start to execute kdump_execute.sh in VM......."
$retVal = SendCommandToVM $ipv4 $sshKey "cd /root && dos2unix kdump_execute.sh && chmod u+x kdump_execute.sh && ./kdump_execute.sh"
if (-not $retVal)
{
    Write-Output "Error: Failed to execute kdump_execute.sh to VM."
    return $false
}
Write-Output "Success: Execute kdump_execute.sh to VM."
Write-host -F Green "kdump.ps1: Success: Execute kdump_execute.sh in VM......."

#
# Get summary.log
#
Write-Host -F DarkGray "kdump.ps1: Start to get summary.log from VM......."
$retVal = GetFileFromVM $ipv4 $sshKey "summary.log" $logdir
if (-not $retVal)
{
    Write-Output "Error: Failed to get summary.log from VM."
    return $false
}
Write-Output "Success: Get summary.log from VM."
Write-Host -F Green "kdump.ps1: Success: Get summary.log from VM......."

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
        Write-Output "Error: Failed to trigger kdump in VM."
        return $false
    }
    Write-Output "Success: Trigger kdump well in VM."
    Write-host -F Green "kdump.ps1: Success: Trigger kdump well in VM......"
}

#
# Give the host a few seconds to record the event
#
Write-Output "Waiting 180 seconds to record the kdump event..."
Write-Host -F DarkGray "kdump.ps1: Waiting 200 seconds to record the kdump event..."
Start-Sleep -S 180


#
# Waiting the VM to have a connection; Or will use function WaiForVMToStartSSH()
#
Write-Output "Checking the VM connection after kernel panic..."
Write-Host -F DarkGray "kdump.ps1: Checking the VM connection after kernel panic......."
#WaitForVMToStartSSH $ipv4 180
Start-Sleep -S 240

#
# Verifying if the kernel panic process creates a vmcore file of size 10M+
#
Write-Host -F DarkGray "Connection to VM is good. Checking the results..."
$vmobj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
$sta = $vmobj.PowerState
if ($sta -eq "PoweredOn") {
    Write-Host -F DarkGray "kdump.ps1: Start to send kdump_results.sh to VM......."
    $retVal = SendFileToVM $ipv4 $sshKey ".\remote-scripts\kdump_results.sh" "/root/kdump_results.sh"
    if (-not $retVal)
    {
        Write-Output "Error: Failed to send kdump_results.sh to VM."
        return $false
    }
    Write-Output "Success: send kdump_results.sh to VM."
    Write-host -F Green "kdump.ps1: Success: send kdump_results.sh to VM......."

    Write-Host -F DarkGray "kdump.ps1: Start to Execute kdump_results.sh......."
    $retVal = SendCommandToVM $ipv4 $sshKey "cd /root && dos2unix kdump_results.sh && chmod u+x kdump_results.sh && ./kdump_results.sh"
    if (-not $retVal)
    {
        Write-Output "Error: Failed to execute kdump_results.sh in VM."
        return $false
    }
    Write-Output "Success: execute kdump_results.sh in VM."
    Write-host -F Green "Success: execute kdump_results.sh in VM......."
}

return $retVal
