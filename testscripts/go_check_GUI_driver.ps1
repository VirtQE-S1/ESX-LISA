###############################################################################
##
## Description:
## Check the vmware driver xorg-x11-drv-vmware exist in guest.
##
###############################################################################
##
## Revision:
## V1.0.0 - ldu - 05/20/2019 - Check the vmware driver xorg-x11-drv-vmware exist in guest.
##
##
###############################################################################

<#
.Synopsis
    Check the vmware driver xorg-x11-drv-vmware exist in guest.
.Description

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
        "VMMemory"     { $mem = $fields[1].Trim() }
        "standard_diff"{ $standard_diff = $fields[1].Trim() }
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


# Check the vmware driver xorg-x11-drv-vmware exist.
$vmware_driver = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "rpm -qa xorg-x11-drv-vmware"
Write-Host -F Red "driver result is $vmware_driver"

if ($vmware_driver -eq $null)
{
	Write-Output "Failed:The no vmware gui related driver xorg-x11-drv-vmware found in guest.$vmware_driver"
}
else{
    Write-Output "passed, the vmware driver xorg-x11-drv-vmware exist, $vmware_driver."
    $retVal = $Passed
}


DisconnectWithVIServer

return $retVal

