###############################################################################
##
## Description:
## Take snapshot with memory and Quiesce.
##
###############################################################################
##
## Revision:
## v1.0.0 - ldu - 10/24/2017 - Take snapshot with memory and Quiesce.
## v1.0.1 - ruqin - 7/26/2018 - FIX: this case failed in RHEL7.6-ESXi6.5-BIOS
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
    exit 1
}

if (-not $hvServer)
{
    "FAIL: hvServer cannot be null!"
    exit 1
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
		Set-Location $rootDir
	}
	else
	{
		"Warn : rootdir '${rootDir}' does not exist"
	}
}

if ($null -eq $sshKey)
{
	"FAIL: Test parameter sshKey was not specified"
	return $Aborted
}

if ($null -eq $ipv4)
{
	"FAIL: Test parameter ipv4 was not specified"
	return $Aborted
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
if (-not $vmObj) {
    LogPrint "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
    return $Aborted
}

# Create a new test file named test01 before start test
$newfile = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "touch /root/test01"

#
# Take snapshot and select quiesce option
#
$snapshotTargetName = "snap_memory"
$new_sp = New-Snapshot -VM $vmObj -Name $snapshotTargetName -Description "snapshot with memory" -Memory:$true -Quiesce:$true -Confirm:$false

$newSPName = $new_sp.Name
LogPrint "INFO: New Snapshot is $newSPName"

if ($new_sp)
{
    if ($newSPName -eq $snapshotTargetName)
    {
        LogPrint "INFO: The snapshot $newSPName with memory and Quiesce is created successfully"
    }
    else
    {
        LogPrint "INFO: The snapshot with memory and Quiesce is created Failed"
        DisconnectWithVIServer
        return $Fail
    }
}

# Remove new created file test01
$removefile = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "rm -f /root/test01"
# Confirm file test01 has been removed
$removeResult = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "find /root/ -name test01"
LogPrint "INFO: removeResult is $removeResult"
if ($null -ne $removeResult)
{
    Write-Error -Message "ERROR: remove file failed" -Category ObjectNotFound -ErrorAction SilentlyContinue
    DisconnectWithVIServer
    return $Aborted
}


# Refresh VM data
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj) {
    LogPrint "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
    return $Aborted
}


#
# restore SP that just created
#
$restore = Set-VM -VM $vmObj -Snapshot $new_sp -Confirm:$false
LogPrint "INFO: restore is $restore"

#
# Remove SP created
#
$remove = Remove-Snapshot -Snapshot $new_sp -RemoveChildren -Confirm:$false
$snapshots = Get-Snapshot -VM $vmObj
if ($snapshots.Length -eq 1)
{
    Write-Host -F Red "INFO: The snapshot has been removed successfully"
    Write-Output "INFO: The snapshot has been removed successfully"
}
else
{
    Write-Host -F Red "ERROR: The snapshot removed failed"
    Write-Output "ERROR: The snapshot removed failed"
    DisconnectWithVIServer
    return $Aborted
}

#
# Confirm test file test01 esxit after restore snapshot
#
$exist = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "find /root/ -name test01"
if ($null -eq $exist)
{
    Write-Error -Message "ERROR: snapshot restore failed" -Category ObjectNotFound -ErrorAction SilentlyContinue
    DisconnectWithVIServer
    return $Failed
}
else
{
    LogPrint "INFO: File is exist: $exist"
    LogPrint Red "INFO: The snapshot has been restored successfully"
    $retVal = $Passed
}

DisconnectWithVIServer
return $retVal
