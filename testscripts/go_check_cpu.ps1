###############################################################################
##
## Description:
##   Check CPU count in the VM
##
## Revision:
##  v1.0.0 - hhei - 01/6/2017 - Check cpu count in vm
##  v1.0.1 - hhei - 01/10/2017 - Update log info
##  v1.0.2 - hhei - 02/6/2017 - Remove TC_COVERED and update return value
##  v1.0.3 - boyang - 05/10/2018 - Enhance the script and exit 100 if false
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
    "VCPU"         { $numCPUs = [int]$fields[1].Trim() }
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


# Check CPU count in the VM
$vm_num = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "grep processor /proc/cpuinfo | wc -l"
if ($vm_num -eq $numCPUs)
{
    Write-Host -F Red "PASS: CPU count in the VM is correct"
    Write-Output "PASS: CPU count in the VM is correct"
    $retVal = $Passed
}
else
{
    Write-Host -F Red "FAIL: CPU count in the VM is incorrect"
    Write-Output "FAIL: CPU count in the VM is incorrect"
}


DisconnectWithVIServer
return $retVal
