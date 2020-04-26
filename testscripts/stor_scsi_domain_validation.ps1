########################################################################################
## Description:
## 	Check SCSI domain validation deadlock status when a device's request queue is full.
##
## Revision:
## 	v1.0.0 - ldu - 09/23/2019 - Build scripts.
## 	v1.0.1 - boyang - 12/18/2019 - Enhance errors check.
########################################################################################


<#
.Synopsis
    Check SCSI domain validation deadlock status when a device's request queue is full
.Description
<test>
        <testName>stor_scsi_domain_validation</testName>
        <testID>ESX-Stor-037</testID>
        <testScript>testscripts\stor_scsi_domain_validation.ps1</testScript>
        <files>
                remote-scripts/utils.sh,remote-scripts/stor_domain_validation.sh
        </files>
        <testParams>
            <param>TC_COVERED=RHEL6-0000,RHEL-173219</param>
        </testParams>
        <cleanupScript>SetupScripts\revert_guest_B.ps1</cleanupScript>
        <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
        <timeout>1800</timeout>
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


# Checking the input arguments.
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
	"ERROR: Test parameter ipv4 was not specified."
	return $False
}

if ($null -eq $logdir)
{
	"ERROR: Test parameter logdir was not specified."
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

$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
# Get the Guest B.
$GuestBName = $vmObj.Name.Split('-')
# Get another VM by change Name.
$GuestBName[-1] = "B"
$GuestBName = $GuestBName -join "-"
$GuestB = Get-VMHost -Name $hvServer | Get-VM -Name $GuestBName


# If the VM is not stopped, try to stop it.
if ($GuestB.PowerState -ne "PoweredOff") {
    LogPrint "INFO: $GuestBName is not in a poweredoff state. Will stop-vm."
    $outStopVm = Stop-VM -VM $GuestB -Confirm:$false -Kill
    if ($outStopVm -eq $false -or $outStopVm.PowerState -ne "PoweredOff") {
        LogPrint "ERROR: VM-B powerstate isn't powered off. Aborted."
        return $Aborted
    }
}


# Check the disk number of the guest before add a new one.
$oldDiskList =  Get-HardDisk -VM $GuestB
$oldDiskLength = $oldDiskList.Length

LogPrint "DEBUG: oldDiskLength: ${oldDiskLength}."


# Add LSI Logic Parallel for Guest B.
$hd_size = Get-Random -Minimum 10 -Maximum 15

$GuestB | New-HardDisk -CapacityGB $hd_size -StorageFormat "Thin" | New-ScsiController -Type VirtualLsiLogic
if (-not $?) {
    LogPrint "ERROR : Cannot add a disk to VMB."
    DisconnectWithVIServer
    return $Aborted
}
LogPrint "INFO: Add LSI logic Parallel scsi controller and disk well when VM-B powered off."


# Start GuestB.
$on = Start-VM -VM $GuestB -Confirm:$false -RunAsync:$true -ErrorAction SilentlyContinue
if (-not $?) {
    LogPrint "ERROR : Cannot start VM."
    DisconnectWithVIServer
    return $Aborted
}
else
{
    LogPrint "INFO: Power on VMB completed."
}


# Wait for GuestB SSH ready.
if ( -not (WaitForVMSSHReady $GuestBName $hvServer $sshKey 300)) {
    LogPrint "ERROR : Cannot start SSH."
    DisconnectWithVIServer
    return $Aborted
}
{
    LogPrint "INFO: Ready SSH."
}


# Get VMB IP addr.
$ipv4B = GetIPv4 -vmName $GuestBName -hvServer $hvServer
LogPrint "DEBUG: ipv4B: ${ipv4B}."


# Check the disk number of the guest.
$GuestB = Get-VMHost -Name $hvServer | Get-VM -Name $GuestBName

$newDiskList =  Get-HardDisk -VM $GuestB
$newDiskLength = $newDiskList.Length
LogPrint "DEBUG: newDiskLength: ${newDiskLength}."

if (($newDiskLength - $oldDiskLength) -eq 1)
{
    LogPrint "INFO: Hot plug LSILogicParallel scsi disk successfully, The disk count is $newDiskLength."
}
else
{
    LogPrint "ERROR: Hot plug LSILogicParallel scsi disk Failed, $newDiskLength disk in the guest."
    DisconnectWithVIServer
    return $Aborted
}


# Rescan new add parallel scsi disk in guest.
$result = SendCommandToVM $ipv4B $sshKey "rescan-scsi-bus.sh -a && sleep 3 && ls /dev/sdb"
LogPrint "DEBUG: result: ${result}."
if (-not $result)
{
	LogPrint "ERROR: Failed to detect new add LSILogicParallel scsi disk."
	return $Aborted
}
else{
    LogPrint "INFO: new add LSILogicParallel scsi disk could be detected."
}


# Add ipv4B addr to constants.sh.
$result2 = SendCommandToVM $ipv4 $sshKey "echo 'ipv4B=$ipv4B' >> ~/constants.sh"
LogPrint "DEBUG: result2: ${result2}."
if (-not $result2[-1])
{
    LogPrint "ERROR: Cannot add ipv4B addr into constants.sh file."
	DisconnectWithVIServer
	return $Aborted
}


# SCP shell scripts stor_domain_validation.sh utils.sh constants.sh from guestA to guestB.
$result3 = SendCommandToVM $ipv4 $sshKey "scp -i `$HOME/.ssh/id_rsa_private -o StrictHostKeyChecking=no stor_domain_validation.sh utils.sh constants.sh root@${ipv4B}:/root"
LogPrint "DEBUG: result3: ${result3}."
if (-not $result3[-1])
{
    LogPrint "ERROR: Cannot scp file to VM-B."
	DisconnectWithVIServer
	return $Aborted
}


# Make filesystem and mount the new Parallel disk to /mnt.
$result4 = SendCommandToVM $ipv4B $sshKey "cd /root && dos2unix stor_domain_validation.sh && bash stor_domain_validation.sh"
LogPrint "DEBUG: result4: ${result4}."
if (-not $result4)
{
	LogPrint "ERROR: Failed to format new add scsi disk."
	return $Aborted
}
else
{
    LogPrint "INFO: new add scsi disk could be formated and read,write."
}


# Start running a heavy load of io to sdb，for example:
$workload = 'fio --filename=/mnt/test --time_based --direct=1 --rw=randrw --bs=4k --size=5G --numjobs=75 --runtime=300000 --name=test --ioengine=libaio --iodepth=64 --rwmixread=50'
$process1 = Start-Process .\bin\plink.exe -ArgumentList "-i ssh\${sshKey} root@${ipv4B} ${workload}" -PassThru -WindowStyle Hidden
LogPrint "INFO: Process1 id is $($process1.id)"


# In a loop issue the revalidate command
$Command = "while true; do echo 1 > /sys/class/spi_transport/target2\:0\:0/revalidate; done"
$process2 = Start-Process .\bin\plink.exe -ArgumentList "-i ssh\${sshKey} root@${ipv4B} ${Command}" -PassThru -WindowStyle Hidden
LogPrint "INFO: Process2 id is $($process2.id)  revalidate while loop is running"


# Loop runing for 10 mins
Start-Sleep -Seconds 300


# Check the fio tools running from the fio test file /mnt/test1
$exist = bin\plink.exe -i ssh\${sshKey} root@${ipv4B} "ls /mnt/test"
LogPrint "DEBUG: exist: ${exist}."
if ($null -eq $exist)
{
    
	LogPrint "ERROR Tool fio run failed, file /mnt/test1 didn't exist."
    DisconnectWithVIServer
	return $Failed
}
else
{
	Write-Output "INFO: Tool fio run successfully, file /mnt/test1 exist."
}


# Check loop revalidate command is running from dmesg log file.
$grep = bin\plink.exe -i ssh\${sshKey} root@${ipv4B} "dmesg | grep 'Ending Domain Validation'"
LogPrint "DEBUG: grep: ${grep}."
if ($null -eq $grep)
{
    
	LogPrint "ERROR: Revalidate command failed, no domain validation log in dmesg."
    DisconnectWithVIServer
	return $Failed
}
else
{
	LogPrint "INFO: Revalidate command successfully, found domain validation log in dmesg."
}


# Check the call trace in dmesg file.
$calltrace = CheckCallTrace $ipv4 $sshKey
LogPrint "DEBUG: calltrace: ${calltrace}."
if (-not $calltrace[-1]) {
    LogPrint "ERROR: Found $($calltrace[-2]) in msg."
}
else {
    LogPrint "INFO: NOT found $($calltrace[-2]) in msg."
    $retVal = $Passed
}


DisconnectWithVIServer
return $retVal
