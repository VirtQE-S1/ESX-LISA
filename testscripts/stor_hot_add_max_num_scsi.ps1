###############################################################################
##
## Description:
## Test guest works well when hot add  scsi disks at max number .
##
###############################################################################
##
## Revision:
## v1.0.0 - ldu - 07/21/2019 - Hot add  scsi disk wit max number.
##
## 
###############################################################################

<#
.Synopsis
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
$count = $null
$diskType = $null

$params = $testParams.Split(";")
foreach ($p in $params)
{
	$fields = $p.Split("=")
	switch ($fields[0].Trim())
	{
		"rootDir"		{ $rootDir = $fields[1].Trim() }
		"sshKey"		{ $sshKey = $fields[1].Trim() }
		"ipv4"			{ $ipv4 = $fields[1].Trim() }
		"TestLogDir"	{ $logdir = $fields[1].Trim() }
        "Count"         { $count = $fields[1].Trim() }
        "DiskType"      { $diskType = $fields[1].Trim() }
        "StorageFormat" { $storageFormat = $fields[1].Trim() }
        "CapacityGB"    { $capacityGB = $fields[1].Trim() }
        "DiskDataStore" { $diskDataStore = $fields[1].Trim() }
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

#Hot add scsi disk with max number to each scsi controllor
Write-Host -F Red "Count is $count"
for ($i = 0; $i -le $count; $i++)
{
    write-host -F red "i is $i"
    for ($j = 0; $j -lt 63; $j++)
    {   
        #add scsi disk to each controllor
        write-host -F red "j is $j" 
        $hd_size = Get-Random -Minimum 1 -Maximum 5
        $disk = New-HardDisk -CapacityGB $hd_size -VM $vmObj -StorageFormat "Thin" -Controller "SCSI Controller $i" -ErrorAction SilentlyContinue
        Start-Sleep -seconds 1
        Write-Output "INFO: Round: $j "
        Write-Host -F Red "INFO: Round: $j"
    }
    
}


# Check the disk number of the guest.
$diskList =  Get-HardDisk -VM $vmObj
$diskLength = $diskList.Length

if ($diskLength -eq 256)
{
    write-host -F Red "The disk numbers is $diskLength."
    Write-Output "Add max number scsi disk successfully, The disk numbers is $diskLength."
}
else
{
    write-host -F Red "Error: The disk numbers is $diskLength."
    Write-Output "Error: Add max number disk Failed, only $diskLength disk in guest."
    DisconnectWithVIServer
    return $Aborted
}

$calltrace_check = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "dmesg | grep 'Call Trace'"
if ($null -eq $calltrace_check)
{
    $retVal = $Passed
    Write-host -F Red "INFO: After cat file /dev/snapshot, NO $calltrace_check Call Trace found"
    Write-Output "INFO: After cat file /dev/snapshot, NO $calltrace_check Call Trace found"
}
else{
    Write-Output "ERROR: After, FOUND $calltrace_check Call Trace in demsg"
}

DisconnectWithVIServer

return $retVal
