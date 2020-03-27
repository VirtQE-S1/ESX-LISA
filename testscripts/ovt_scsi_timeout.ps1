########################################################################################
## Description:
## 	Check the scsi timeout value is 180.
##
## Revision:
## 	v1.0.0 - ldu - 03/05/2018 - Check the scsi timeout value is 180.
########################################################################################


<#
.Synopsis
    Check the scsi timeout value is 180.
.Description
<test>
    <testName>ovt_scsi_timeout</testName>
    <testID>ESX-STOR-009</testID>
    <testScript>testscripts\ovt_scsi_timeout.ps1</testScript>
    <testParams>
        <param>TC_COVERED=RHEL6-47887,RHEL7-94310</param>
    </testParams>
    <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
    <timeout>300</timeout>
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


# Checking the input arguments
param([String] $vmName, [String] $hvServer, [String] $testParams)
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

# Output test parameters so they are captured in log file
"TestParams : '${testParams}'"


# Parse test parameters
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


# Check all parameters are valid
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


# Source tcutils.ps1
. .\setupscripts\tcutils.ps1

PowerCLIImport
ConnectToVIServer $env:ENVVISIPADDR `
                  $env:ENVVISUSERNAME `
                  $env:ENVVISPASSWORD `
                  $env:ENVVISPROTOCOL


########################################################################################
# Main Body
########################################################################################
$retVal = $Failed


# OVT is skipped in RHEL6
$OS = GetLinuxDistro  $ipv4 $sshKey
if ($OS -eq "RedHat6")
{
    DisconnectWithVIServer
    return $Skipped
}


# Check the scsi timeout value in two files.
$scsi_timeout = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "cat /sys/block/sda/device/timeout | grep 180"
LogPrint "DEBUG: scsi_timeout: ${scsi_timeout}."


$udev_timeout = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "cat /usr/lib/udev/rules.d/99-vmware-scsi-udev.rules | grep 180"
LogPrint "DEBUG: udev_timeout: ${udev_timeout}."
if ($udev_timeout -and $scsi_timeout)
{
    LogPrint "INFO: The scsi timeout values are ${scsi_timeout} and ${udev_timeout}."
    $retVal = $Passed
}
else{
    Write-Output "INFO: The scsi timeout values are not 180, The actual values are $scsi_timeout and ${udev_timeout}."
}


DisconnectWithVIServer
return $retVal
