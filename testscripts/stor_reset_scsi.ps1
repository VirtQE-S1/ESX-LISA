########################################################################################
## Description:
## 	Check guest status when reset SCSI adapter.
#
## Revision:
## 	v1.0.0 - ldu - 09/25/2019 - Build scripts.
########################################################################################


<#
.Synopsis
    check guest status when reset SCSI adapter.
.Description
<test>
        <testName>stor_reset_scsi</testName>
        <testID>ESX-Stor-038</testID>
        <setupScript>setupscripts\add_hard_disk.ps1</setupScript>
        <testScript>testscripts\stor_reset_scsi.ps1</testScript>
        <files>remote-scripts/utils.sh,remote-scripts/stor_reset_scsi_disk.sh</files>
        <testParams>
            <param>DiskType=SCSI</param>
            <param>StorageFormat=Thick</param>
            <param>Count=1</param>
            <param>CapacityGB=10</param>
            <param>TC_COVERED=RHEL6-0000,RHEL-152733</param>
        </testParams>
        <cleanupScript>SetupScripts\remove_hard_disk.ps1</cleanupScript>
        <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
        <timeout>3600</timeout>
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


# Get the VM
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName


# Check the disk number of the guest.
$diskList =  Get-HardDisk -VM $vmObj
$diskLength = $diskList.Length
if ($diskLength -eq 2)
{
    LogPrint "INFO: Add two disks successfully, The disks count: $diskLength."
}
else
{
    LogPrint "ERROR: Add disk Failed, only $diskLength disk(s) in guest."
    DisconnectWithVIServer
    return $Aborted
}


# Make filesystem and dd a 5G files on new disk.
$result = SendCommandToVM $ipv4 $sshKey "cd /root && dos2unix stor_reset_scsi_disk.sh && chmod u+x stor_reset_scsi_disk.sh && ./stor_reset_scsi_disk.sh"
if (-not $result)
{
	LogPrint "ERROR: Failed to format new add scsi disk."
    DisconnectWithVIServer
	return $Aborted
}
else {
    LogPrint "INFO: New scsi disk could be formated and read, write."
}


# Reset scsi disk when coping files.
$reset = "while true; do sg_reset -v -b /dev/sdb1; done"
$process = Start-Process .\bin\plink.exe -ArgumentList "-i ssh\${sshKey} root@${ipv4} ${reset}" -PassThru -WindowStyle Hidden
LogPrint "DEBUG: process.id: $($process.id)"


Start-Sleep -Seconds 10


# Check loop revalidate command is running from dmesg log file.
$exist = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "dmesg | grep 'SCSI Bus reset'"
if ($null -eq $exist)
{
    
	Logprint "ERROR: Revalidate command failed, no SCSI Bus reset log found in dmesg."
    DisconnectWithVIServer
	return $Failed
}
else {
    LogPrint "INFO: Revalidate command successfully, found $exist in dmesg."
}



# Copy a big file between two scsi disk, while run rest scsi disk.
$result = SendCommandToVM $ipv4 $sshKey "cp /test/1G /tmp"
if (-not $result)
{
	LogPrint "ERROR: Failed to copy file in new scsi disk."
	return $Aborted
}
else
{
    Write-Output "INFO: Copy file successfully."
}


# Check log file, no "FAILED Result: hostbyte=DID_OK driverbyte=DRIVER_OK" logs in demsg.
$exist = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "dmesg | grep 'FAILED Result: hostbyte=DID_OK'"
if ($null -eq $exist)
{
    
    LogPrint "INFO: The sg_reset test successfully, check $exist in dmesg."
    $retVal = $Passed
}
else
{
	LogPrint "ERROR: Cant' find the sg_reset log in dmesg."
    DisconnectWithVIServer
	return $Failed
}


DisconnectWithVIServer
return $retVal
