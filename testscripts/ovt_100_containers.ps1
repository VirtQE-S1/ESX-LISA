########################################################################################
## Description:
## 	Check guest vmware-vmsvc.log, dmesg log when 100 containers running.
##
## Revision:
## 	v1.0.0 - ldu - 07/28/2018 - Check guest log when 100 containers running.
## 	v1.0.1 - boyang - 12/18/2019 - Enhance errors check.
########################################################################################


<#
.Synopsis
    Check guest vmware-vmsvc.log, dmesg log when 100 containers running..
.Description

.Parameter vmName
    Name of the test VM.
.Parameter hvServer
    Name of the VIServer hosting the VM.
.Parameter testParams
    Semicolon separated list of test parameters.
#>


param([String] $vmName, [String] $hvServer, [String] $testParams)


# Checking the input arguments
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


# Skip RHEL6, as not support OVT on RHEL6.
$DISTRO = GetLinuxDistro ${ipv4} ${sshKey}
if ( $DISTRO -eq "RedHat6" ){
    DisconnectWithVIServer
    return $Skipped
}


# Get the VM
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName


# Install docker and start one network container on guest.
$sts = SendCommandToVM $ipv4 $sshKey "yum install -y podman" 
if (-not $sts) {
    LogPrint "ERROR : YUM install podman packages failed"
    DisconnectWithVIServer
    return $Failed
}


# Run 100 containers in guest.
for ($i = 0; $i -le 100; $i++)
{
    $sts = SendCommandToVM $ipv4 $sshKey "podman run --name $i -it -P -d centos /bin/bash" 
    if (-not $sts) {
        LogPrint "ERROR : run container centos failed in guest"
        DisconnectWithVIServer
        return $Failed
    }
}


Start-Sleep -S 30


# Check the /var/log/vmware-vmsvc.log log file.
$calltrace_check = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "cat /var/log/vmware-vmsvc.log | grep 'NIC limit (16) reached'"
if ($null -eq $calltrace_check)
{
    Write-host -F Red "INFO: After cat file /var/log/vmware-vmsvc.log, NO NIC limit (16) reached log found."
    Write-Output "INFO: After cat file /var/log/vmware-vmsvc.log, NO NIC limit (16) reached found."
}
else{
    Write-Output "ERROR: After, FOUND NIC limit (16) reached in /var/log/vmware-vmsvc.log."
    return $Failed
}


# Check the call trace in dmesg file
$status = CheckCallTrace $ipv4 $sshKey
if (-not $status[-1]) {
    Write-Host -F Red "ERROR: Found $($status[-2]) in msg."
    Write-Output "ERROR: Found $($status[-2]) in msg."
    DisconnectWithVIServer
    return $Failed
}
else {
    Write-Host -F Red "INFO: NO call trace found after 100 containers."
    Write-Output "INFO: NO call trace found after 100 containers."
    $retVal = $Passed
}


DisconnectWithVIServer
return $retVal
