###############################################################################
##
## Description:
##  Test live migrate for ESXi
##
## Revision:
##  v1.0.0 - ruqin - 7/12/2018 - Build the script
##
###############################################################################

<#
.Synopsis
    Move virtual machine disk to Dest shared NFS storage and then try live migration
    During Migration need to test network doesn't lose packets

.Description
        Dst host should be different with hvServer
         <test>
            <testName>nw_live_migration</testName> <testID>ESX-NW-017</testID>
            <setupScript>SetupScripts\revert_guest_B.ps1</setupScript>
            <testScript>testscripts\nw_live_migration.ps1</testScript>
            <cleanupScript>
                <file>SetupScripts\reset_migration.ps1</file>
            </cleanupScript>
            <testParams>
                <param>dstHost6.7=10.73.196.95,10.73.196.97</param>
                <param>dstHost6.5=10.73.199.191,10.73.196.230</param>
                <param>dstHost6.0=10.73.196.234,10.73.196.236</param>
                <param>dstDatastore=freenas</param>
                <param>TC_COVERED=RHEL7-50929</param>
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
$dstHost6_0 = $null
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
        "dstHost6.0" { $dstHost6_0 = $fields[1].Trim()}
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


if (-not $dstHost6_7 -or -not $dstHost6_5 -or -not $dstHost6_0) {
    "INFO: dstHost 6.7 is $dstHost6_7"
    "INFO: dstHost 6.5 is $dstHost6_5"
    "INFO: dstHost 6.0 is $dstHost6_0"
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
#
###############################################################################


$retVal = $Failed

$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj) {
    Write-Host -F Red "ERROR: Unable to Get-VM with $vmName"
    Write-Output "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
    return $Aborted
}

# Specify dst host
$dstHost = FindDstHost -hvServer $hvServer -Host6_0 $dstHost6_0 -Host6_5 $dstHost6_5 -Host6_7 $dstHost6_7
if ($null -eq $dstHost) {
    LogPrint "ERROR: Cannot find required Host"    
    DisconnectWithVIServer
    return $Aborted
}
LogPrint "INFO: Destination Host is $dstHost"


# Store Old datastore
$oldDatastore = Get-Datastore -Name "datastore-*" -VMHost $hvServer
if (-not $oldDatastore) {
    Write-Host -F Red "ERROR: Unable to Get required original datastore $oldDatastore"
    Write-Output "ERROR: Unable to Get required original datastore $oldDatastore"
    DisconnectWithVIServer
    return $Aborted
}


# Get Required Datastore
$shardDatastore = Get-Datastore -VMHost (Get-VMHost $hvServer) | Where-Object {$_.Name -like "*$dstDatastore*"}
if (-not $shardDatastore) {
    Write-Host -F Red "ERROR: Unable to Get required shard datastore $dstDatastore"
    Write-Output "ERROR: Unable to Get required shard datastore $dstDatastore"
    DisconnectWithVIServer
    return $Aborted
}

$name = $shardDatastore.Name

Write-Host -F Red "INFO: required shard datastore $name"
Write-Output "INFO: required shard datastore $name"

# Move Hard Disk to shared datastore to prepare next migrate
$task = Move-VM -VMotionPriority High -VM $vmObj -Datastore $shardDatastore -Confirm:$false -ErrorAction SilentlyContinue
if (-not $?) {
    Write-Host -F Red "ERROR : Cannot move disk to required Datastore $shardDatastore"
    Write-Output "ERROR : Cannot move disk to required Datastore $shardDatastore"
    DisconnectWithVIServer
    return $Failed
}
# Start another VM
$testVMName = $vmObj.Name.Split('-')
# Get another VM by change Name
$testVMName[-1] = "B"
$testVMName = $testVMName -join "-"
$testVM = Get-VMHost -Name $hvServer | Get-VM -Name $testVMName

Start-VM -VM $testVM -Confirm:$false -RunAsync:$true -ErrorAction SilentlyContinue
if (-not $?) {
    Write-Host -F Red "ERROR : Cannot start VM"
    Write-Output "ERROR : Cannot start VM"
    DisconnectWithVIServer
    return $Aborted
}

# Get another VM IP addr
if ( -not (WaitForVMSSHReady $testVMName $hvServer $sshKey 300)) {
    Write-Host -F Red "ERROR : Cannot start SSH"
    Write-Output "ERROR : Cannot start SSH"
    DisconnectWithVIServer
    return $Aborted
}

Write-Host -F Red "INFO: Ready SSH"
Write-Output "INFO: Ready SSH"

