########################################################################################
## Description:
##  Boot a Guest with RDMA NIC and check RDMA NIC
##
## Revision:
##  v1.0.0 - ruqin  - 08/15/2018 - Build the script.
##  v1.1.0 - boyang - 10/16/2019 - Skip test when host hardware hasn't RDMA NIC.
########################################################################################


<#
.Synopsis
    Check RDMA NIC after boot guest
.Description
    Check RDMA NIC after boot guest
.Parameter vmName
    Name of the test VM.
.Parameter testParams
    Semicolon separated list of test parameters.
#>


# Checking the input arguments.
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
    Throw "Error: No test parameters specified!"
}


# Output test parameters so they are captured in log file.
"TestParams : '${testParams}'"


# Parse the test parameters.
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


# Check all parameters are valid.
if (-not $rootDir) {
    "Warn : no rootdir was specified"
}
else {
    if ( (Test-Path -Path "${rootDir}") ) {
        Set-Location $rootDir
    }
    else {
        "Warn : rootdir '${rootDir}' does not exist."
    }
}

if ($null -eq $sshKey) {
    "FAIL: Test parameter sshKey was not specified."
    return $False
}

if ($null -eq $ipv4) {
    "FAIL: Test parameter ipv4 was not specified."
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
    LogPrint "ERROR: Unable to Get-VM with ${vmName}."
    DisconnectWithVIServer
    return $Aborted
}


# Get the Guest version.
$DISTRO = GetLinuxDistro ${ipv4} ${sshKey}
LogPrint "DEBUG: DISTRO: $DISTRO"
if (-not $DISTRO) {
    LogPrint "ERROR: Guest OS version is NULL."
    DisconnectWithVIServer
    return $Aborted
}


# Get Old Adapter Name of VM.
$Command = "ip a|grep `$(echo `$SSH_CONNECTION| awk '{print `$3}')| awk '{print `$(NF)}'"
$Old_Adapter = Write-Output y | bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command
LogPrint "DEBUG: Old_Adapter: $Old_Adapter"
if ( $null -eq $Old_Adapter) {
    LogPrint "ERROR : Cannot get Server_Adapter from first adapter"
    DisconnectWithVIServer
    return $Aborted
}


# Get pci status.
$Command = "lspci | grep -i infiniband"
$pciInfo = Write-Output y | bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command
LogPrint "DEBUG: pciInfo: $pciInfo"
if ( $pciInfo -notlike "*Infiniband controller: VMware Paravirtual RDMA controller*") {
    LogPrint "ERROR : Cannot get pvRDMA info from guest."
    DisconnectWithVIServer
    return $Failed
}


# Install required packages.
$sts = SendCommandToVM $ipv4 $sshKey "yum install -y rdma-core infiniband-diags"
LogPrint "DEBUG: sts: $sts"
if (-not $sts) {
    LogPrint "ERROR : YUM cannot install required packages."
    DisconnectWithVIServer
    return $Failed
}


# Make sure the vmw_pvrdma is loaded.
$Command = "lsmod | grep vmw_pvrdma | wc -l"
$modules = [int] (Write-Output y | bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command)
LogPrint "DEBUG: modules: $modules"
if ($modules -eq 0) {
    LogPrint "ERROR : Cannot find any pvRDMA module."
    DisconnectWithVIServer
    return $Failed
}
else {
    $retVal = $Passed
}


DisconnectWithVIServer
return $retVal
