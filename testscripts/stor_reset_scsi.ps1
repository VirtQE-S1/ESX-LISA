###############################################################################
##
## Description:
## check guest status when reset SCSI adapter
##
###############################################################################
##
## Revision:
## v1.0.0 - ldu - 09/25/2019 - Build scripts.
##
##
## 
###############################################################################

<#
.Synopsis
    
.Description

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
# #hot add two scsi disk
# $hd_size = Get-Random -Minimum 5 -Maximum 10
# $disk1 = New-HardDisk -CapacityGB $hd_size -VM $vmObj -StorageFormat "Thin" -ErrorAction SilentlyContinue

#
# Check the disk number of the guest.
#
$diskList =  Get-HardDisk -VM $vmObj
$diskLength = $diskList.Length

if ($diskLength -eq 2)
{
    write-host -F Red "The disk count is $diskLength."
    Write-Output "Add two disk successfully, The disk count is $diskLength."
}
else
{
    write-host -F Red "The disk count is $diskLength."
    Write-Output "Add disk Failed, only $diskLength disk in guest."
    DisconnectWithVIServer
    return $Aborted
}

#Make filesystem and dd a 5G files on new disk
$result = SendCommandToVM $ipv4 $sshKey "cd /root && dos2unix stor_reset_scsi_disk.sh && chmod u+x stor_reset_scsi_disk.sh && ./stor_reset_scsi_disk.sh"
if (-not $result)
{
	Write-Host -F Red "FAIL: Failed to format new add scsi disk."
	Write-Output "FAIL: Failed to format new add scsi disk"
	return $Aborted
}
else
{
	Write-Host -F Green "PASS: new add scsi disk could be formated and read,write."
    Write-Output "PASS: new add scsi disk could be formated and read,write."
}

#Reset scsi disk when coping files
$reset = "while true; do sg_reset -v -b /dev/sdb1; done"
$process = Start-Process .\bin\plink.exe -ArgumentList "-i ssh\${sshKey} root@${ipv4} ${reset}" -PassThru -WindowStyle Hidden
write-host -F Red "process1 id is $($process.id)"

Start-Sleep -Seconds 10

#check loop revalidate command is running from dmesg log file
$exist = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "dmesg |grep 'SCSI Bus reset'"
if ($null -eq $exist)
{
    
	Write-Host -F Red "INFO: revalidate command failed, no SCSI Bus reset log is exist: $exist"
	Write-Output "Failed, revalidate command failed, no SCSI Bus reset log is exist in dmesg: $exist "
    DisconnectWithVIServer
	return $Failed
}
else
{
	Write-Host -F Red "INFO: revalidate command successfully, SCSI Bus reset log is exist: $exist"
	Write-Output "Passed, revalidate command successfully, SCSI Bus reset log is exist in dmesg: $exist "
}

#Copy a big file between two scsi disk, while run rest scsi disk.
$result = SendCommandToVM $ipv4 $sshKey "cp /test/3G /tmp"
if (-not $result)
{
	Write-Host -F Red "FAIL: Failed to copy file from new add scsi disk."
	Write-Output "FAIL: Failed to copy file from new add scsi disk"
	return $Aborted
}
else
{
	Write-Host -F Red "PASS:copy file successfully."
    Write-Output "PASS: copy file successfully."
}

#check log file, no "FAILED Result: hostbyte=DID_OK driverbyte=DRIVER_OK" logs in demsg.
$exist = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "dmesg |grep 'FAILED Result: hostbyte=DID_OK'"
if ($null -eq $exist)
{
    
	Write-Host -F Green "INFO: File FAILED Result: hostbyte=DID_OK  is not exist: $exist"
    Write-Output "INFO: The sg_reset test successfully"
    $retVal = $Passed
}
else
{
	Write-Host -F Red "INFO: failed log is exist: $exist"
	Write-Output "Failed, the failed log is exist in dmesg: $exist "
    DisconnectWithVIServer
	return $Failed
}


DisconnectWithVIServer

return $retVal
