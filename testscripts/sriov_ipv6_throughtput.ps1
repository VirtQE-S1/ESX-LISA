########################################################################################
## Description:
##  Test a 10G network IPv6 throughput via SR-IOV
##
## Revision:
##  v1.0.0 - ruqin - 09/19/2018 - Build the script
##  v1.1.0 - boyang - 10/16.2019 - Skip test when host hardware hasn't RDMA NIC.
########################################################################################


<#
.Synopsis
    Test a 10G network IPv6 throughput via SR-IOV 

.Description
      <test>
            <testName>sriov_ipv6_throughtput</testName>
            <testID>ESX-SRIOV-008</testID>
            <setupScript>
                <file>SetupScripts\change_cpu.ps1</file>
                <file>SetupScripts\change_memory.ps1</file>
                <file>SetupScripts\revert_guest_B.ps1</file>
                <file>setupscripts\add_sriov.ps1</file>
            </setupScript>
            <cleanupScript>
                <file>SetupScripts\shutdown_guest_B.ps1</file>
                <file>SetupScripts\disable_memory_reserve.ps1</file>
                <file>SetupScripts\reset_migration.ps1</file>
            </cleanupScript>
            <testScript>testscripts\sriov_ipv6_throughtput.ps1</testScript>
            <testParams>
                <param>dstHost6.7=10.73.196.95,10.73.196.97</param>
                <param>dstHost6.5=10.73.199.191,10.73.196.230</param>
                <param>dstDatastore=datastore</param>
                <param>memoryReserve=True</param>
                <param>VCPU=8</param>
                <param>VMMemory=4GB</param>
                <param>NetworkBandWidth=10</param>
                <param>TC_COVERED=RHEL-113881,RHEL6-49168</param>
            </testParams>
            <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
            <timeout>1500</timeout>
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
$dstHost6_7 = $null
$dstHost6_5 = $null
$dstDatastore = $null
$NetworkBandWidth = $null