$ipv4Addr_B = GetIPv4 -vmName $testVMName -hvServer $hvServer
$testVM = Get-VMHost -Name $hvServer | Get-VM -Name $testVMName



$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj) {
    Write-Host -F Red "ERROR: Unable to Get-VM with $vmName"
    Write-Output "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
    return $Aborted
}


# Another VM Ping During Migration
$task = Move-VM -VMotionPriority High -VM $vmObj -Destination (Get-VMHost $dstHost) -Confirm:$false -RunAsync:$true

if (-not $?) {
    Write-Host -F Red "ERROR : Cannot move VM to required Host $dstHost"
    Write-Output "ERROR : Cannot move VM to required Host $dstHost"
    $vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
    # Move Hard Disk back to old datastore
    $task = Move-VM -VMotionPriority High -VM $vmObj -Datastore $oldDatastore -Confirm:$false
    DisconnectWithVIServer
    return $Aborted
}

$command = "ping $ipv4 -c 100  | grep -i 'packet loss' | awk '{print `$(NF-4)}'"
$packetLoss = Write-Output y | bin\plink.exe -i ssh\${sshKey} root@${ipv4Addr_B} $Command
Write-Host -F Red "Info: Packets Loss $packetLoss"
Write-Output "Info: Packets Loss $packetLoss"


Start-Sleep 1
# Check packet Loss value
if ($packetLoss -ne "0%" -and $packetLoss -ne "1%" ) {
    Write-Host -F Red "ERROR : Packet Loss During Migration"
    Write-Output "ERROR : Packet Loss During Migration"
    $vmObj = Get-VMHost -Name $dstHost | Get-VM -Name $vmName
    $task = Move-VM -VMotionPriority High -VM $vmObj -Destination (Get-VMHost $hvServer) -Confirm:$false
    $vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
    # Move Hard Disk back to old datastore
    $task = Move-VM -VMotionPriority High -VM $vmObj -Datastore $oldDatastore -Confirm:$false

    DisconnectWithVIServer
    return $Failed
}
else {
    $retVal = $Passed
}

# Wait for finish migrate if ping finshed first
# Wait-Task -Task $task -ErrorAction SilentlyContinue

$status = Wait-Task -Task $task
Write-Host -F Red $status

# Clean up step: Move back to old host

# Move host to old host
$task = Move-VM -VMotionPriority High -VM $vmObj -Destination (Get-VMHost $hvServer) -Confirm:$false -RunAsync:$true

if (-not $?) {
    Write-Host -F Red "ERROR : Cannot move VM to required Host $dstHost"
    Write-Output "ERROR : Cannot move VM to required Host $dstHost"
    DisconnectWithVIServer
    return $Failed
}

# Test ping during migration again
$command = "ping $ipv4 -c 100  | grep -i 'packet loss' | awk '{print `$(NF-4)}'"
$packetLoss = Write-Output y | bin\plink.exe -i ssh\${sshKey} root@${ipv4Addr_B} $Command
Write-Host -F Red "Info: Packets Loss $packetLoss"
Write-Output "Info: Packets Loss $packetLoss"

Start-Sleep 1

$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName

if (-not $vmObj) {
    Write-Host -F Red "ERROR: Unable to Get-VM with $vmName"
    Write-Output "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
    return $Failed
}

# Check packet Loss value
if ($packetLoss -ne "0%" -and $packetLoss -ne "1%" ) {
    Write-Host -F Red "ERROR : Packet Loss During Migration"
    Write-Output "ERROR : Packet Loss During Migration"
    DisconnectWithVIServer
    return $Failed
}
else {
    $retVal = $Passed
}

$status = Wait-Task -Task $task
Write-Host -F Red $status


# Move Hard Disk back to old datastore
$task = Move-VM -VMotionPriority High -VM $vmObj -Datastore $oldDatastore -Confirm:$false

if (-not $?) {
    Write-Host -F Red "ERROR : Cannot move disk to required Datastore $oldDatastore"
    Write-Output "ERROR : Cannot move disk to required Datastore $oldDatastore"
    DisconnectWithVIServer
    return $Failed
}

# Shutdown another VM
Stop-VM $testVM -Confirm:$False -RunAsync:$true
if (-not $?) {
    Write-Host -F Red "ERROR : Cannot stop VM $testVMName"
    Write-Output "ERROR : Cannot stop VM $testVMName"
    DisconnectWithVIServer
    return $Aborted
}

DisconnectWithVIServer
return $retVal
