###############################################################################
##
## Description:
## Take snapshot with memory and Quiesce.
##
###############################################################################
##
## Revision:
## V1.0 - ldu - 10/24/2017 - Take snapshot with memory and Quiesce.
## RHEL7-81369
## ESX-Stor-004
###############################################################################

<#
.Synopsis
    Take snapshot with memory and Quiesce.
.Description
<test>
    <testName>stor_take_restore_snapshot</testName>
    <testID>ESX-Stor-004</testID>
    <testScript>testscripts/stor_take_restore_snapshot.ps1</testScript>
    <files>remote-scripts/utils.sh</files>
    <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
    <testParams>
      <param>TC_COVERED=RHEL6-46079,RHEL7-81369</param>
    </testParams>
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

$retVal = $Failed

# Get the VM
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName

# Create a new test file named test01 before start test
$newfile = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "touch /root/test01"

#
# Take snapshot and select quiesce option
#
$snapshotTargetName = "snap_memory"
$new_sp = New-Snapshot -VM $vmObj -Name $snapshotTargetName -Description "snapshot with memory" -Memory:$true -Quiesce:$true -Confirm:$false
write-host -F Red "new_sp is $new_sp"
$newSPName = $new_sp.Name
if ($new_sp)
{
    if ($newSPName -eq $snapshotTargetName)
    {
        Write-Host -F Red "The snapshot $newSPName with memory and Quiesce is created successfully"
        Write-Output "The snapshot $newSPName with memory and Quiesce is created successfully"
    }
    else
    {
        Write-Output "The snapshot with memory and Quiesce is created Failed"
        DisconnectWithVIServer
        return $Aborted
    }
}

# Remove new created file test01
$removefile = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "rm -f /root/test01"
# Confirm file test01 has been removed
$removeResult = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "find /root/ -name test01"
Write-Host -F Red "removeResult is $removeResult"
if ($removeResult -ne $null)
{
    Write-Error -Message "remove file failed" -Category ObjectNotFound -ErrorAction SilentlyContinue
    DisconnectWithVIServer
    return $Aborted
}

#
# restore SP that just created
#
$restore = Set-VM -VM $vmObj -Snapshot $newSPName -Confirm:$false
write-host -F Red "restore is $restore"

#
# Remove SP created
#
$remove = Remove-Snapshot -Snapshot $new_sp -RemoveChildren -Confirm:$false
$snapshots = Get-Snapshot -VM $vmObj
if ($snapshots.Length -eq 1)
{
    Write-Host -F Red "The snapshot has been removed successfully"
    Write-Output "The snapshot has been removed successfully"
}
else
{
    Write-Host -F Red "The snapshot removed failed"
    Write-Output "The snapshot removed failed"
    DisconnectWithVIServer
    return $Aborted
}

#
# Confirm test file test01 esxit after restore snapshot
#
$exist = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "find /root/ -name test01"
Write-Host -F Red "exit is $exist"
if ($exist -eq $null)
{
    Write-Error -Message "snapshot restore failed" -Category ObjectNotFound -ErrorAction SilentlyContinue
    DisconnectWithVIServer
    return $Aborted
}
else
{
    Write-Host -F Red "The snapshot has been restored successfully"
    Write-Output "The snapshot has been restored successfully"
    $retVal = $Passed
}

DisconnectWithVIServer

return $retVal
