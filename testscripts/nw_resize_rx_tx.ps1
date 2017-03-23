###############################################################################
##
## Description:
## Check NIX's RX and TX current value,
## Resize NIC's RX and TX to other value
##
###############################################################################
##
## Revision:
## V1.0 - boyang - 03/22/2017 - Build script
##
###############################################################################

<#
.Synopsis
    Check and resize NIC's RX and TX to MAX value

.Description
    User can check and resize NIC's RX and TX to other value

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

$rx_value = 1023
$tx_vaule = 1023

#
# Confirm NIC interface types. RHELs has different NIC types, like "eth0" "ens192:" "enp0s25:"
#
$eth_temp = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ifconfig | grep ^e[tn][hps]"
$eth = $eth_temp | awk '{print $1}' | awk -F : '{print $1}'

$retVal = SendCommandToVM $ipv4 $sshKey "ping $hvServer -I $eth -c 4"
if (-not $retVal)
{
	Write-Output "FAIL: $eth doesn't work."
	Write-Host -F Red "nw_resize_rx_tx_max.ps1: FAIL: $eth doesn't work........"
	return $Failed
}

#
# Confirm MTU value of NIC is 1500, RHEL6.X and RHEL7.X hasve the different ifconfig output for MTU
#
$DISTRO = GetLinuxDistro $ipv4 $sshKey
if ($DISTRO -eq "RedHat6")
{
	$mtu_temp = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ifconfig $eth | grep MTU"
	$mtu = $mtu_temp | awk -F : '{print $2}' | awk '{print $1}'
}
if ($DISTRO -eq "RedHat7")
{
	$mtu_temp = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ifconfig $eth | grep mtu"
	$mtu = $mtu_temp | awk '{print $4}'
}
if ($mtu -ne 1500)
{
	Write-Output "FAIL: $mtu isn't equal 1500."
	Write-Host -F Red "nw_resize_rx_tx.ps1: FAIL: $mtu isn't equal 1500........."
	return $Failed
}

#
# Check $eth Ring current RX, TX parameters
#
$rx_current_temp = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ethtool -g $eth | grep ^RX:"
$rx_current = $rx_current_temp | awk 'NR==2{print $2}'

$tx_current_temp = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ethtool -g $eth | grep ^TX:"
$tx_current = $tx_current_temp | awk 'NR==2{print $2}'

#
# Resize rx, tx to other value
#
$retVal = SendCommandToVM $ipv4 $sshKey "ethtool -G $eth rx $rx_value tx $tx_vaule"
if (-not $retVal)
{
	Write-Output "FAIL: Resize rx, tx failed."
	Write-Host -F Red "nw_resize_rx_tx.ps1: FAIL: Resize rx, tx failed........"
	return $Failed
}

#
# Confirm RX, TX other value is done
#
$rx_new_temp = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ethtool -g $eth | grep ^RX:"
$rx_new = $rx_new_temp | awk 'NR==2{print $2}'
if ($rx_new -eq $rx_current)
{
	Write-Output "FAIL: Resize rx failed."
	Write-Host -F Red "nw_resize_rx_tx.ps1: FAIL: Resize rx failed........."
	return $Failed
}

$tx_new_temp = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ethtool -g $eth | grep ^TX:"
$tx_new = $tx_new_temp | awk 'NR==2{print $2}'
if ($tx_new -eq $tx_current)
{
	Write-Output "FAIL: Resize tx failed."
	Write-Host -F Red "nw_resize_rx_tx.ps1: FAIL: Resize tx failed........."
	return $Failed
}

#
# Confirm NIC which RX, TX are MAX works
#
$retVal = SendCommandToVM $ipv4 $sshKey "ping $hvServer -I $eth -c 4"
if (-not $retVal)
{
	Write-Output "FAIL: $eth with new RX, TX doesn't work."
	Write-Host -F Red "nw_resize_rx_tx.ps1: FAIL: $eth with new RX, TX doesn't work........"
	return $Failed
}

DisconnectWithVIServer

return $retVal