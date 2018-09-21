###############################################################################
##
## Description:
##  Change the MTU of a SR-IOV
##
## Revision:
##  v1.0.0 - ruqin - 8/23/2018 - Build the script
##
###############################################################################


<#
.Synopsis
    Change the MTU of a SR-IOV

.Description
       <test>
            <testName>sriov_mtu_check</testName>
            <testID>ESX-SRIOV-002</testID>
            <setupScript>
                <file>SetupScripts\revert_guest_B.ps1</file>
                <file>SetupScripts\add_sriov.ps1</file>
            </setupScript>
            <cleanupScript>
                <file>SetupScripts\shutdown_guest_B.ps1</file>
                <file>SetupScripts\disable_memory_reserve.ps1</file>
                <file>SetupScripts\reset_migration.ps1</file>
            </cleanupScript>
            <testScript>testscripts\sriov_mtu_check.ps1</testScript>
            <testParams>
                <param>TC_COVERED=RHEL-113877,RHEL6-49164</param>
                <param>mtuChange=True</param>
                <param>mtu=9000</param>
                <param>memoryReserve=true</param>
            </testParams>
            <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
            <timeout>600</timeout>
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
$mtu = $null

$params = $testParams.Split(";")
foreach ($p in $params) {
    $fields = $p.Split("=")
    switch ($fields[0].Trim()) {
        "sshKey" { $sshKey = $fields[1].Trim() }
        "rootDir" { $rootDir = $fields[1].Trim() }
        "ipv4" { $ipv4 = $fields[1].Trim() }
        "mtu" { $mtu = $fields[1].Trim() }
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

if ($null -eq $mtu) {
    $mtu = 1500
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
#
###############################################################################


# Get VM object
$retVal = $Failed
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj) {
    LogPrint "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
    return $Aborted
}


# Ready another VM
$GuestBName = $vmObj.Name.Split('-')
# Get another VM by change Name
$GuestBName[-1] = "B"
$GuestBName = $GuestBName -join "-"


# disable memory reserve
$status = DisableMemoryReserve $GuestBName $hvServer
# Add sriov nic for guest B
$status = AddSrIOVNIC $GuestBName $hvServer $true
if ( -not $status[-1] ) {
    LogPrint "ERROR: Guest B sriov nic add failed"
    DisconnectWithVIServer
    return $Aborted
}


# Start GuestB
$GuestB = Get-VMHost -Name $hvServer | Get-VM -Name $GuestBName
Start-VM -VM $GuestB -Confirm:$false -RunAsync:$true -ErrorAction SilentlyContinue
if (-not $?) {
    LogPrint "ERROR: Cannot start VM"
    DisconnectWithVIServer
    return $Aborted
}


# Find out new add sriov nic for Guest A
$nics += @($(FindAllNewAddNIC $ipv4 $sshKey))
if ($null -eq $nics) {
    LogPrint "ERROR: Cannot find new add SR-IOV NIC" 
    DisconnectWithVIServer
    return $Failed
}
else {
    $sriovNIC_A = $nics[-1]
}
LogPrint "INFO: New NIC for GuestA is $sriovNIC_A"


# Config SR-IOV NIC IP addr for Guest A and MTU
$IPAddr_guest_A = "192.168.99." + (Get-Random -Maximum 124 -Minimum 2)
$status = ConfigIPforNewDevice $ipv4 $sshKey $sriovNIC_A ($IPAddr_guest_A + "/24") $mtu
if ( -not $status[-1]) {
    LogPrint "ERROR : Guest A Config IP Failed"
    DisconnectWithVIServer
    return $Aborted
}
LogPrint "INFO: Guest A SR-IOV NIC IP add is $IPAddr_guest_A"


# Install tcpdump at GuestA
$status = SendCommandToVM $ipv4 $sshKey "yum install tcpdump -y"
if (-not $status[-1]) {
    LogPrint "Error: Cannot install tcpdump"
    DisconnectWithVIServer
    return $Aborted
}


# Wait for GuestB SSH ready
if ( -not (WaitForVMSSHReady $GuestBName $hvServer $sshKey 300)) {
    LogPrint "ERROR : Cannot start SSH"
    DisconnectWithVIServer
    return $Aborted
}
LogPrint "INFO: Ready SSH"


# Get GuestB IP addr
$ipv4Addr_B = GetIPv4 -vmName $GuestBName -hvServer $hvServer
$GuestB = Get-VMHost -Name $hvServer | Get-VM -Name $GuestBName


# Find out new add SR-IOV nic for Guest B
$nics += @($(FindAllNewAddNIC $ipv4Addr_B $sshKey))
if ($null -eq $nics) {
    LogPrint "ERROR: Cannot find new add SR-IOV NIC" 
    DisconnectWithVIServer
    return $Aborted
}
else {
    $sriovNIC = $nics[-1]
}
LogPrint "INFO: New NIC for Guest B is $sriovNIC"


# Config SR-IOV NIC IP addr for Guest B and MTU
$IPAddr_guest_B = "192.168.99." + (Get-Random -Maximum 254 -Minimum 125)
$status = ConfigIPforNewDevice $ipv4Addr_B $sshKey $sriovNIC ($IPAddr_guest_B + "/24") $mtu
if ( -not $status[-1]) {
    LogPrint "ERROR : Guest B Config IP Failed"
    DisconnectWithVIServer
    return $Aborted
}
LogPrint "INFO: Guest B SR-IOV NIC IP add is $IPAddr_guest_B"


$packetSize = $mtu - 28
# Ping Guest A from Guest B
$Command = "ping -s $packetSize -M do -c 50 -W 1 $IPAddr_guest_A"
$proc = Start-Process .\bin\plink.exe -ArgumentList "-i ssh\${sshKey} root@${ipv4Addr_B} ${Command}" -PassThru -WindowStyle Hidden


# Use tcpdump to check the packet is not fragmented
LogPrint "INFO: Start tcpdump to receive Ping"
$Command = "timeout 100 tcpdump -n -v -i $sriovNIC_A -l -c 20 icmp and src $IPAddr_guest_B | grep 'offset 0'| grep 'length $mtu' | wc -l"
$packetsCount = [int] (bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command)
if ($packetsCount -ne 20) {
    LogPrint "ERROR: Packet is fragmented or tcpdump is timeout" 
    DisconnectWithVIServer
    return $Failed
}


# Check Ping results
$handle = $proc.Handle
$proc.WaitForExit()
LogPrint "INFO: Handle is $handle, Exit Code is $($proc.ExitCode)"
if ($proc.ExitCode -ne 0) {
    LogPrint "ERROR: Exit Code is not 0" 
    DisconnectWithVIServer
    return $Failed 
}
else {
    $retVal = $Passed
}


DisconnectWithVIServer
return $retVal
