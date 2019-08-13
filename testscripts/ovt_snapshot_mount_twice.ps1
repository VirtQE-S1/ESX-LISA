###############################################################################
##
## Description:
## Take snapshot when container running.
##
###############################################################################
##
## Revision:
## V1.0 - ldu - 07/25/2018 - Take snapshot when container running.
##
###############################################################################

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
#Skip RHEL6, as not support OVT on RHEL6.
$DISTRO = GetLinuxDistro ${ipv4} ${sshKey}
if ( $DISTRO -eq "RedHat6" ){
    DisconnectWithVIServer
    return $Skipped
}

$retVal = $Failed

#
# Get the VM
#
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName

#Install docker and start one network container on guest.
$result = SendCommandToVM $ipv4 $sshKey "cd /root && dos2unix ovt_mount.sh && chmod u+x ovt_mount.sh && ./ovt_mount.sh"
if( -not $result ){
    Write-Host -F Red "ERROR: mount twice with loop device failed"
    Write-Output "ERROR: mount twice with loop device failed"
    DisconnectWithVIServer
    return $Aborted
}  else {
    Write-Host -F Red "Info : mount twice with loop device successfully"
    Write-Output "Info : mount twice with loop device successfully"
}

#Run a container in guest
# $sts = SendCommandToVM $ipv4 $sshKey "podman run -P -d nginx" 
# if (-not $sts) {
#     LogPrint "ERROR : run container nginx failed in guest"
#     DisconnectWithVIServer
#     return $Failed
# }

# Take snapshot and select quiesce option
$snapshotTargetName = "snapshot"
$new_sp = New-Snapshot -VM $vmObj -Name $snapshotTargetName -Quiesce:$true -Confirm:$false
$newSPName = $new_sp.Name
write-host -f red "$newSPName"
if ($new_sp)
{
    if ($newSPName -eq $snapshotTargetName)
    {
        Write-Host -F Red "The snapshot $newSPName with Quiesce is created successfully"
        Write-Output "The snapshot $newSPName with Quiesce is created successfully"
        $retVal = $Passed
    }
    else
    {
        Write-Output "The snapshot $newSPName with Quiesce is created Failed"
    }
}
sleep 3
#
# Remove SP created
#
$remove = Remove-Snapshot -Snapshot $new_sp -RemoveChildren -Confirm:$false
sleep 3
$snapshots = Get-Snapshot -VM $vmObj -Name $new_sp
if ($snapshots -eq $null)
{
    Write-Host -F Red "The snapshot has been removed successfully"
    Write-Output "The snapshot has been removed successfully"
}
else
{
    Write-Host -F Red "The snapshot removed failed"
    Write-Output "The snapshot removed failed"
    return $Aborted
}

DisconnectWithVIServer

return $retVal
