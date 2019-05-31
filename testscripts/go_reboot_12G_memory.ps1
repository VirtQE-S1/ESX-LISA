#######################################################################################
##  
## Description:
##  Reboot guest wiht memory more then 12G many times.
##
## Revision:
##  v1.0.0 - ldu - 01/31/2018 - Create the script
##  v1.1.0 - boyang - 11/13/2018 - Different reboot methods
##
#######################################################################################


<#
.Synopsis
    Reboot guest with memory more then 12G 8 times with different reboot methods

.Description
    Reboot guest with memory more then 12G 8 times with different reboot methods

.Parameter vmName
    Name of the test VM

.Parameter hvServer
    Name of the VIServer hosting the VM

.Parameter testParams
    Semicolon separated list of test parameters
#>


param([String] $vmName, [String] $hvServer, [String] $testParams)
# Checking the input arguments
# Checking the input arguments
if (-not $vmName) {
    "Error: VM name cannot be null!"
    exit 1
}

if (-not $hvServer) {
    "Error: hvServer cannot be null!"
    exit 1
}

if (-not $testParams) {
    Throw "Error: No test parameters specified"
}


# Display the test parameters so they are captuRed in the log file
"TestParams : '${testParams}'"


# Parse the test parameters
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
        "VMMemory"     { $mem = $fields[1].Trim() }
        "standard_diff"{ $standard_diff = $fields[1].Trim() }
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


#######################################################################################
#
# Main Body
#
#######################################################################################
$retVal = $Failed

# Get the VM
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj)
{
    Write-Error -Message "CheckModules: Unable to create VM object for VM $vmName" -Category ObjectNotFound -ErrorAction SilentlyContinue
}

# Get the guest memory from outside of vm(XML)
$staticMemory = ConvertStringToDecimal $mem.ToUpper()
Write-Output "DEBUG: staticMemory: [${staticMemory}]"
Write-Host -F Red "DEBUG: staticMemory: [${staticMemory}]"

# Get the expected memory
$expected_mem = ([Convert]::ToDecimal($staticMemory)) * 1024 * 1024
Write-Output "DEBUG: expected_mem: [${expected_mem}]"
Write-Host -F Red "DEBUG: expected_mem: [${expected_mem}]"

$diff = 100
# Check mem in vm
$meminfo_total = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "awk '/MemTotal/{print `$2}' /proc/meminfo"
Write-Output "DEBUG: meminfo_total: [${meminfo_total}]"
Write-Host -F Red "DEBUG: meminfo_total: [${meminfo_total}]"
if (-not $meminfo_total)
{
    Write-Output "ERROR: Get MemTotal from /proc/meminfo failed"
    Write-Host -F Red "ERROR: Get MemTotal from /proc/meminfo failed"
    return $Aborted
}

# Kdump reserved memory size with Byte, need to devide 1024
$kdump_kernel = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "cat /sys/kernel/kexec_crash_size"
Write-Output "DEBUG: kdump_kernel: [${kdump_kernel}]"
Write-Host -F Red "DEBUG: kdump_kernel: [${kdump_kernel}]"
if ($kdump_kernel -ge 0)
{
    $meminfo_total = ([Convert]::ToDecimal($meminfo_total)) + (([Convert]::ToDecimal($kdump_kernel))/1024)
    Write-Output "INFO: Acutal total memory in vm [${meminfo_total}]"
    Write-Host -F Red "INFO: Acutal total memory in vm [${meminfo_total}]"

    $diff = ($expected_mem - $meminfo_total)/$expected_mem
    Write-Host -F Red "INFO: The memory in VM: $meminfo_total, expected memory: $expected_mem, actual diff: $diff (standard is $standard_diff) "
    Write-Output "INFO: The memory in VM: $meminfo_total, expected memory: $expected_mem, actual diff: $diff (standard is $standard_diff) "

    if ($diff -lt $standard_diff -and $diff -gt 0)
    {
        Write-Output "INFO: Check memory in vm passed, diff is $diff (standard is $standard_diff)"
        Write-Host -F Red "INFO: Check memory in vm passed, diff is $diff (standard is $standard_diff)"
    }
    else
    {
        Write-Host -F Red "INFO: The memory total in guest is $meminfo_total, expected memory is $expected_mem "
        Write-Output "INFO: The memory total in guest is $meminfo_total, expected memory is $expected_mem"

        Write-Host -F Red "ERROR: Check memory in vm failed, actual is: $diff (standard is $standard_diff)"
        Write-Output "ERROR: Check memory in vm failed, actual is: $diff (standard is $standard_diff)"
        return $Aborted
    }
}
else
{
    Write-Host -F Red "ERROR: Get kdump memory size from /sys/kernel/kexec_crash_size failed"
    Write-Output "ERROR: Get kdump memory size from /sys/kernel/kexec_crash_size failed"
    return $Aborted
}
Write-Host -F Red "INFO: go_check_memory.ps1 script completed"
Write-Output "INFO: go_check_memory.ps1 script completed"

# Reboot in VM
$round=0
while ($round -lt 4)
{
    $round=$round+1
    Write-Host -F Red "INFO: The round: $round"
    Write-Output "INFO: The round: $round"

    $reboot = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "init 6"

    Start-Sleep -seconds 6

    # Wait for vm to Start
    $ssh = WaitForVMSSHReady $vmName $hvServer ${sshKey} 360
    if ( $ssh -ne $true )
    {
        Write-Output "ERROR: Failed to init VM. The round is $round"
        Write-Host -F Red "ERROR: Failed to init VM. The round is $round"
        return $Aborted
    }
}

if ($round -eq 4)
{
    Write-Output "INFO: The guest could reboot(init 6) $round times with no crash"
    Write-Host -F Red "INFO: The guest could reboot(init 6) $round times with no crash"
}
else
{
    Write-Host -F Red "ERROR: Can't complete reboot(init 6) 4 times"
    Write-Output "ERROR: Can't complete reboot(init 6) 4 times"
    return $Aborted
}

# Reboot with reset in vsphere
$round=0
while ($round -lt 4)
{
    $round=$round+1
    Write-Host -F Red "INFO: The round: $round"
    Write-Output "INFO: The round: $round"

    $vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
    if (-not $vmObj)
    {
        Write-Error -Message "CheckModules: Unable to create VM object for VM $vmName" -Category ObjectNotFound -ErrorAction SilentlyContinue
    }

    $restart = Restart-VM -VM $vmObj -Confirm:$False

    Start-Sleep -seconds 6
    
    $ssh = WaitForVMSSHReady $vmName $hvServer ${sshKey} 360
    if ($ssh -ne $true)
    {
        Write-Output "ERROR: Failed to Restart-VM.The round is $round"
        Write-Host -F Red "ERROR: Failed to Restart-VM.The round is $round"
        return $Aborted
    }
}

if ($round -eq 4)
{
    $retVal = $Passed
    Write-Output "INFO: The guest could reboot(Start-VM) $round times with no crash"
    Write-Host -F Red "INFO: The guest could reboot(Start-VM) $round times with no crash"
}
else
{
    Write-Host -F Red "ERROR: Can't complete reboot(Restart) 4 times"
    Write-Output "ERROR: Can't complete reboot(Restart) 4 times"
    return $Aborted
}

DisconnectWithVIServer

return $retVal
