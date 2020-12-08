########################################################################################
## Description:
## 	Enable Hot cpu and verify it works
##
## Revision:
## 	v1.0.0 - boyang - 10/12/2017 - Build the script
## 	v1.0.1 - boyang - 05/14/2018 - Enhance the script
## 	v1.1.0 - boyang - 05/28/2018 - Not supported in ESXi6.7
########################################################################################


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


# Checking the input arguments.
param([String] $vmName, [String] $hvServer, [String] $testParams)
if (-not $vmName)
{
    "ERROR: VM name cannot be null!"
    exit 100
}

if (-not $hvServer)
{
    "ERROR: hvServer cannot be null!"
    exit 100
}

if (-not $testParams)
{
    Throw "ERROR: No test parameters specified"
}


# Checking the input arguments
"TestParams : '${testParams}'"


# Parse the test parameters
$rootDir = $null
$sshKey = $null
$ipv4 = $null
$cpuNum = 0
$cpuAfter = 0

$params = $testParams.Split(";")
foreach ($p in $params)
{
    $fields = $p.Split("=")
    switch ($fields[0].Trim())
    {
    "sshKey"       { $sshKey = $fields[1].Trim() }
    "rootDir"      { $rootDir = $fields[1].Trim() }
    "ipv4"         { $ipv4 = $fields[1].Trim() }
    "VCPU"         { $cpuNum = [int]$fields[1].Trim() }
    "VCPU_After"   { $cpuAfter = [int]$fields[1].Trim() }
    default        {}
    }
}

# Check all parameters are valid
if (-not $rootDir)
{
    "WARNING: no rootdir was specified"
}
else
{
    if ( (Test-Path -Path "${rootDir}") )
    {
        cd $rootDir
    }
    else
    {
        "WARNING: rootdir '${rootDir}' does not exist"
    }
}


# Source the tcutils.ps1 file
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


$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj)
{
    LogPrint "ERROR: Unable to Get-VM with $vmName."
    DisconnectWithVIServer
	return $Aborted
}


# Sometimes $Failed in RHEL6 platform, NOT A BUG
$DISTRO = GetLinuxDistro ${ipv4} ${sshKey}
if ($DISTRO -eq "RedHat6")
{
    LogPrint "ERROR: CPU hot-plugin failed in $DISTRO in BZ is status NOTABUG."    
    DisconnectWithVIServer
    return $Skipped
}


# As ESXi6.7 has been released, but cpu hot-plugin isn't supported by CLI.
$host_obj = Get-VMHost -Name $hvServer
$host_ver = $host_obj.version
LogPrint "DEBUG: host_ver: $host_ver"
if ($host_ver -ge "6.7.0")
{
    LogPrint "ERROR: CPU hot-plugin isn't supproted in $host_ver"    
    DisconnectWithVIServer
    return $Skipped
}


# $cpuNum is from xml(it is 1) which mustn't be -eq VM's default cpu number(2)
# So, this will void default cpu number(2) is -eq $cpuAfter, that verify hot cpu
$vmCPUNum = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "grep processor /proc/cpuinfo | wc -l"
if ($vmCPUNum -ne $cpuNum)
{
    LogPrint "ERROR: VM's cpu number $vmCPUNum -ne $cpuNum in setup phrase"    
    return $Aborted
}
LogPrint "INFO: VM's cpu number $vmCPUNum -eq $cpuNum in setup phrase."


# Hot CPU to set the VM cpu number to VCPU_After
$ret = Set-VM -VM $vmObj -NumCpu $cpuAfter -Confirm:$False
LogPrint "DEBUG: ret: $ret."


# Confirm the new cpu number after hot add
$vmCPUNum = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "grep processor /proc/cpuinfo | wc -l"
if ($vmCPUNum -ne $cpuAfter)
{
    LogPrint "ERROR: VM's cpu number $vmCPUNum -ne $cpuAfter"    
    return $Aborted
}
else
{

    LogPrint "VM's cpu number $vmCPUNum -eq $cpuAfter in setup phrase"   
	
    LogPrint "Check these cpus hot-add online"
    $online = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "cat /sys/devices/system/cpu/online"
    if ( ($online.Split("-"))[1] -ne ($cpuAfter - 1))
    {
        LogPrint "FAIL: VM's cpu hot-add number is correct. But online isn't correct" 
    }
    else
    {
        LogPrint "PASS: VM's cpu hot-add number and online are correct"
        $retVal = $Passed
    }
}


DisconnectWithVIServer
return $retVal
