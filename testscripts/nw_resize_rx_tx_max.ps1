###############################################################################
##
## Description:
## Check NIX's RX and TX current value, Check MAX value
## Resize NIC's RX and TX to MAX value
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
    User can check and resize NIC's RX and TX to MAX value

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
# Check $eth current Ring RX, TX parameters. 
# Defalut value isn't equal to MAX
#
$rx_current = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ethtool -g $eth | grep ^RX: | awk 'NR==2{print `$2`}'"
write-host -F Red "rx_current is $rx_current"

$tx_current = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ethtool -g $eth | grep ^TX: | awk 'NR==2{print `$2`}'"
write-host -F Red "tx_current is $tx_current"

#
# Get $eth RX, TX MAX value
#
$rx_max = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ethtool -g $eth | grep ^RX: | awk 'NR==1{print `$2`}'"
write-host -F Red "rx_max is $rx_max"

$tx_max = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ethtool -g $eth | grep ^TX: | awk 'NR==1{print `$2`}'"
write-host -F Red "tx_max is $tx_max"


#
# Resize rx, tx to MAX value
#
$result = SendCommandToVM $ipv4 $sshKey "ethtool -G $eth rx $rx_max tx $tx_max"
if (-not $result)
{
	Write-Output "FAIL: Resize rx, tx failed."
	DisconnectWithVIServer
	return $Aborted
}

#
# Confirm RX, TX MAX value is done
#
$rx_new = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ethtool -g $eth | grep ^RX: | awk 'NR==2{print `$2`}'"
write-host -F Red "rx_new is $rx_new"

if ($rx_new -eq $rx_max)
{
	Write-Output "PASS: Resize rx passed."
	$retVal = $Passed
}

$tx_new = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ethtool -g $eth | grep ^TX: | awk 'NR==2{print `$2`}'"
write-host -F Red "tx_new is $tx_new"

if ($tx_new -eq $tx_max)	
{
	Write-Output "PASS: Resize tx passed."
	$retVal = $Passed
}

#
# Confirm NIC which RX, TX are MAX works
#
$result = SendCommandToVM $ipv4 $sshKey "ping $hvServer -I $eth -c 4"
if (-not $result)
{
	Write-Output "FAIL: $eth with new MTU doesn't work."
	DisconnectWithVIServer
	return $Aborted
}

DisconnectWithVIServer

return $retVal