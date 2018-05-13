###############################################################################
##
## Description:
##  Check reboot of the VM
##
##
## Revision:
##  v1.0.0 - hhei - 1/6/2017 - Check reboot of the VM
##  v1.0.1 - boyang - 05/11/2018 - Enhance the script and exit 100 if false
##
###############################################################################


<#
.Synopsis
    reboot in vm.

.Description
    Check reboot in vm.

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


# Execute 'reboot' commnad in the VM
bin\plink.exe -i ssh\${sshKey} root@${ipv4} 'reboot'


# Sleep for seconds to wait for the VM stopping firstly
Start-Sleep -seconds 6


# Wait for the VM booting
$ret = WaitForVMSSHReady $vmName $hvServer ${sshKey} 300
if ($ret -eq $true)
{
    Write-Host -F Red "PASS: Complete the booting"
    Write-Output "PASS: Complete the booting"
    $retVal = $Passed
}
else
{
    Write-Host -F Red "FAIL: The booting failed"
    Write-Output "FAIL: The booting failed"
}


DisconnectWithVIServer
return $retVal
