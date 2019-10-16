########################################################################################
##
## Description:
##  Hot plug the e1000 network adapter.
##
## Revision:
##  v1.0.0 - boyang - 02/11/2017 - Build script.
##  v1.1.0 - ruqin - 08/13/2018 - Change e1000 to e1000e, add driver check.
########################################################################################

<#
.Synopsis
    Hot plug the e1000 network adapter

.Description
    When the VM alives, Hot plug a e1000, no crash found
    <test>
        <testName>nw_hot_plug_e1000</testName>
        <testID>ESX-NW-012</testID>
        <testScript>testscripts\nw_hot_plug_e1000.ps1</testScript>
        <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
        <timeout>360</timeout>
        <testParams>
            <param>TC_COVERED=RHEL6-34954,RHEL7-50936</param>
        </testParams>
        <onError>Continue</onError>
        <noReboot>False</noReboot>
    </test>
.Parameter vmName
    Name of the test VM.

.Parameter hvServer
    Name of the VIServer hosting the VM.

.Parameter testParams
    Semicolon separated list of test parameters.
#>

param([String] $vmName, [String] $hvServer, [String] $testParams)

#
# Checking the input arguments
#
if (-not $vmName) {
    "FAIL: VM name cannot be null!"
    exit
}

if (-not $hvServer) {
    "FAIL: hvServer cannot be null!"
    exit
}

if (-not $testParams) {
    Throw "FAIL: No test parameters specified"
}

#
# Output test parameters so they are captured in log file
#
"TestParams : '${testParams}'"

#
# Parse test parameters
#
$rootDir = $null
$sshKey = $null
$ipv4 = $null
$logdir = $null

$params = $testParams.Split(";")
foreach ($p in $params) {
    $fields = $p.Split("=")
    switch ($fields[0].Trim()) {
        "rootDir" { $rootDir = $fields[1].Trim() }
        "sshKey" { $sshKey = $fields[1].Trim() }
        "ipv4" { $ipv4 = $fields[1].Trim() }
        "TestLogDir"	{ $logdir = $fields[1].Trim()}
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

if ($null -eq $logdir) {
    "FAIL: Test parameter logdir was not specified"
    return $False
}

#
# Source tcutils.ps1
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
# "VM Network" is default value in vSphere
$new_nic_name = "VM Network" 

#
# Confirm VM
#
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj) {
    Write-Error -Message "Unable to get-vm with $vmName" -Category ObjectNotFound -ErrorAction SilentlyContinue
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

#
# Hot plug one new adapter named $new_nic_name, the adapter count will be 2
#
if ($DISTRO -eq "RedHat6") {
    # RHEL 6 supports e1000
    $new_nic = New-NetworkAdapter -VM $vmObj -NetworkName $new_nic_name -Type e1000 -WakeOnLan -StartConnected -Confirm:$false
}
else {
    # RHEL 7\8 support e1000e
    $new_nic = New-NetworkAdapter -VM $vmObj -NetworkName $new_nic_name -Type e1000e -WakeOnLan -StartConnected -Confirm:$false
}
LogPrint "Get the new NIC: $new_nic"

$all_nic_count = (Get-NetworkAdapter -VM $vmObj).Count
if ($all_nic_count -ne 2) {
    Write-Host -F Red "FAIL: Unknow issue after hot plug e1000, check it manually"
    Write-Output "FAIL: Unknow issue after hot plug e1000, check it manually"
}

# Get Old Adapter Name of VM
$Command = "ip a|grep `$(echo `$SSH_CONNECTION| awk '{print `$3}')| awk '{print `$(NF)}'"
$Old_Adapter = Write-Output y | bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command
if ( $null -eq $Old_Adapter) {
    LogPrint "ERROR : Cannot get Server_Adapter from first adapter"
    DisconnectWithVIServer
    return $Aborted
}

# Get e1000e nic
$Command = "ls /sys/class/net | grep e | grep -v $Old_Adapter | awk 'NR==1'"
$sriovNIC = Write-Output y | bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command
if ( $null -eq $sriovNIC) {
    LogPrint "ERROR : Cannot get sriovNIC from guest"
    DisconnectWithVIServer
    return $Aborted
}

# Get e100e nic driver 
$Command = "ethtool -i $sriovNIC | grep driver | awk '{print `$2}'"
$driver = Write-Output y | bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command
# mellanox 40G driver and intel 40G NIC maybe different
if ($driver -ne "e1000e") {
    LogPrint "ERROR : Sriov driver Error or unsupported driver"
    DisconnectWithVIServer
    return $Aborted 
}
else {
    $retVal = $Passed
}

DisconnectWithVIServer
return $retVal
