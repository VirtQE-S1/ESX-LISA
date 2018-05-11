###############################################################################
##
## Description:
##   Check memory in the VM
##
## Revision:
##  v1.0.0 - hhei - 1/9/2017 - Check memory in the VM
##  v1.0.1 - hhei - 2/6/2017 - Remove TC_COVERED and update return value
##  v1.0.2 - boyang - 05/11/2018 - Enhance the script and exit 100 if false
##
###############################################################################
<#
.Synopsis
    Demo script ONLY for test script.

.Description
    A demo for Powershell script as test script.

.Parameter vmName
    Name of the test VM.

.Parameter testParams
    Semicolon separated list of test parameters.
#>


param([String] $vmName, [String] $hvServer, [String] $testParams)


########################################################################
#
# ConvertStringToDecimal()
#
########################################################################
function ConvertStringToDecimal([string] $str)
{
    $uint64Size = $null

    #
    # Make sure we received a string to convert
    #
    if (-not $str)
    {
        Write-Error -Message "ConvertStringToDecimal() - input string is null" -Category InvalidArgument -ErrorAction SilentlyContinue
        return $null
    }

    if ($str.EndsWith("GB"))
    {
        $num = $str.Replace("GB","")
        $uint64Size = ([Convert]::ToDecimal($num))
    }
    elseif ($str.EndsWith("TB"))
    {
        $num = $str.Replace("TB","")
        $uint64Size = ([Convert]::ToDecimal($num)) * 1024
    }
    else
    {
        Write-Error -Message "Invalid newSize parameter: ${str}" -Category InvalidArgument -ErrorAction SilentlyContinue
        return $null
    }

    return $uint64Size
}


#
# Checking the input arguments
#
if (-not $vmName)
{
    "Error: VM name cannot be null!"
    exit 100
}

if (-not $hvServer)
{
    "Error: hvServer cannot be null!"
    exit 100
}

if (-not $testParams)
{
    Throw "Error: No test parameters specified"
}


#
# Output test parameters so they are captured in log file
#
"TestParams : '${testParams}'"


#
# Parse the test parameters
#
$rootDir = $null
$sshKey = $null
$ipv4 = $null

$params = $testParams.Split(";")
foreach ($p in $params)
{
    $fields = $p.Split("=")
    switch ($fields[0].Trim())
    {
    "sshKey"       { $sshKey = $fields[1].Trim() }
    "rootDir"      { $rootDir = $fields[1].Trim() }
    "ipv4"         { $ipv4 = $fields[1].Trim() }
    "VMMemory"     { $mem = $fields[1].Trim() }
    "standard_diff"{ $standard_diff = $fields[1].Trim() }
    default        {}
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


#
# Source the tcutils.ps1 file
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


$staticMemory = ConvertStringToDecimal $mem.ToUpper()


$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj)
{
    Write-Host -F Red "ERROR: Unable to Get-VM with $vmName"
    Write-Output "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
	return $Aborted
}


$expected_mem = ([Convert]::ToDecimal($staticMemory)) * 1024 * 1024
Write-Host -F Red "DEBUG: Expected total memory is $expected_mem"
Write-Output "DEBUG: Expected total memory is $expected_mem"


$diff = 100
# Check mem in the VM
# MemTotal in /proc/meminfo is kB
$meminfo_total = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "awk '/MemTotal/{print `$2}' /proc/meminfo"
if (-not $meminfo_total)
{
    Write-Host -F Red "ERROR: Get MemTotal from /proc/meminfo failed"
    Write-Output "ERROR: Get MemTotal from /proc/meminfo failed"
    DisconnectWithVIServer
    return $Aborted
}
Write-Host -F Red "INFO: meminfo_total: $meminfo_total"
Write-Output "INFO: meminfo_total: $meminfo_total"


# Kdump reserved memory size with B, need to devide 1024
$kdump_kernel = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "cat /sys/kernel/kexec_crash_size"
if ( $kdump_kernel -ge 0 )
{
    # Get the acutal total memory size
    $meminfo_total = ([Convert]::ToDecimal($meminfo_total)) + (([Convert]::ToDecimal($kdump_kernel))/1024)
    Write-Host -F Red "INFO: Acutal total memory: $meminfo_total"
    Write-Output "INFO: Acutal total memory: $meminfo_total"

    # Check diff, diff should < standard_diff
    $diff = ($expected_mem - $meminfo_total)/$expected_mem
    if ( $diff -lt $standard_diff -and $diff -gt 0 )
    {
        "Info : Check memory in vm passed, diff is $diff (standard is $standard_diff)"
        Write-Host -F Red "PASS : Complete the memory check. And diff is $diff(standard is $standard_diff)"
        Write-Output "PASS : Complete the memory check. And diff is $diff(standard is $standard_diff)"
        $retVal = $Passed
    }
    else
    {
        Write-Host -F Red "FAIL : Memory check failed. And diff is $diff(standard is $standard_diff)"
        Write-Output "FAIL : Memory check failed. And diff is $diff(standard is $standard_diff)"
    }
}
else
{
    Write-Host -F Red "ERROR: Get kdump memory size from /sys/kernel/kexec_crash_size failed"
    Write-Output "ERROR: Get kdump memory size from /sys/kernel/kexec_crash_size failed"
}


DisconnectWithVIServer
return $retVal
