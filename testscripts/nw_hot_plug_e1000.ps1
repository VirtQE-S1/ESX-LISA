###############################################################################
##
## Description:
## Hot plug and unplug the e1000 network adapter
##
###############################################################################
##
## Revision:
## V1.0 - boyang - 11/02/2017 - Build script
##
###############################################################################

<#
.Synopsis
    Hot plug and unplug the e1000 network adapter

.Description
    When VM alives, Hot plug and unplug vmxnet3, no crash
    <test>
        <testName>nw_hot_plug_unplug_e1000</testName>
        <testID>ESX-NW-012</testID>
        <testScript>testscripts\nw_hot_plug_unplug_e1000.ps1</testScript>
        <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
        <timeout>360</timeout>
        <testParams>
            <param>TC_COVERED=RHEL6-34954,RHEL7-50936</param>
        </testParams>
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
# "VM Network" is default value in vSphere
$new_nic_name = "VM Network" 

#
# Confirm VM
#
$vmOut = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmOut)
{
    Write-Error -Message "Unable to get-vm with $vmName" -Category ObjectNotFound -ErrorAction SilentlyContinue
	return $Aborted
}

#
# Hot plug one new adapter named $new_nic_name, DON'T test on original adapter, adapter count will be 2
# Hot unplug this new adapter named $new_nic_name, adapter count will be 1(original one)
#
$new_nic = New-NetworkAdapter -VM $vmOut -NetworkName $new_nic_name -Type e1000 -WakeOnLan -StartConnected -Confirm:$false
Write-Output "Get new NIC: $new_nic."

$all_nic_count = (Get-NetworkAdapter -VM $vmOut).Count
if ($all_nic_count -eq 2)
{
    Write-Output "PASS: Hot plug e1000 well"
    $retVal = $Passed
}
else
{
    Write-Error -Message "FAIL: Unknow issue after hot plug adapter, check it manually" -Category ObjectNotFound -ErrorAction SilentlyContinue
}

DisconnectWithVIServer

return $retVal