###############################################################################
##
## Description:
## Add CD driver to guest and check the cd file in guest.
##
###############################################################################
##
## Revision:
##
## V1.0 - ldu - 08/01/2018 - Add CD driver to guest and check the cd file in guest.
## V1.1 - ldu - 06/26/2019 - update cd file name
##
###############################################################################

<#
.Synopsis
    Add CD driver to guest and check the cd file in guest.
.Description
<test>
    <testName>stor_check_cd_file</testName>
    <testID>ESX-Stor-016</testID>
    <setupScript>setupscripts\add_CDDrive.ps1</setupScript>
    <testScript>testscripts\stor_check_cd_file.ps1</testScript>
    <testParams>
        <param>cd_num=2</param>
        <param>iso=[trigger] tmp/cloud-init.iso</param>
        <param>TC_COVERED=RHEL6-49145,RHEL7-111400</param>
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

# $cd = Set-CDDrive -CD $a -ISOPath "[trigger] tmp/cloud-init.iso" -Connected:true

#
# Check the CD number of the guest.
#
$CDList =  Get-CDDrive -VM $vmObj
$CDLength = $CDList.Length

if ($CDLength -eq $cd_num)
{
    write-host -F Red "The cd count is $CDLength "
    Write-Output "Add cd successfully"
}
else
{
    write-host -F Red "The cd count is $CDLength "
    Write-Output "Add cd during setupScript Failed, only $CDLength cd in guest."
    DisconnectWithVIServer
    return $Aborted
}

$result = SendCommandToVM $ipv4 $sshKey "mount /dev/cdrom /mnt && cat /mnt/user-data.txt"
if (-not $result)
{
	Write-Host -F Red "FAIL: Failed to execute cat /mnt/user-data in VM"
	Write-Output "FAIL: Failed to execute cat /mnt/user-data in VM"
	DisconnectWithVIServer
	return $Aborted
}
else
{
	Write-Host -F Green "PASS: Execute cat /mnt/user-data in VM successfully"
	Write-Output "PASS: Execute cat /mnt/user-data in VM successfully"
    $retVal = $Passed
}


DisconnectWithVIServer

return $retVal
