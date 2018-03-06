###############################################################################
##
## Description:
## Reboot guest with debugkernel and check pvscsi error in log.
##
###############################################################################
##
## Revision:
## V1.0 - ldu - 03/06/2018 - Reboot guest with debugkernel and check pvscsi error in log.
##
##
###############################################################################

<#
.Synopsis
    Reboot guest with debugkernel and check pvscsi error in log.
.Description
<test>
    <testName>stor_check_pvscsi_error</testName>
    <testID>ESX-STOR-009</testID>
    <testScript>testscripts\stor_check_pvscsi_error.ps1</testScript>
    <testParams>
        <param>TC_COVERED=RHEL6-34930,RHEL7-54890</param>
    </testParams>
    <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
    <timeout>300</timeout>
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
        "VMMemory"     { $mem = $fields[1].Trim() }
        "standard_diff"{ $standard_diff = $fields[1].Trim() }
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

# Install kerel-debug package in guest.
$kerneldebug_install = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "yum install -y kernel-debug"

#check the kernel-debug installed successfully.
$kerneldebug_check = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "rpm -qa kernel-debug"
Write-Host -F red "$kerneldebug_check"
if ($null -eq $kerneldebug_check)
{
    Write-Output "The kernel-debug installed failed in guest."
    return $Aborted
}
else
{
    Write-Output " The kernel debug $kerneldebug_check installed successfully."

}

# Change the boot sequence to debug krenl
$change_boot = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "grub2-set-default 0"

#Reboot guest with debug kernel.
$reboot = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "init 6"

$ssh = WaitForVMSSHReady $vmName $hvServer ${sshKey} 300
if ( $ssh -ne $true )
{
    Write-Output "Failed: Failed to start VM."
    Write-host -F Red "the round is $round "
    return $Aborted
}

$pvscsi_log_check = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "dmesg |grep pvscsi |grep -E 'fail|error'"
Write-Host -F red "$pvscsi_log_check"
if ($null -eq $pvscsi_log_check)
{
    $retVal = $Passed
    Write-host -F Red "The guest could reboot with debug kernel, no error or failed message related pvscsi "
    Write-Output "PASS: The guest could reboot with debug kernel, no error or failed message related pvscsi"
}
else
{
    Write-Output "FAIL: After booting with debug kernel, FOUND $calltrace_check in demsg"
}


DisconnectWithVIServer

return $retVal
