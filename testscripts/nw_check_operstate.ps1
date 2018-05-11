###############################################################################
##
## Description:
##  Check NIC operstate when ifup / ifdown
##
## Revision:
##  v1.0.0 - boyang - 08/31/2017 - Build the script
##  v1.0.1 - boyang - 05/10/2018 - Enhance the script in debug info
##
###############################################################################


<#
.Synopsis
    Check NIC operstate when ifup / ifdown

.Description
    Check NIC operstate when ifup / ifdown, operstate owns up / down states

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
$new_network_name = "VM Network"

#
# Confirm VM
#
$vmOut = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmOut)
{
    Write-Host -F Red "ERROR: Unable to Get-VM with $vmName"
    Write-Output "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
	return $Aborted
}


#
# Hot plug a new NIC
#
Write-Host -F Red "INFO: Is adding a new NIC"
Write-Output "INFO: Is adding a new NIC"
$new_nic_obj_x = New-NetworkAdapter -VM $vmOut -NetworkName $new_network_name -WakeOnLan -StartConnected -Confirm:$false
Write-Host -F Red "DEBUG: new_nic_obj_x: $new_nic_obj_x"
Write-Output "DEBUG: new_nic_obj_x: $new_nic_obj_x"


# Confirm NIC count
$all_nic_count = (Get-NetworkAdapter -VM $vmOut).Count
Write-Host -F Red "DEBUG: all_nic_count: $all_nic_count"
Write-Output "DEBUG: all_nic_count: $all_nic_count"
if ($all_nic_count -ne 2)
{
    Write-Host -F Red "ERROR: Hot plug vmxnet3 failed"
    Write-Output "ERROR: Hot plug vmxnet3 failed"
    DisconnectWithVIServer
    return $Aborted
}
Write-Host -F Red "INFO: Hot plug vmxnet3 done"
Write-Output "INFO: Hot plug vmxnet3 done"


#
# Send nw_config_ifcfg.sh to VM which setup new NIC ifcfg file, ifdown / ifup to check operstate
#
#$result = SendCommandToVM $ipv4 $sshKey "cd /root && dos2unix nw_check_operstate.sh && chmod u+x nw_check_operstate.sh && ./nw_check_operstate.sh"
$process = Start-Process bin\plink -ArgumentList "-i ssh\${sshKey} root@${ipv4} cd /root && dos2unix nw_check_operstate.sh && chmod u+x nw_check_operstate.sh && ./nw_check_operstate.sh" -WindowStyle Hidden -Wait -PassThru
$exit_code = $process.ExitCode
if ($exit_code -eq 0)
{
    Write-Host -F Red "PASS: Complete to execute nw_check_operstate.sh in VM"
	Write-Output "PASS: Complete to execute nw_check_operstate.sh in VM"
    $retVal = $Passed
}
else
{
    Write-Host -F Red "FAIL: Failed to execute nw_check_operstate.sh in VM"
    Write-Output "FAIL: Failed to execute nw_check_operstate.sh in VM"
}


DisconnectWithVIServer
return $retVal
