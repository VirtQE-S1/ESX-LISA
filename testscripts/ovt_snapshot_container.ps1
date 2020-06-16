########################################################################################
## Description:
## 	Take snapshot when container running.
##
## Revision:
## 	v1.0.0 - ldu - 07/25/2018 - Take snapshot when container running.
## 	v2.0.0 - ldu - 03/12/2020 - Update podman install command.
## 	v2.0.1 - ldu - 03/12/2020 - Modifiy the container registry config file.
########################################################################################


<#
.Synopsis
    Take snapshot when container running.
.Description
<test>
    <testName>ovt_snapshot_container</testName>
    <testID>ESX-OVT-033</testID>
    <testScript>testscripts/ovt_snapshot_container.ps1</testScript  >
    <files>remote-scripts/utils.sh</files>
    <files>remote-scripts/ovt_docker_install.sh</files>
    <testParams>
        <param>TC_COVERED=RHEL6-51216,RHEL7-135106</param>
    </testParams>
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


# Install podman and add docker.io to container registries config file.
$sts = SendCommandToVM $ipv4 $sshKey "yum install podman -y && sed -i 's/registry.access.redhat.com/docker.io/g' /etc/containers/registries.conf" 
LogPrint "DEBUG: sts: ${sts}."
if (-not $sts) {
    LogPrint "ERROR: YUM cannot install podman packages."
    DisconnectWithVIServer
    return $Failed
}


# Run one network container in guest.
$run = SendCommandToVM $ipv4 $sshKey "podman run -P -d nginx" 
LogPrint "DEBUG: run: ${run}."
if (-not $sts) {
    LogPrint "ERROR: run container nginx failed in guest."
    DisconnectWithVIServer
    return $Failed
}


# Take snapshot and select quiesce option.
$snapshotTargetName = "snapcontainer"
$new_sp = New-Snapshot -VM $vmObj -Name $snapshotTargetName -Quiesce:$true -Confirm:$false
$newSPName = $new_sp.Name
LogPrint "DEBUG: newSPName: ${newSPName}."
if ($new_sp)
{
    if ($newSPName -eq $snapshotTargetName)
    {
        LogPrint "INFO: The snapshot $newSPName with Quiesce is created successfully"
        $retVal = $Passed
    }
    else
    {
        LogPrint "INFO：The snapshot $newSPName with Quiesce is created Failed"
    }
}


Start-Sleep -S 6


# Remove SP created.
$remove = Remove-Snapshot -Snapshot $new_sp -RemoveChildren -Confirm:$false
$snapshots = Get-Snapshot -VM $vmObj -Name $new_sp
LogPrint "DEBUG: snapshots: ${snapshots}."
if ($snapshots -eq $null)
{
    LogPrint "INFO: The snapshot has been removed successfully."
}
else
{
    LogPrint "INFO: The snapshot removed failed."
    return $Aborted
}


DisconnectWithVIServer
return $retVal
