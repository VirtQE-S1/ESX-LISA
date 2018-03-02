###############################################################################
##
## Description:
## Reboot guest wiht memory more then 12G many times.
##
###############################################################################
##
## Revision:
## V1.0 - ldu - 01/31/2018 - Reboot guest with memory more then 12G 4 times.
##
## ESX-GO-012
##
###############################################################################

<#
.Synopsis
    Reboot guest with memory more then 12G 4 times.
.Description
<test>
    <testName>go_reboot_12G_memory</testName>
    <testID>ESX-GO-012</testID>
    <setupScript>setupscripts\change_memory.ps1</setupScript>
    <testScript>testscripts\go_reboot_12G_memory.ps1</testScript>
    <testParams>
        <param>VMMemory=16GB</param>
        <param>standard_diff=1</param>
        <param>TC_COVERED=RHEL6-47863,RHEL7-87238</param>
    </testParams>
    <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
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

# Get the VM
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
#Get the guest memory from outside of vm(XML).
$staticMemory = ConvertStringToDecimal $mem.ToUpper()
Write-Host -F Red "staticMemory is $staticMemory"

if (-not $vmObj)
{
    Write-Error -Message "CheckModules: Unable to create VM object for VM $vmName" -Category ObjectNotFound -ErrorAction SilentlyContinue
}
else
{
    $expected_mem = ([Convert]::ToDecimal($staticMemory)) * 1024 * 1024
    "Info : Expected total memory is $expected_mem"
    $diff = 100
    # check mem in vm
    # MemTotal in /proc/meminfo is kB
    $meminfo_total = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "awk '/MemTotal/{print `$2}' /proc/meminfo"
    "Debug : meminfo_total in vm is $meminfo_total"
    if ( -not $meminfo_total )
    {
        "Error : Get MemTotal from /proc/meminfo failed"
        return $Aborted
    }
    else
    {
        # kdump reserved memory size, in B,need to devide 1024
        $kdump_kernel = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "cat /sys/kernel/kexec_crash_size"
        "Debug : kdump_kernel in vm is $kdump_kernel"
        if ( $kdump_kernel -ge 0 )
        {

            $meminfo_total = ([Convert]::ToDecimal($meminfo_total)) + (([Convert]::ToDecimal($kdump_kernel))/1024)
            "Info : Acutal total memory in vm is $meminfo_total"

            $diff = ($expected_mem - $meminfo_total)/$expected_mem
            Write-Host -F Red "The memory total in guest is $meminfo_total, expected memory is $expected_mem,actual is: $diff (standard is $standard_diff) "
            Write-Output "The memory total in guest is $meminfo_total, expected memory is $expected_mem"

            if ( $diff -lt $standard_diff -and $diff -gt 0 )
            {
                "Info : Check memory in vm passed, diff is $diff (standard is $standard_diff)"
            }
            else
            {
                Write-host -F Red "The memory total in guest is $meminfo_total, expected memory is $expected_mem "
                Write-Output "The memory total in guest is $meminfo_total, expected memory is $expected_mem"

                "Error : Check memory in vm failed, actual is: $diff (standard is $standard_diff)"
                return $Aborted
            }
        }
        else
        {
            "Error : Get kdump memory size from /sys/kernel/kexec_crash_size failed"
            return $Aborted
        }
    }

}
"Info : go_check_memory.ps1 script completed"
#
#Reboot the guest first time.
#
$round=0
while ($round -lt 4)
{
    $reboot = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "init 6"
    Start-Sleep -seconds 6
    # wait for vm to Start
    $ssh = WaitForVMSSHReady $vmName $hvServer ${sshKey} 300
    if ( $ssh -ne $true )
    {
        Write-Output "Failed: Failed to start VM."
        Write-host -F Red "the round is $round "
        return $Aborted
    }
    $round=$round+1
    Write-host -F Red "the round is $round "
}
if ($round -eq 4)
{
    $retVal = $Passed
    Write-host -F Red "the round is $round, the guest could reboot 3 times with no crash "
}
else
{
    Write-host -F Red "the round is $round "
}



DisconnectWithVIServer

return $retVal
