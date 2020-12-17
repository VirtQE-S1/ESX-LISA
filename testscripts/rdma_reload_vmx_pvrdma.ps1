########################################################################################
## Description:
##  Load and unload the vmw_pvrdma module
##
## Revision:
##  v1.0.0 - ruqin - 8/16/2018 - Build the script.
##  v1.1.0 - boyang - 10/16/2019 - Skip test when host hardware hasn't RDMA NIC.
########################################################################################


<#
.Synopsis
    Load and unload the vmw_pvrdma module for 10 minx and check system status 
.Description
    Load and unload the vmw_pvrdma module for 10 minx and check system status 
.Parameter vmName
    Name of the test VM.
.Parameter testParams
    Semicolon separated list of test parameters.
#>


# Checking the input arguments
param([String] $vmName, [String] $hvServer, [String] $testParams)
if (-not $vmName) {
    "Error: VM name cannot be null!"
    exit 100
}

if (-not $hvServer) {
    "Error: hvServer cannot be null!"
    exit 100
}

if (-not $testParams) {
    Throw "Error: No test parameters specified"
}


# Output test parameters so they are captured in log file
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


# Check all parameters are valid
if (-not $rootDir) {
    "WARNING: no rootdir was specified"
}
else {
    if ( (Test-Path -Path "${rootDir}") ) {
        Set-Location $rootDir
    }
    else {
        "WARNING: rootdir '${rootDir}' does not exist"
    }
}

if ($null -eq $sshKey) {
    "FAIL: Test parameter sshKey was not specified"
    return $False
}

if ($null -eq $ipv4) {
    "FAIL: Test parameter ipv4 was not specified"
    return $False
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


$skip = SkipTestInHost $hvServer "6.0.0"
if($skip)
{
    return $Skipped
}


$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj) {
    LogPrint "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
    return $Aborted
}


# Get the Guest version
$DISTRO = GetLinuxDistro ${ipv4} ${sshKey}
LogPrint "DEBUG: DISTRO: $DISTRO"
if (-not $DISTRO) {
    LogPrint "ERROR: Guest OS version is NULL"
    DisconnectWithVIServer
    return $Aborted
}


# Make sure the vmw_pvrdma is loaded 
$Command = "lsmod | grep vmw_pvrdma | wc -l"
$modules = [int] (Write-Output y | bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command)
LogPrint "DEBUG: modules: ${modules}."
if ($modules -eq 0) {
    LogPrint "ERROR : Cannot find any pvRDMA module"
    DisconnectWithVIServer
    return $Aborted
}


# Unload and load vmw_pvrdma module
$Command = "while true; do modprobe -r vmw_pvrdma; modprobe vmw_pvrdma; done"
Start-Process .\bin\plink.exe -ArgumentList "-i ssh\${sshKey} root@${ipv4} ${Command}" -PassThru -WindowStyle Hidden
LogPrint "INFO: vmw_pvrdma while loop is running"


# Loop runing for 10 mins
Start-Sleep -Seconds 600


# Check System dmesg
$status = CheckCallTrace $ipv4 $sshKey
if (-not $status[-1]) {
    Write-Host -F Red "ERROR: Found $($status[-2]) in msg."
    Write-Output "ERROR: Found $($status[-2]) in msg."
}
else {
    Write-Host -F Red "INFO: NO call trace found."
    Write-Output "INFO: NO call trace found."
    $retVal = $Passed
}


DisconnectWithVIServer
return $retVal
