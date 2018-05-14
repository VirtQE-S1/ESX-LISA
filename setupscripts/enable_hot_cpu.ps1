###############################################################################
##
## Description:
## Hot enable CPU feature
##
###############################################################################
##
## Revision:
## V1.0 - boyang - 10/12/2017 - Build the script
##
###############################################################################
<#
.Synopsis
    Hot enable memory feature in setup phrase

.Description
    Hot enable memory feature in setup phrase

.Parameter vmName
    Name of the test VM

.Parameter testParams
    Semicolon separated list of test parameters
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


Write-Host -F Red "INFO: Is starting to enable hot-cpu feature"
Write-Output "INFO: Is starting to enable hot-cpu feature"
$vmView = Get-vm $vmObj | Get-View
Write-Host -F Red "DEBUG: vmView: $vmView"
Write-Output "DEBUG: vmView: $vmView"

$vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
Write-Host -F Red "DEBUG: vmConfigSpec: $vmConfigSpec"
Write-Output "DEBUG: vmConfigSpec: $vmConfigSpec"

$extra = New-Object VMware.Vim.optionvalue
Write-Host -F Red "DEBUG: extra: $extra"
Write-Output "DEBUG: extra: $extra"
$extra.Key="vcpu.hotadd"
$extra.Value="true"
Write-Host -F Red "DEBUG: extra2: $extra"
Write-Output "DEBUG: extra2: $extra"

$vmConfigSpec.extraconfig += $extra
Write-Host -F Red "DEBUG: vmConfigSpec2: $vmConfigSpec"
Write-Output "DEBUG: vmConfigSpec2: $vmConfigSpec"

$vmView.ReconfigVM($vmConfigSpec)
Write-Host -F Red "DEBUG: vmView2: $vmView"
Write-Output "DEBUG: vmView2: $vmView"

$retVal = $Passed

return $retVal
