########################################################################################
## Description:
## 	Hot enable memory feature.
##
## Revision:
## 	v1.0.0 - boyang - 10/12/2017 - Build the script.
## 	v1.0.1 - ruqin  - 07/16/2018 - Fix DisconnectWithVIServer ERROR.
########################################################################################


<#
.Synopsis
    Hot enable memory feature
.Description
    Hot enable memory feature in setup phrase
.Parameter vmName
    Name of the test VM
.Parameter testParams
    Semicolon separated list of test parameters
#>


# Checking the input arguments
param([String] $vmName, [String] $hvServer, [String] $testParams)
if (-not $vmName) {
    "ERROR: VM name cannot be null!"
    exit
}

if (-not $hvServer) {
    "ERROR: hvServer cannot be null!"
    exit
}

if (-not $testParams) {
    Throw "ERROR: No test parameters specified."
}


# Display the test parameters so they are captured in the log file
"TestParams : '${testParams}'"


# Parse the test parameters
$rootDir = $null
$sshKey = $null
$ipv4 = $null

$params = $testParams.Split(";")
foreach ($p in $params) {
    $fields = $p.Split("=")
    switch ($fields[0].Trim()) {
        "sshKey" { $sshKey = $fields[1].Trim() }
        "rootDir" { $rootDir = $fields[1].Trim() }
        "ipv4" { $ipv4 = $fields[1].Trim() }
        default {}
    }
}

if (-not $rootDir) {
    "Warn : no rootdir was specified"
}
else {
    if ( (Test-Path -Path "${rootDir}") ) {
        Set-Location $rootDir
    }
    else {
        "Warn : rootdir '${rootDir}' does not exist"
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
# Main Body
########################################################################################
$retVal = $Failed


$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj) {
    Write-ERROR -Message "INFO: Unable to create VM object for VM $vmName" -Category ObjectNotFound -ERRORAction SilentlyContinue
    DisconnectWithVIServer
    return $Aborted
}
else {
    LogPrint "INFO: Start to enable hot-mem feature."
    # $vmObj.ExtensionData.config
    $vmView = Get-vm $vmObj | Get-View
    $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
    $vmConfigSpec.MemoryHotAddEnabled = $true
    $vmConfigSpec.CPUHotAddEnabled = $true
    # $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
    # $extra = New-Object VMware.Vim.optionvalue
    # $extra.Key="mem.hotadd"
    # $extra.Value="true"
    # $vmConfigSpec.extraconfig += $extra
    $vmView.ReconfigVM($vmConfigSpec)
    $retVal = $Passed
}


return $retVal
