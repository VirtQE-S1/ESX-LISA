###############################################################################
##
## Description:
## Add more then one CD driver to guest.
##
###############################################################################
##
## Revision:
## 
## V1.0 - ldu - 07/23/2018 - Add more then one CD driver to guest.
##
###############################################################################

<#
.Synopsis
    Hot remove one scsi disk.
.Description
<test>
    <testName>stor_add_remove_cd</testName>
    <testID>ESX-Stor-013</testID>
    <setupScript>setupscripts\add_CDDrive.ps1</setupScript>
    <testScript>testscripts\stor_add_remove_cd.ps1</testScript>
    <testParams>
        <param>cd_num=3</param>
        <param>TC_COVERED=RHEL6-38505,RHEL7-80233</param>
    </testParams>
    <cleanupScript>SetupScripts\remove_CDDrive.ps1</cleanupScript>
    <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
    <timeout>600</timeout>
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
        "cd_num"        { $cd_num = $fields[1].Trim() }
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



# Get the VM
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName

#
# Check the CD number of the guest.
#
$CDList =  Get-CDDrive -VM $vmObj
$CDLength = $CDList.Length

if ($CDLength -eq $cd_num)
{
    write-host -F Red "The cd count is $CDLength "
    Write-Output "Add cd successfully"
    $retVal = $Passed
}
else
{
    write-host -F Red "The cd count is $CDLength "
    Write-Output "Add cd during setupScript Failed, only $CDLength cd in guest."
    DisconnectWithVIServer
    return $retVal
}

DisconnectWithVIServer

return $retVal
