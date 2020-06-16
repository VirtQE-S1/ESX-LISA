###############################################################################
##
## Description:
##  Check the VM OS logs after first boot
##
##
## Revision:
##  v1.0.0 - ldu - 10/23/2019 - Build Scripts
##
###############################################################################


<#
.Synopsis
go_check_logs

.Description
    <test>
        <testName>go_check_logs</testName>
        <testID>ESX-GO-023</testID>
        <testScript>testscripts/go_check_logs.ps1</testScript  >
        <files>remote-scripts/utils.sh</files>
        <testParams>
            <param>TC_COVERED=RHEL6-0000,RHEL-149710</param>
        </testParams>
        <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
        <timeout>600</timeout>
        <onError>Continue</onError>
        <noReboot>False</noReboot>
    </test>

.Parameter vmName
    Name of the test VM.

.Parameter testParams
    Semicolon separated list of test parameters.
#>


param([String] $vmName, [String] $hvServer, [String] $testParams)


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


$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj)
{
    Write-Host -F Red "ERROR: Unable to Get-VM with $vmName"
    Write-Output "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
	return $Aborted
}

#Check the kernel version, if kernel version below then 162

# Check Call Trace
$status = CheckCallTrace $ipv4 $sshKey
if (-not $status[-1]) {
    Write-Host -F Red "ERROR: Found $($status[-2]) in msg."
    Write-Output "ERROR: Found $($status[-2]) in msg."
    DisconnectWithVIServer
    return $Failed
}


# Check failed, backtrace, error logs in dmesg 
$fail_check = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "dmesg | grep -v 'failed to assign \|Ignore above error' | grep -E 'fail|backtrace|error'"
if ($null -eq $fail_check)
{
    $retVal = $Passed
    LogPrint "INFO: After boot, NO $fail_check failed log found."
}
else{
    $version = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "rpm -qa kernel" 
    $ver_num = $($version.split("-"))[2]
    LogPrint "DEBUG: kernel version is: ${version} and kernel ver_num is $ver_num."
    if ($ver_num -lt 162) {
        LogPrint "INFO: The kernel version older then 162."
        if ("$fail_check" -match "Perf event create on CPU 0 failed with -2")
        {
            LogPrint "INFO: it's a know issue,ignore this failed log $fail_check."
            DisconnectWithVIServer
            return $Skipped
        }
        LogPrint "ERROR: After boot, FOUND $fail_check failed log in demsg."  
    }
    
}


DisconnectWithVIServer
return $retVal
