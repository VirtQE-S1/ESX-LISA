########################################################################################
## Description:
## 	Reboot guet with debugkernel installed.
##
## Revision:
## 	v1.0.0 - ldu - 05/27/2019 - Reboot guest with debugkernel installed.
## 	v1.1.0 - boyang - 06/03/2019 - Fix send CMD format.
##  v1.2.0 - boyang - 10/16.2019 - Skip test when host hardware hasn't RDMA NIC.
########################################################################################


<#
.Synopsis
    Reboot guet with debugkernel installed.

.Description
    Reboot guet with debugkernel installed.

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


########################################################################################
# Main Body
########################################################################################
$retVal = $Failed


$skip = SkipTestInHost $hvServer "6.0.0"
if($skip)
{
    return $Skipped
}


# Get new add RDMA NIC
$nics = FindAllNewAddNIC $ipv4 $sshKey
if ($null -eq $nics) 
{
    LogPrint "ERROR: Cannot find new add SR-IOV NIC."
    DisconnectWithVIServer
    return $Failed
}
else 
{
    $rdmaNIC = $nics[-1]
}
LogPrint "INFO: New NIC is $rdmaNIC."


# Assign a new IP addr to new RDMA nic
$IPAddr = "172.31.1." + (Get-Random -Maximum 254 -Minimum 2)
if (-not (ConfigIPforNewDevice $ipv4 $sshKey $rdmaNIC ($IPAddr + "/24"))) 
{
    LogPrint "ERROR: Config IP Failed."
    DisconnectWithVIServer
    return $Failed
}


# Install required packages
$sts = SendCommandToVM $ipv4 $sshKey "yum install -y rdma-core infiniband-diags" 
if (-not $sts) 
{
    LogPrint "ERROR: YUM cannot install required packages."
    DisconnectWithVIServer
    return $Failed
}


# Load mod ib_umad for ibstat check
$Command = "modprobe ib_umad"
$modules = Write-Output y | bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command


# Make sure the ibstat is active 
$Command = "ibstat | grep Active | wc -l"
$ibstat = [int] (Write-Output y | bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command)
if ($ibstat -eq 0) 
{
    LogPrint "ERROR: The ibstat is not correctly."
    DisconnectWithVIServer
    return $Failed
}


# Install kerel-debug package in guest.
$kerneldebug_install = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "yum install -y kernel-debug"


# Check the kernel-debug installed successfully or not.
$kernel_debug_check = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "rpm -qa kernel-debug"
Write-Host -F Red "DEBUG: kernel_debug_check: $kernel_debug_check"
Write-Output "DEBUG: kernel_debug_check: $kernel_debug_check"
if ($null -eq $kernel_debug_check)
{
    Write-Output "ERROR: Failed to install kernel-debug."
    return $Aborted
}
else
{
    Write-Output "INFO: Install kernel-debug $kernel_debug_check successfully."
}


# Check the OS distro.Then change the grub file to change boot order
$OS = GetLinuxDistro  $ipv4 $sshKey
if ($OS -eq "RedHat6")
{
    # Change the boot sequence to debug kernel.
    $change_EFI = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "sed -i 's/default=1/default=0/g' /boot/efi/EFI/redhat/grub.conf"
    $change_bois = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "sed -i 's/default=1/default=0/g' /boot/grub/grub.conf"
}
else
{
    # Change the boot sequence to debug kernel.
    $change_boot = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "grub2-set-default 0"
}


# Reboot the guest
$reboot = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "init 6"
Start-Sleep -seconds 6


# Wait for vm to Start
$ssh = WaitForVMSSHReady $vmName $hvServer ${sshKey} 300
if ($ssh -ne $true)
{
    Write-host -F Red "ERROR: Failed to start VM."
    Write-Output "ERROR: Failed to start VM."
    return $Aborted
}
else
{
    $current_kernel = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "uname -r | grep debug"
    Write-Host -F Red "INFO: After reboot the current kernel is $current_kernel."
    Write-Output "INFO: After reboot the current kernel is $current_kernel."
    if ($null -eq $current_kernel)
    {
        Write-Output "ERROR: The kernel-debug switch failed in guest."
        return $Aborted
    }
}


# Check call trace.
$calltrace_check = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "dmesg | grep 'Call Trace'"
Write-Output "DEBUG: calltrace_check: $calltrace_check"
Write-Host -F red "DEBUG: calltrace_check: $calltrace_check"
if ($null -eq $calltrace_check)
{
    $retVal = $Passed
    Write-host -F Red "INFO: After booting with debug kernel, NO $calltrace_check Call Trace found."
    Write-Output "INFO: After  booting with debug kernel, NO $calltrace_check Call Trace found."
}
else{
    Write-Output "ERROR: After booting with debug kernel, FOUND $calltrace_check Call Trace in demsg."
}


DisconnectWithVIServer
return $retVal
