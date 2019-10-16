########################################################################################
## Description:
##  Load and unload the vmw_pvrdma module
##
## Revision:
##  v1.0.0 - ruqin - 8/16/2018 - Build the script.
##  v1.1.0 - boyang - 10/16.2019 - Skip test when host hardware hasn't RDMA NIC.
########################################################################################


<#
.Synopsis
    Load and unload the vmw_pvrdma module for 10 minx and check system status 

.Description
       <test>
            <testName>rdma_reload_vmx_pvrdma</testName>
            <testID>ESX-RDMA-002</testID>
            <setupScript>
                <file>setupscripts\add_pvrdma.ps1</file>
            </setupScript>
            <testScript>testscripts\rdma_reload_vmx_pvrdma.ps1</testScript>
            <testParams>
                <param>TC_COVERED=RHEL-111206</param>
            </testParams>
            <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
            <timeout>900</timeout>
            <onError>Continue</onError>
            <noReboot>False</noReboot>
        </test>

.Parameter vmName
    Name of the test VM.

.Parameter testParams
    Semicolon separated list of test parameters.
#>


param([String] $vmName, [String] $hvServer, [String] $testParams)


# Checking the input arguments
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


$skip = SkipTestInHost $hvServer "6.0.0","6.5.0","6.7.0"
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
LogPrint "INFO: Guest OS version is $DISTRO"


# Different Guest DISTRO
if ($DISTRO -ne "RedHat7" -and $DISTRO -ne "RedHat8" -and $DISTRO -ne "RedHat6") {
    LogPrint "ERROR: Guest OS ($DISTRO) isn't supported, MUST UPDATE in Framework / XML / Script"
    DisconnectWithVIServer
    return $Skipped
}


# Make sure the vmw_pvrdma is loaded 
$Command = "lsmod | grep vmw_pvrdma | wc -l"
$modules = [int] (Write-Output y | bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command)
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
$Command = "dmesg | grep -i `"Call Trace`" | wc -l"
$Error_Num = [int] (bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command)
if ($Error_Num -ne 0) {
    LogPrint "ERROR: System has error during load and unload vmw_pvrdma module"
    DisconnectWithVIServer
    return $Failed
}else{
    $retVal = $Passed
}


DisconnectWithVIServer
return $retVal