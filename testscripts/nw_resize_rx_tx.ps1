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
## V1.1 - boyang - 11/22/2017 - Update logical check
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

$retVal = $Failed

#
# Confirm VM
#
$vmOut = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmOut)
{
    Write-Host -F Yellow "ABORT: Unable to get-vm with $vmName"
    Write-Output "ABORT: Unable to get-vm with $vmName"        
    DisconnectWithVIServer
    return $Aborted
}

#
# Confirm NIC interface types. RHELs has different NIC types, like "eth0" "ens192:" "enp0s25:"
# After snapshot, defalut, vmxnet3 NIC works and MTU is 1500
#
$eth = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ls /sys/class/net/ | grep ^e[tn][hosp]"

#
# Check $eth Ring current RX, TX parameters
# For target RX, TX value = current RX TX value / 2
#
$rx_current = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ethtool -g $eth | grep ^RX: | awk 'NR==2{print `$2`}'"
Write-Host -F Gray "rx_current size is $rx_current"
Write-Output "rx_current szie is $rx_current"
$rx_other = $rx_current / 2
Write-Host -F Gray "rx_other size is $rx_other"
Write-Output "rx_other szie is $rx_other"

$tx_current = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ethtool -g $eth | grep ^TX: | awk 'NR==2{print `$2`}'"
Write-Host -F Gray "tx_current size is $tx_current"
Write-Output "tx_current szie is $tx_current"
$tx_other = $tx_current / 2
Write-Host -F Gray "tx_other size is $tx_other"
Write-Output "tx_other szie is $tx_other"

#
# Resize rx, tx to other value
#
$result = SendCommandToVM $ipv4 $sshKey "ethtool -G $eth rx $rx_other tx $tx_other"
if (-not $result)
{	
    Write-Host -F Red "FAIL: Resize rx, tx failed"
    Write-Output "FAIL: Resize rx, tx failed"
}
else
{

    Write-Host -F Gray "DONE. Resize rx, tx well"
    Write-Output "DONE. Resize rx, tx well"    
    
    Start-Sleep 6
    
    #
    # Confirm RX, TX other value is done
    #
    $rx_new = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ethtool -g $eth | grep ^RX: | awk 'NR==2{print `$2`}'"
    Write-Host -F Gray "rx_new is $rx_new"
    Write-Output "rx_new is $rx_new"
    if ($rx_new -eq $rx_other)
    {
        Write-Host -F Gray "DONE. New rx value is correct"
        Write-Output "DONE. New rx value is correct"
        
        $tx_new = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ethtool -g $eth | grep ^TX: | awk 'NR==2{print `$2`}'"
        Write-Host -F Gray "tx_new is $tx_new"
        Write-Output "tx_new is $tx_new"
        if ($tx_new -eq $tx_other)
        {
            Write-Host -F Green "PASS: New rx / tx values are correct"
            Write-Output "PASS: New rx / tx values are correct"               
            $retVal = $Passed
        }
        else
        {
            Write-Host -F Red "FAIL: New tx is incorrect"
            Write-Output "FAIL: New tx is incorrect"    
        }        
    }
    else
    {
        Write-Host -F Red "FAIL: New rx is incorrect"
        Write-Output "FAIL: New rx is incorrect"    
    }

}

DisconnectWithVIServer

return $retVal