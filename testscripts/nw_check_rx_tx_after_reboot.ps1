###############################################################################
##
## Description:
## Check NIC's RX and TX after reboot
##
###############################################################################
##
## Revision:
## V1.0 - boyang - 10/23/2017 - Build script
##
###############################################################################

<#
.Synopsis
    Check NIC's RX and TX after reboot

.Description
    Change NIC's RX and TX, reboot, check again

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
# Confirm NIC interface types. RHELs has different NIC types, like "eth0" "ens192:" "enp0s25:"
# After snapshot, defalut, NIC works and MTU is 1500
#
$eth = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ls /sys/class/net/ | grep ^e[tn][hosp]"

#
# Check $eth Ring current RX, TX parameters
# For target RX, TX value = current RX TX value / 2
#
$rx_current = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ethtool -g $eth | grep ^RX: | awk 'NR==2{print `$2`}'"
Write-Host -F Gray "rx_current is $rx_current......."
Write-Output "rx_current is $rx_current"
$rx_other = $rx_current / 2
Write-Host -F Gray "rx_other is $rx_other......."
Write-Output "rx_other is $rx_other"

$tx_current = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ethtool -g $eth | grep ^TX: | awk 'NR==2{print `$2`}'"
Write-Host -F Gray "tx_current is $tx_current......."
Write-Output "tx_current is $tx_current"
$tx_other = $tx_current / 2
Write-Host -F Gray "tx_other is $tx_other......."
Write-Output "tx_other is $tx_other"

#
# Resize rx, tx to other value
#
$result = SendCommandToVM $ipv4 $sshKey "ethtool -G $eth rx $rx_other tx $tx_other"
if (-not $result)
{	Write-Host -F Red "WARNING: ethtool -G failed, abort......."
	Write-Output "WARNING: ethtool -G failed, abort"
	DisconnectWithVIServer
	return $Aborted
}

#
# Confirm RX, TX other value is done
#
$rx_new = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ethtool -g $eth | grep ^RX: | awk 'NR==2{print `$2`}'"
Write-Host -F Gray "rx_new is $rx_new"
Write-Output "rx_new is $rx_new"
if ($rx_new -ne $rx_other)
{
    Write-Host -F Gray "WARNING: Resize rx failed, abort......."
	Write-Output "WARNING: Resize rx failed, abort"
	DisconnectWithVIServer
	return $Aborted    
}

$tx_new = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ethtool -g $eth | grep ^TX: | awk 'NR==2{print `$2`}'"
Write-Host -F Gray "tx_new is $tx_new"
Write-Output "tx_new is $tx_new"
if ($tx_new -ne $tx_other)
{
    Write-Host -F Gray "WARNING: Resize tx failed, abort......."
	Write-Output "WARNING: Resize tx failed, abort"
	DisconnectWithVIServer
	return $Aborted        
}

#
# Reboot the VM, rx / tx should be = $rx_current / $tx_current
#
Write-Host -F Gray "Start to reboot VM after change rx / tx value......."
Write-Output "Start to reboot VM after change rx / tx value"
bin\plink.exe -i ssh\${sshKey} root@${ipv4} "init 6"

$timeout = 360
while ($timeout -gt 0)
{
    $vmObject = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
    $vmPowerState = $vmObject.PowerState
    Write-Host -F Gray "The VM power state is $vmPowerState......."        
    Write-Output "The VM B power state is $vmPowerState"
    if ($vmPowerState -eq "PoweredOn")
    {
        $ipv4 = GetIPv4 $vmName $hvServer
        Write-Host -F Gray "The VM ipv4 is $ipv4......."            
        Write-Output "The VM ipv4 is $ipv4"            
        if ($ipv4 -ne $null)
        {
            # Maybe the first some times, will fail as rx / tx not ready
            Start-Sleep -S 6
            $rx_after_reboot = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ethtool -g $eth | grep ^RX: | awk 'NR==2{print `$2`}'"
            
            $tx_after_reboot = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ethtool -g $eth | grep ^TX: | awk 'NR==2{print `$2`}'"
        
            if ($rx_after_reboot -eq $rx_current -and $tx_after_reboot -eq $tx_current)
            {
                Write-Host -F Green "PASS: After reboot, rx / tx returns to original value......."
                Write-Output "PASS: After reboot, rx / tx returns to original value"
                $retVal = $Passed
                break
            }
            else
            {
                Write-Host -F Red "FAIL: After reboot, rx / tx couldn't return to original value......."
                Write-Output "FAIL: After reboot, rx / tx couldn't return to original value"
            }
        }
    }
    Start-Sleep -S 6
    $timeout = $timeout - 6
    if ($timeout -eq 0)
    {
        Write-Host -F Yellow "WARNING: Timeout to reboot the VM, abort......."
        Write-Output "WARNING: Timeout to reboot the VM, abort"
        return $Aborted
    }
}

DisconnectWithVIServer

return $retVal