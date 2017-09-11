###############################################################################
##
## Description:
##  Verify kvm clock adjusting
##
###############################################################################
##
## Revision:
## V1.0 - boyang - 01/18/2017 - Build script
##
###############################################################################

<#
.Synopsis
    Verify kvm clock adjusting

.Description
    Verify kvm clock adjusting when booting the VM

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
$target_error = "Adjusting kvm-clock more than"

$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if ($vmObj.PowerState -ne "PoweredOn")
{
    Write-Error -Message "CheckModules: Unable to create VM object for VM $vmName" -Category ObjectNotFound -ErrorAction SilentlyContinue
    return $Aborted
}
else
{
    #$adjusting_check = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "dmesg | grep 'Adjusting kvm-clock more than'"
    $adjusting_check = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "dmesg | grep '$target_error'"

    Write-Host -F red "$adjusting_check"
    if ($null -eq $adjusting_check)
    {
        Write-Output "PASS: After booting, NO $target_error found"
        $retVal = $Passed
    }
    else
    {
        Write-Output "FAIL: After booting, FOUND $target_error"
    }
}

DisconnectWithVIServer

return $retVal