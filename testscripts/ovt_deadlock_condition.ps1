###############################################################################
##
## Description:
## Take snapshot after deadlock condiation.
##
###############################################################################
##
## Revision:
## V1.0 - ldu - 07/23/2018 - Take snapshot after deadlock condiation.
##
###############################################################################

<#
.Synopsis
    Take snapshot after deadlock condiation.
.Description
<test>
    <testName>ovt_deadlock_condition</testName>
    <testID>ESX-OVT-032</testID>
    <testScript>testscripts/ovt_deadlock_condition.ps1</testScript  >
    <files>remote-scripts/utils.sh</files>
    <files>remote-scripts/ovt_check_deadlock.sh</files>
    <files>remote-scripts/ovt_loop.sh</files>
    <testParams>
        <param>TC_COVERED=RHEL6-47886,RHEL7-94309</param>
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

$scripts = "ovt_check_deadlock.sh"
# Run remote test scripts
$sts =  RunRemoteScript $scripts
if( -not $sts[-1] ){
    Write-Host -F Red "ERROR: mount loop device failed"
    Write-Output "ERROR: mount loop device failed"
    return $Aborted
}  else {
    Write-Host -F Red "Info : mount loop device successfully"
    Write-Output "Info : mount loop device successfully"
}

$command1 = "cd /root/ && dos2unix ovt_loop.sh && chmod u+x ovt_loop.sh && ./ovt_loop.sh"
$Process1 = Start-Process bin\plink -ArgumentList "-i ssh\${sshKey} root@${ipv4} ${command1}" -PassThru -WindowStyle Hidden
write-host -F Red "$($Process1.id)"

$command2 = "/usr/bin/vmtoolsd -l"
$Process2 = Start-Process bin\plink -ArgumentList "-i ssh\${sshKey} root@${ipv4} ${command2}" -PassThru -WindowStyle Hidden


#
# Take snapshot and select quiesce option
#
$snapshotTargetName = "snapdeadlock"
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

#
# Remove SP created
#
$remove = Remove-Snapshot -Snapshot $new_sp -RemoveChildren -Confirm:$false
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

$stop1 = Stop-Process -Id $Process1.Id
$stop2 = Stop-Process -Id $Process2.Id


DisconnectWithVIServer

return $retVal
