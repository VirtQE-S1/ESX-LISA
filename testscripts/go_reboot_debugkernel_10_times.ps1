########################################################################################
## Description:
## 	Reboot guet with debugkernel installed  more then 10 times.
##
## Revision:
## 	v1.0.0 - ldu - 03/02/2018 - Reboot guest more then 10 times with debugkernel
##  v1.1.0 - boyang - 06/03/2019 - Fix send CMD format 
########################################################################################


<#
.Synopsis
    Reboot guet with debugkernel installed  more then 10 times.

.Description
    Reboot guet with debugkernel installed  more then 10 times.

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
## Main Body
########################################################################################
$retVal = $Failed


# Install kerel-debug package in guest
$kerneldebug_install = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "yum install -y kernel-debug"
LogPrint "DEBUG: kerneldebug_install: ${kerneldebug_install}."


Start-Sleep -seconds 6


# Check the kernel-debug installed successfully or not
$kerneldebug_check = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "rpm -qa kernel-debug"
LogPrint "DEBUG: kerneldebug_check: ${kerneldebug_check}."
if ($null -eq $kerneldebug_check)
{
    LogPrint "ERROR: The kernel-debug installed failed in the guest."
    return $Aborted
}


# Check the OS distro. Then change the grub file to change boot order.
$OS = GetLinuxDistro $ipv4 $sshKey
LogPrint "INFO: As VM's OS: ${OS}. Will take different methods to change boot order."
if ($OS -eq "RedHat6")
{
    # Change the boot sequence to debug kernel
    $change_EFI = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "sed -i 's/default=1/default=0/g' /boot/efi/EFI/redhat/grub.conf"
    $change_bois = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "sed -i 's/default=1/default=0/g' /boot/grub/grub.conf"
}
else
{
    # Change the boot sequence to debug kernel
    $change_boot = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "grub2-set-default 0"
}


# Reboot the guest 10 times.
$round=0
while ($round -lt 10)
{
    $reboot = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "init 6"

    Start-Sleep -seconds 6
    
    $ssh = WaitForVMSSHReady $vmName $hvServer ${sshKey} 300
    if ($ssh -ne $true)
    {
    	Write-Output "ERROR: Failed to start VM."
        return $Aborted
    }
    else
    {
        $current_kernel = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "uname -r | grep debug"
        LogPrint "INFO: After reboot the current kernel: ${current_kernel}."
        if ($null -eq $current_kernel)
        {
            LogPrint "ERROR: The kernel-debug has been installed but current kernel isn't kernel-debug but ${current_kernel}."
            return $Aborted
        }
    }

    $round=$round+1
    LogPrint "INFO: The $round time(s) to reboot VM."
}


if ($round -eq 10)
{
    $status = CheckCallTrace $ipv4 $sshKey 
    if (-not $status[-1]) { 
        LogPrint "ERROR: Found $($status[-2]) in msg." 
    } 
    else { 
        LogPrint "INFO: NOT found Call Trace in VM msg." 
        $retVal = $Passed 
    }
}
else
{
    LogPrint "ERROR: The actual round: $round < 10 time(s)."
}


DisconnectWithVIServer
return $retVal
