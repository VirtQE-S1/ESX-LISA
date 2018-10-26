###############################################################################
##
## Description:
##  Ping successfully between 2 Guests on the different Hosts
##
## Revision:
##  v1.0.0 - ruqin - 8/21/2018 - Build the script
##
###############################################################################


<#
.Synopsis
    Ping successfully between 2 Guests on the different Hosts 

.Description
       <test>
            <testName>rdma_ping_diff_host</testName>
            <testID>ESX-RDMA-004</testID>
            <setupScript>
                <file>SetupScripts\revert_guest_B.ps1</file>
                <file>setupscripts\add_pvrdma.ps1</file>
            </setupScript>
            <cleanupScript>
                <file>SetupScripts\reset_migration.ps1</file>
            </cleanupScript>
            <testScript>testscripts\rdma_ping_diff_host.ps1</testScript>
            <testParams>
                <param>dstHost6.7=10.73.196.95,10.73.196.97</param>
                <param>dstHost6.5=10.73.199.191,10.73.196.230</param>
                <param>dstDatastore=freenas</param>
                <param>TC_COVERED=RHEL-111209,RHEL6-49156</param>
            </testParams>
            <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
            <timeout>1200</timeout>
            <onError>Continue</onError>
            <noReboot>False</noReboot>
        </test>

.Parameter vmName
    Name of the test VM.

.Parameter testParams
    Semicolon separated list of test parameters.
#>


param([String] $vmName, [String] $hvServer, [String] $testParams)


#
# Checking the input arguments
#
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
$dstHost6_7 = $null
$dstHost6_5 = $null
$dstDatastore = $null

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
        default {}
    }
}


#
# Check all parameters are valid
#
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


if (-not $dstHost6_7 -or -not $dstHost6_5) {
    "INFO: dstHost 6.7 is $dstHost6_7"
    "INFO: dstHost 6.5 is $dstHost6_5"
    "Warn : dstHost was not specified"
    return $false
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
# ############################################################################### 


$retVal = $Failed
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj) {
    LogPrint "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
    return $Aborted
}


# Specify dst host
$dstHost = FindDstHost -hvServer $hvServer -Host6_5 $dstHost6_5 -Host6_7 $dstHost6_7
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
if ($DISTRO -ne "RedHat7" -and $DISTRO -ne "RedHat8" -and $DISTRO -ne "RedHat6") {
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
$shardDatastore = Get-Datastore -VMHost (Get-VMHost $dstHost) | Where-Object {$_.Name -like "*datastore*"}
if (-not $shardDatastore) {
    LogPrint "ERROR: Unable to Get required shard datastore $shardDatastore"
    DisconnectWithVIServer
    return $Aborted
}


$name = $shardDatastore.Name
LogPrint "INFO: required shard datastore $name"


# Move Hard Disk to another datastore to prepare next migrate
$task = Move-VM -VMotionPriority High -VM $vmObj -Datastore $shardDatastore -Confirm:$false -RunAsync:$true -Destination (Get-VMHost $dsthost) -ErrorAction SilentlyContinue


# Start another VM
$GuestBName = $vmObj.Name.Split('-')
# Get another VM by change Name
$GuestBName[-1] = "B"
$GuestBName = $GuestBName -join "-"
$GuestB = Get-VMHost -Name $hvServer | Get-VM -Name $GuestBName


# Add RDMA NIC for Guest B
$status = AddPVrdmaNIC $GuestBName $hvServer
if ( -not $status[-1]) {
    LogPrint "ERROR: RDMA NIC adds failed" 
    DisconnectWithVIServer
    return $Aborted
}


# Start GuestB
Start-VM -VM $GuestB -Confirm:$false -RunAsync:$true -ErrorAction SilentlyContinue
if (-not $?) {
    LogPrint "ERROR : Cannot start VM"
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


# Get another VM IP addr
$ipv4Addr_B = GetIPv4 -vmName $GuestBName -hvServer $hvServer
$GuestB = Get-VMHost -Name $hvServer | Get-VM -Name $GuestBName


# Find out new add RDMA nic for Guest B
$nics += @($(FindAllNewAddNIC $ipv4Addr_B $sshKey))
if ($null -eq $nics) {
    LogPrint "ERROR: Cannot find new add RDMA NIC" 
    DisconnectWithVIServer
    return $Failed
}
else {
    $rdmaNIC = $nics[-1]
}
LogPrint "INFO: New NIC is $rdmaNIC"


# Config RDMA NIC IP addr for Guest B
$IPAddr_guest_B = "172.31.1." + (Get-Random -Maximum 254 -Minimum 125)
if ( -not (ConfigIPforNewDevice $ipv4Addr_B $sshKey $rdmaNIC ($IPAddr_guest_B + "/24"))) {
    LogPrint "ERROR : Guest B Config IP Failed"
    DisconnectWithVIServer
    return $Failed
}
LogPrint "INFO: Guest B RDMA NIC IP add is $IPAddr_guest_B"


# Check Migration status
Start-Sleep -Seconds 6
$status = Wait-Task -Task $task
LogPrint "INFO: Migration result is $status"
if (-not $status) {
    LogPrint "ERROR : Cannot move disk to required Datastore ${shardDatastore.Name}"
    DisconnectWithVIServer
    return $Aborted
}


# Find out new add RDMA nic for Guest A
$nics += @($(FindAllNewAddNIC $ipv4 $sshKey))
if ($null -eq $nics) {
    LogPrint "ERROR: Cannot find new add rdma NIC" 
    DisconnectWithVIServer
    return $Failed
}
else {
    $rdmaNIC = $nics[-1]
}
LogPrint "INFO: New NIC is $rdmaNIC"


# Config RDMA NIC IP addr for Guest A
$IPAddr_guest_A = "172.31.1." + (Get-Random -Maximum 124 -Minimum 2)
if ( -not (ConfigIPforNewDevice $ipv4 $sshKey $rdmaNIC ($IPAddr_guest_A + "/24"))) {
    LogPrint "ERROR : Guest A Config IP Failed"
    DisconnectWithVIServer
    return $Failed
}
LogPrint "INFO: Guest A RDMA NIC IP add is $IPAddr_guest_A"


# Check can we ping GuestA from GuestB via RDMA NIC
$Command = "ping $IPAddr_guest_A -c 10 -W 15  | grep ttl > /dev/null"
$status = SendCommandToVM $ipv4Addr_B $sshkey $command
if (-not $status) {
    LogPrint "ERROR : Ping test Failed"
    $retVal = $Failed
}
else {
    $retVal = $Passed
}


# Clean up phase: Move back to old host


# Refresh vmobj
$vmObj = Get-VMHost -Name $dsthost | Get-VM -Name $vmName
if (-not $vmObj) {
    LogPrint "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
    return $Aborted
}


# Move guest to old host
$task = Move-VM -VMotionPriority High -VM $vmObj -Destination (Get-VMHost $hvServer) -Datastore $oldDatastore -Confirm:$false
if (-not $?) {
    LogPrint "ERROR : Cannot move VM to required Host $hvServer and Datastore $oldDatastore"
    DisconnectWithVIServer
    return $Aborted
}


# Wait 6 seconds
Start-Sleep -Seconds 6


# Refresh vmobj
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj) {
    LogPrint "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
    return $Aborted
}


DisconnectWithVIServer
return $retVal
