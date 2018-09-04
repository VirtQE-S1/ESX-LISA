###############################################################################
##
## Description:
##  Migration to a Host with SR-IOV supported should be supported
##
## Revision:
##  v1.0.0 - ruqin - 09/04/2018 - Build the script
##
###############################################################################


<#
.Synopsis
    Migration to a Host with SR-IOV supported should be supported 

.Description
       <test>
            <testName>sriov_move_host_supported</testName>
            <testID>ESX-SRIOV-003</testID>
            <setupScript>
                <file>setupscripts\add_sriov.ps1</file>
            </setupScript>
            <testScript>testscripts\sriov_move_host_supported.ps1</testScript>
            <testParams>
                <param>dstHost6.7=10.73.196.95,10.73.196.97</param>
                <param>dstHost6.5=10.73.199.191,10.73.196.230</param>
                <param>dstDatastore=datastore</param>
                <param>TC_COVERED=RHEL-111209,RHEL6-49156</param>
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
$dstHost = FindDstHost -vmName $vmName -hvServer $hvServer -Host6_5 $dstHost6_5 -Host6_7 $dstHost6_7
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
$shardDatastore = Get-Datastore -VMHost (Get-VMHost $dsthost) | Where-Object {$_.Name -like "*$dstDatastore*"}
if (-not $shardDatastore) {
    LogPrint "ERROR: Unable to Get required shard datastore $shardDatastore"
    DisconnectWithVIServer
    return $Aborted
}


$name = $shardDatastore.Name
LogPrint "INFO: required shard datastore $name"


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


# Move storage and resource
$status = Move-VM -VMotionPriority High -VM $vmObj -Destination $(Get-VMHost $dsthost) -Datastore $shardDatastore -Confirm:$false -ErrorAction SilentlyContinue
if (-not $?) {
    LogPrint  "ERROR : Cannot move VM to required Host $dsthost"
    DisconnectWithVIServer
    return $Aborted
}


# Refresh status
$vmObj = Get-VMHost -Name $dstHost | Get-VM -Name $vmName
if (-not $vmObj) {
    LogPrint "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
    return $Aborted
}


# Start Guest
Start-VM -VM $vmObj -Confirm:$false -RunAsync:$true -ErrorAction SilentlyContinue
if (-not $?) {
    # Move VM back
    Move-VM -VMotionPriority High -VM $vmObj -Destination $(Get-VMHost $hvServer) -Datastore $oldDatastore -Confirm:$false -ErrorAction SilentlyContinue
    LogPrint "ERROR : Cannot start VM"
    DisconnectWithVIServer
    return $Aborted
}


# Wait for SSH ready
if ( -not (WaitForVMSSHReady $vmName $dstHost $sshKey 300)) {
    # Move VM back
    Move-VM -VMotionPriority High -VM $vmObj -Destination $(Get-VMHost $hvServer) -Datastore $oldDatastore -Confirm:$false -ErrorAction SilentlyContinue
    LogPrint "ERROR : Cannot start SSH"
    DisconnectWithVIServer
    return $Aborted
}
LogPrint "INFO: Ready SSH"


# Get another VM IP addr and refresh
$ipv4 = GetIPv4 -vmName $vmName -hvServer $dstHost
$vmObj = Get-VMHost -Name $dstHost | Get-VM -Name $vmName
if (-not $vmObj) {
   LogPrint "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
    return $Aborted
}


# Find out new add RDMA nic for Guest A
$nics += @($(FindAllNewAddNIC $ipv4 $sshKey))
if ($null -eq $nics) {
    # Move VM back
    Move-VM -VMotionPriority High -VM $vmObj -Destination $(Get-VMHost $hvServer) -Datastore $oldDatastore -Confirm:$false -ErrorAction SilentlyContinue
    LogPrint "ERROR: Cannot find new add SR-IOV NIC" 
    DisconnectWithVIServer
    return $Failed
}
else {
    $sriovNIC = $nics[-1]
}
LogPrint "INFO: New NIC is $sriovNIC"


# Get sriov nic driver 
$Command = "ethtool -i $sriovNIC | grep driver | awk '{print `$2}'"
$driver = Write-Output y | bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command
# mellanox 40G driver and intel 40G NIC maybe different
if ($driver -ne "ixgbevf") {
    LogPrint "ERROR : Sriov driver error or unsupported driver"
    DisconnectWithVIServer
    return $Aborted 
}
else {
    $retVal = $Passed
}


# Refresh status
$vmObj = Get-VMHost -Name $dstHost | Get-VM -Name $vmName
if (-not $vmObj) {
    LogPrint "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
    return $Aborted
}


# Move VM back
Move-VM -VMotionPriority High -VM $vmObj -Destination $(Get-VMHost $hvServer) -Datastore $oldDatastore -Confirm:$false -ErrorAction SilentlyContinue
LogPrint "INFO: Move VM back"


DisconnectWithVIServer
return $retVal
