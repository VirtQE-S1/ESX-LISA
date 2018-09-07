###############################################################################
##
## Description:
##  Boot a Guest with SR-IOV NIC which owns a manual MAC address
##
## Revision:
##  v1.0.0 - ruqin - 09/05/2018 - Build the script
##
###############################################################################


<#
.Synopsis
    Boot a Guest with SR-IOV NIC which owns a manual MAC address 

.Description
       <test>
            <testName>sriov_manual_mac</testName>
            <testID>ESX-SRIOV-004</testID>
            <setupScript>
                <file>setupscripts\add_sriov.ps1</file>
            </setupScript>
            <cleanupScript>
                <file>SetupScripts\disable_memory_reserve.ps1</file>
            </cleanupScript>
            <testScript>testscripts\sriov_manual_mac.ps1</testScript>
            <testParams>
                <param>TC_COVERED=RHEL-113886,RHEL6-49172</param>
            </testParams>
            <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
            <timeout>300</timeout>
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


###############################################################################
#
# Main Body
# ############################################################################### 


$retVal = $Failed
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


# Poweroff VM
$status = Stop-VM $vmObj -Confirm:$False
if (-not $?) {
    LogPrint "ERROR : Cannot stop VM $vmName, $status"
    DisconnectWithVIServer
    return $Aborted
}


# Refresh status
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj) {
    LogPrint "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
    return $Aborted
}


# Mac address generate
$macAddress = (0..5 | ForEach-Object { '{0:x}{1:x}' -f (Get-Random -Minimum 0 -Maximum 15),(Get-Random -Minimum 0 -Maximum 15)})  -join ':'
LogPrint "INFO: Generate mac address is $macAddress"


# Get sriov nic
$nic = Get-NetworkAdapter -VM $vmObj -Name "*SR-IOV*"
# Set with new mac address
$status = Set-NetworkAdapter -NetworkAdapter $nic -MacAddress $macAddress -Confirm:$false
if (-not $?) {
    LogPrint "ERROR : Cannot setup nic $nic, with mac address $macAddress"
    DisconnectWithVIServer
    return $Failed
}


# Start Guest
$status = Start-VM -VM $vmObj -Confirm:$false -RunAsync:$true -ErrorAction SilentlyContinue
if (-not $?) {
    LogPrint "ERROR : Cannot start VM"
    DisconnectWithVIServer
    return $Aborted
}


# Wait for SSH ready
if ( -not (WaitForVMSSHReady $vmName $hvServer $sshKey 300)) {
    LogPrint "ERROR : Cannot start SSH"
    DisconnectWithVIServer
    return $Aborted
}
LogPrint "INFO: Ready SSH"


# Get another VM IP addr and refresh
$ipv4 = GetIPv4 -vmName $vmName -hvServer $hvServer
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj) {
    LogPrint "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
    return $Aborted
}


# Find out new add Sriov nic
$nics += @($(FindAllNewAddNIC $ipv4 $sshKey))
if ($null -eq $nics) {
    LogPrint "ERROR: Cannot find new add SR-IOV NIC" 
    DisconnectWithVIServer
    return $Failed
}
else {
    $sriovNIC = $nics[-1]
}
LogPrint "INFO: New NIC is $sriovNIC"


# Get nic mac address
$Command = "ip link show $sriovNIC  | grep link | awk '{print `$2}'"
$macGuest = Write-Output y | bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command
if ($macGuest -ne $macAddress) {
   LogPrint "ERROR: mac address $macGuest is different with generate $macAddress" 
   DisconnectWithVIServer
   return $Failed
}else {
    $retVal = $Passed
}


DisconnectWithVIServer
return $retVal