$params = $testParams.Split(";")
foreach ($p in $params) {
    $fields = $p.Split("=")
    switch ($fields[0].Trim()) {
        "sshKey" { $sshKey = $fields[1].Trim() }
        "rootDir" { $rootDir = $fields[1].Trim() }
        "ipv4" { $ipv4 = $fields[1].Trim() }
        "dstHost6.7" { $dstHost6_7 = $fields[1].Trim()}
        "dstHost6.5" { $dstHost6_5 = $fields[1].Trim()}
        "dstDatastore" { $dstDatastore = $fields[1].Trim() }
        "NetworkBandWidth" { $NetworkBandWidth = $fields[1].Trim() }
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


if ($null -eq $dstDatastore) {
    "FAIL: Test parameter dstDatastore was not specified"
    return $False 
}


if ($null -eq $NetworkBandWidth) {
    "FAIL: Test parameter NetworkBandWidth was not specified"
    return $False  
}


if (-not $dstHost6_7 -or -not $dstHost6_5) {
    "INFO: dstHost 6.7 is $dstHost6_7"
    "INFO: dstHost 6.5 is $dstHost6_5"
    "Warn : dstHost was not specified"
    return $false
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


$skip = SkipTestInHost $hvServer "6.0.0","6.7.0"
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


# iperf3 rhel6 url
$ipef3URL = "http://download.eng.bos.redhat.com/brewroot/vol/rhel-6/packages/iperf3/3.3/2.el6eng/x86_64/iperf3-3.3-2.el6eng.x86_64.rpm"


# Specify dst host
$dstHost = FindDstHost -hvServer $hvServer -Host6_5 $dstHost6_5 -Host6_7 $dstHost6_7 -Host7_0 $dstHost7_0
if ($null -eq $dstHost) {
    LogPrint "ERROR: Cannot find required Host"    
    DisconnectWithVIServer
    return $Aborted
}
LogPrint "INFO: Destination Host is $dstHost"


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
if ($DISTRO -ne "RedHat7" -and $DISTRO -ne "RedHat8") {
    LogPrint "ERROR: Guest OS ($DISTRO) isn't supported, MUST UPDATE in Framework / XML / Script"
    DisconnectWithVIServer
    return $Skipped
}


# Store Old datastore
$oldDatastore = Get-Datastore -Name "datastore-*" -VMHost $hvServer
if (-not $oldDatastore) {
    LogPrint "ERROR: Unable to Get required original datastore $oldDatastore"
    DisconnectWithVIServer
    return $Aborted
}


# Get Required Datastore
$shardDatastore = Get-Datastore -VMHost (Get-VMHost $dsthost) | Where-Object {$_.Name -like "*$dstDatastore*"}
if (-not $shardDatastore) {
    LogPrint "ERROR: Unable to Get required shard datastore $shardDatastore"
    DisconnectWithVIServer
    return $Aborted
}
# Print Datastore name
$name = $shardDatastore.Name
LogPrint "INFO: required shard datastore $name"


# Get another VM by change Name
$GuestBName = $vmObj.Name.Split('-')
$GuestBName[-1] = "B"
$GuestBName = $GuestBName -join "-"
$GuestB = Get-VMHost -Name $hvServer | Get-VM -Name $GuestBName


# Change CPU and memory for Guest B
$status = Set-VM -VM $GuestB -NumCpu 8 -MemoryGB 4 -Confirm:$False
if (-not $?) {
    LogPrint "ERROR: Cannot setup guest B for required cpu and memory"
    DisconnectWithVIServer
    return $Aborted 
}


# Add SR-IOV NIC for Guest B
$status = AddSrIOVNIC $GuestBName $hvServer
if ( -not $status[-1]) {
    LogPrint "ERROR: SRIOV NIC adds failed" 
    DisconnectWithVIServer
    return $Aborted
}


# Move Guest B to another host
$task = Move-VM -VMotionPriority High -VM $GuestB -Destination (Get-VMHost $dsthost) `
    -Datastore $shardDatastore -Confirm:$false -RunAsync:$true -ErrorAction SilentlyContinue


# Find out new add SR-IOV nic for Guest A
$nics += @($(FindAllNewAddNIC $ipv4 $sshKey))
if ($null -eq $nics) {
    LogPrint "ERROR: Cannot find new add SR-IOV NIC" 
    $status = Wait-Task -Task $task
    resetGuestSRIOV -vmName $GuestBName -hvServer $hvServer -dstHost $dstHost -oldDatastore $oldDatastore
    DisconnectWithVIServer
    return $Aborted
}
else {
    $sriovNIC = $nics[-1]
}
LogPrint "INFO: New NIC is $sriovNIC"


# Config SR-IOV NIC IP addr for Guest A
$IPAddr_guest_A = "172.31.2." + (Get-Random -Maximum 124 -Minimum 2)
if ( -not (ConfigIPforNewDevice $ipv4 $sshKey $sriovNIC ($IPAddr_guest_A + "/24"))) {
    LogPrint "ERROR : Guest A Config IP Failed"
    $status = Wait-Task -Task $task
    resetGuestSRIOV -vmName $GuestBName -hvServer $hvServer -dstHost $dstHost -oldDatastore $oldDatastore
    DisconnectWithVIServer
    return $Aborted
}
LogPrint "INFO: Guest A SR-IOV NIC IP add is $IPAddr_guest_A"


# Setup ipv6 addr for Guest A
$IPAddr6_guest_A = "fd00::" + ([Convert]::ToString((Get-Random -Maximum 32767 -Minimum 2), 16))
$Command = "nmcli con mod $sriovNIC ipv6.addresses '$($IPAddr6_guest_A + '/64')' ipv6.method manual && `
        nmcli con down $sriovNIC && nmcli con up $sriovNIC"
$status = SendCommandToVM $ipv4 $sshkey $command
if (-not $status) {
    LogPrint "ERROR: Guest A ipv6 config failed"
    resetGuestSRIOV -vmName $GuestBName -hvServer $hvServer -dstHost $dstHost -oldDatastore $oldDatastore
    DisconnectWithVIServer
    return $Aborted
}


# Install iperf3 on Guest A
if ($DISTRO -eq "RedHat6") {
    $Command = "yum localinstall $ipef3URL -y"
}
else {
    $Command = "yum install iperf3 -y"
}
$status = SendCommandToVM $ipv4 $sshkey $command
if (-not $status) {
    LogPrint "ERROR: iperf3 install failed"
    $status = Wait-Task -Task $task
    resetGuestSRIOV -vmName $GuestBName -hvServer $hvServer -dstHost $dstHost -oldDatastore $oldDatastore
    DisconnectWithVIServer
    return $Aborted
}


# Check Migration status
$status = Wait-Task -Task $task
LogPrint "INFO: Migration result is $status"
if (-not $status) {
    resetGuestSRIOV -vmName $GuestBName -hvServer $hvServer -dstHost $dstHost -oldDatastore $oldDatastore
    LogPrint  "ERROR : Cannot move VM to required Host $dsthost"
    DisconnectWithVIServer
    return $Aborted
}


# Refresh Guest B status
$GuestB = Get-VMHost -Name $dstHost | Get-VM -Name $GuestBName
if (-not $GuestB) {
    LogPrint "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
    return $Aborted
}


# Start GuestB
Start-VM -VM $GuestB -Confirm:$false -RunAsync:$true -ErrorAction SilentlyContinue
if (-not $?) {
    LogPrint "ERROR : Cannot start VM"
    resetGuestSRIOV -vmName $GuestBName -hvServer $hvServer -dstHost $dstHost -oldDatastore $oldDatastore
    DisconnectWithVIServer
    return $Aborted
}


# Wait for GuestB SSH ready
if ( -not (WaitForVMSSHReady $GuestBName $dstHost $sshKey 300)) {
    LogPrint "ERROR : Cannot start SSH"
    resetGuestSRIOV -vmName $GuestBName -hvServer $hvServer -dstHost $dstHost -oldDatastore $oldDatastore
    DisconnectWithVIServer
    return $Aborted
}
LogPrint "INFO: Ready SSH"


# Get GuestB VM IP addr
$ipv4Addr_B = GetIPv4 -vmName $GuestBName -hvServer $dstHost
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
LogPrint "INFO: New NIC is $sriovNIC"


# Config SR-IOV NIC IP addr for Guest B
$IPAddr_guest_B = "172.31.2." + (Get-Random -Maximum 254 -Minimum 125)
if ( -not (ConfigIPforNewDevice $ipv4Addr_B $sshKey $sriovNIC ($IPAddr_guest_B + "/24"))) {
    LogPrint "ERROR : Guest B Config IP Failed"
    DisconnectWithVIServer
    return $Aborted
}
LogPrint "INFO: Guest B SR-IOV NIC IP add is $IPAddr_guest_B"


# Setup ipv6 addr for Guest B
$IPAddr6_guest_B = "fd00::" + ([Convert]::ToString((Get-Random -Maximum 65535 -Minimum 32768), 16))
$Command = "nmcli con mod $sriovNIC ipv6.addresses '$($IPAddr6_guest_B + '/64')' ipv6.method manual && `
        nmcli con down $sriovNIC && nmcli con up $sriovNIC"
$status = SendCommandToVM $ipv4Addr_B $sshkey $command
if (-not $status) {
    LogPrint "ERROR: Guest B ipv6 config failed"
    resetGuestSRIOV -vmName $GuestBName -hvServer $hvServer -dstHost $dstHost -oldDatastore $oldDatastore
    DisconnectWithVIServer
    return $Aborted
}


# Install iperf3 on Guest B
if ($DISTRO -eq "RedHat6") {
    $Command = "yum localinstall $ipef3URL -y"
}
else {
    $Command = "yum install iperf3 -y"
}
$status = SendCommandToVM $ipv4Addr_B $sshkey $command
if (-not $status) {
    LogPrint "ERROR: iperf3 install failed"
    resetGuestSRIOV -vmName $GuestBName -hvServer $hvServer -dstHost $dstHost -oldDatastore $oldDatastore
    DisconnectWithVIServer
    return $Aborted
}


### Starting iperf3 test


# Ready iperf3 server in Guest-A
$Command = "iperf3 -s"
$Status = Start-Process .\bin\plink.exe -ArgumentList "-i ssh\${sshKey} root@${ipv4} ${Command}" -PassThru -WindowStyle Hidden
LogPrint "INFO: iperf3 is enable"


# Test Network Connection
$Command = "ping6 $IPAddr6_guest_A -c 5"
$status = SendCommandToVM $ipv4Addr_B $sshkey $command
if ( -not $status) {
    LogPrint "Error : Cannot ping Guest-A from Guest-B"
    resetGuestSRIOV -vmName $GuestBName -hvServer $hvServer -dstHost $dstHost -oldDatastore $oldDatastore
    DisconnectWithVIServer
    return $Aborted
}
LogPrint "INFO: Network is working"


# Start iperf3 test
$total = 0
for ($i = 0; $i -lt 10; $i++) {
    $Command = "iperf3 -t 30 -Z -P16 -c $IPAddr6_guest_A -O10 | grep SUM | grep sender |awk '{print `$6}'"
    $bandwidth = [decimal] (bin\plink.exe -i ssh\${sshkey} root@${ipv4Addr_B} $command)
    if ( -not $bandwidth) {
        LogPrint "Error : iperf3 failed in $GuestBName"
        resetGuestSRIOV -vmName $GuestBName -hvServer $hvServer -dstHost $dstHost -oldDatastore $oldDatastore
        DisconnectWithVIServer
        return $Failed
    }
    LogPrint "INFO: Round $i, bandwidth is $bandwidth"
    $total += $bandwidth
}


# Check bandwidth value
$total = $total / 10
LogPrint "INFO: average bandwidth is $total"
$NetworkBandWidth = ([decimal]$NetworkBandWidth) * 0.9
if ($total -lt $NetworkBandWidth) {
    LogPrint "INFO: Network bandwidth doesn't fit requirement" 
    $retVal = $Failed
}
else {
    $retVal = $Passed
}


# Clean up step
resetGuestSRIOV -vmName $GuestBName -hvServer $hvServer -dstHost $dstHost -oldDatastore $oldDatastore


DisconnectWithVIServer
return $retVal
