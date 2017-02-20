###############################################################################
##
## Description:
##   Check memory in vm
##   Return passed, case is passed; return failed, case is failed
##
###############################################################################
##
## Revision:
## v1.0 - hhei - 1/9/2017 - Check memory in vm.
## v1.1 - hhei - 2/6/2017 - Remove TC_COVERED and update return value
##                          true is changed to passed,
##                          false is changed to failed.
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
    exit
}

if (-not $hvServer)
{
    "Error: hvServer cannot be null!"
    exit
}

if (-not $testParams)
{
    Throw "Error: No test parameters specified"
}

#
# Display the test parameters so they are captured in the log file
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

$staticMemory = ConvertStringToDecimal $mem.ToUpper()

$Result = $Failed
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
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
    if ( -not $meminfo_total )
    {
        "Error : Get MemTotal from /proc/meminfo failed"
        $Result = $Failed
    }
    else
    {
        # kdump reserved memory size, in B,need to devide 1024
        $kdump_kernel = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "cat /sys/kernel/kexec_crash_size"
        if ( $kdump_kernel -ge 0 )
        {

            $meminfo_total = ([Convert]::ToDecimal($meminfo_total)) + (([Convert]::ToDecimal($kdump_kernel))/1024)
            "Info : Acutal total memory in vm is $meminfo_total"

            $diff = ($expected_mem - $meminfo_total)/$expected_mem
            if ( $diff -lt $standard_diff -and $diff -gt 0 )
            {
                "Info : Check memory in vm passed, diff is $diff (standard is $standard_diff)"
                $Result = $Passed
            }
            else
            {
                "Error : Check memory in vm failed, actual is: $diff (standard is $standard_diff)"
                $Result = $Failed
            }
        }
        else
        {
            "Error : Get kdump memory size from /sys/kernel/kexec_crash_size failed"
            $Result = $Failed
        }
    }

}
"Info : go_check_memory.ps1 script completed"
DisconnectWithVIServer
return $Result
