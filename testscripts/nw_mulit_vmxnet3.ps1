###############################################################################
##
## Description:
## Add one more vmxnet3 network adapter
##
###############################################################################
##
## Revision:
## V1.0 - boyang - 08/29/2017 - Build script
##
###############################################################################

<#
.Synopsis
    Add one more vmxnet3 network adapter

.Description
    When VM alives, Add one more vmxnet3 network adapter, configure their ifcfg-ens192.cfg

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
$new_device_name = ""
$new_network_name = "VM Network"

#
# Confirm VM
#
$vmOut = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmOut)
{
    Write-Error -Message "nw_remove_vmxnet3.ps1: Unable to get-vm with $vmName" -Category ObjectNotFound -ErrorAction SilentlyContinue
	return $Aborted
}

#
# Hot plug two new NICs
# @total_nics: target nic number want to add
# @count: flag
# @new_nic_obj_x: every new nic object
#
$total_nics = 2
$count = 1
while ($count -le $total_nics)
{
    Write-Output "Now, is creating the $count NIC"
    $new_nic_obj_x = "new_nic_obj" + $count
    $new_nic_obj_x = New-NetworkAdapter -VM $vmOut -NetworkName $new_network_name -WakeOnLan -StartConnected -Confirm:$false
    
    Write-Host -F red "Get new NIC: $new_nic_obj_x"
    $count ++
}

#
# @all_nic_count: should own $total_nics + 1
#
$all_nic_count = (Get-NetworkAdapter -VM $vmOut).Count
Write-Host -F red "All NICs: $all_nic_count"
if ($all_nic_count -eq ($total_nics + 1))
{
    Write-Output "PASS: Hot plug vmxnet3 well"
}
else
{
    Write-Error -Message "FAIL: Unknow issue after hot plug adapter, check it manually" -Category ObjectNotFound -ErrorAction SilentlyContinue
    return $Aborted
}

#$result = SendCommandToVM $ipv4 $sshKey "cd /root && dos2unix nw_config_ifcfg.sh && chmod u+x nw_config_ifcfg.sh && ./nw_config_ifcfg.sh"
#if (-not $result)
#$exit = Start-Process bin\plink -ArgumentList "-i ssh\${sshKey} root@${ipv4} cd /root && dos2unix nw_config_ifcfg.sh && chmod u+x nw_config_ifcfg.sh && ./nw_config_ifcfg.sh" -NoNewWindow -Wait -PassThru
#$exit = Start-Process bin\plink -ArgumentList "-i ssh\${sshKey} root@${ipv4} ls /root/" -NoNewWindow -Wait -PassThru
$process = Start-Process bin\plink -ArgumentList "-i ssh\${sshKey} root@${ipv4} ls /root/" -Wait -PassThru -WindowStyle Hidden
$state = $process.ExitCode
Write-Host -F red "Debug: $state"
if ($state -ne 0)
{
	Write-Output "FAIL: Failed to execute nw_config_ifcfg.sh in VM."
	DisconnectWithVIServer
	return $Aborted
}
else
{
    $retVal = $Passed
}

DisconnectWithVIServer

return $retVal