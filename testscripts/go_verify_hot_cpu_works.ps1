###############################################################################
##
## Description:
##   Enable Hot cpu and verify it works
##
###############################################################################
##
## Revision:
## V1.0 - boyang - 10/12/2017 - Build the script
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
    "VCPU_After"         { $cpuAfter = [int]$fields[1].Trim() }
    
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

###############################################################################
#
# Main Body
#
###############################################################################
   
$retVal = $Failed

$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj)
{
    Write-Error -Message "CheckModules: Unable to create VM object for VM $vmName" -Category ObjectNotFound -ErrorAction SilentlyContinue
    return $Aborted
}

#
# $cpuNum is from xml(it is 1) which mustn't be -eq VM's default cpu number(2)
# So, this will void default cpu number(2) is -eq $cpuAfter, that verify hot cpu
#
$vmCPUNum = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "grep processor /proc/cpuinfo | wc -l"
if ($vmCPUNum -ne $cpuNum)
{
    Write-Host -F Yellow "WARNING: VM's cpu number $vmCPUNum -ne $cpuNum in setup phrase......."
    Write-Output "WARNING: VM's cpu number $vmCPUNum -ne $cpuNum in setup phrase"    
    return $Aborted
}
else
{
    Write-Host -F Green "VM's cpu number $vmCPUNum -eq $cpuNum in setup phrase......."
    Write-Output "VM's cpu number $vmCPUNum -eq $cpuNum in setup phrase"    
}

#
# Set the VM cpu number to VCPU_After
#
$retSet = Set-VM -VM $vmObj -NumCpu $cpuAfter -Confirm:$False
if ($? -ne $True)
{
    Write-Host -F Yellow "WARNING: Can't set the VM's CPU number to $cpuAfter under hot-add cpu feature......."
    Write-Output "WARNING: Can't set the VM's CPU number to $cpuAfter under hot-add cpu feature" 
    return $Aborted
}

# Confirm the new cpu number after hot add
$vmCPUNum = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "grep processor /proc/cpuinfo | wc -l"
if ($vmCPUNum -ne $cpuAfter)
{
    Write-Host -F Yellow "WARNING: VM's cpu number $vmCPUNum -ne $cpuAfter......."
    Write-Output "WARNING: VM's cpu number $vmCPUNum -ne $cpuAfter"    
    return $Aborted
}
else
{

    Write-Host -F Green "VM's cpu number $vmCPUNum -eq $cpuAfter in setup phrase......."
    Write-Output "VM's cpu number $vmCPUNum -eq $cpuAfter in setup phrase"   
	
    Write-Host -F Gray "Check these cpus hot-add online......."
    Write-Output "Check these cpus hot-add online"
    $online = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "cat /sys/devices/system/cpu/online"
    if ( ($online.Split("-"))[1] -ne ($cpuAfter - 1))
    {
        Write-Host -F Red "FAIL: VM's cpu hot-add number is correct. But online isn't correct......."
        Write-Output "FAIL: VM's cpu hot-add number is correct. But online isn't correct" 
    }
    else
    {
        Write-Host -F Green "PASS: VM's cpu hot-add number and online are correct......."
        Write-Output "PASS: VM's cpu hot-add number and online are correct"
        $retVal = $Passed
    }
}

DisconnectWithVIServer
return $retVal
