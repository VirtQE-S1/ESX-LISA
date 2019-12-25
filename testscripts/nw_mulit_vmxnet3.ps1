########################################################################################
## Description:
## 	Add one more vmxnet3 network adapter.
##
## Revision:
## 	v1.0.0 - boyang - 08/29/2017 - Build script.
## 	v1.1.0 - ruqin  - 08/28/2018 - Use NetworkManager instead of network.
########################################################################################


<#
.Synopsis
    Add one more vmxnet3 network adapter
.Description
    <test>
            <testName>nw_mulit_vmxnet3</testName>
            <testID>ESX-NW-008</testID>
            <testScript>testscripts\nw_mulit_vmxnet3.ps1</testScript>
            <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
            <timeout>360</timeout>
            <testParams>
                <param>TC_COVERED=RHEL6-38520,RHEL7-80532</param>
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
if (-not $vmName) {
    "FAIL: VM name cannot be null!"
    exit 1
}

if (-not $hvServer) {
    "FAIL: hvServer cannot be null!"
    exit 1
}

if (-not $testParams) {
    Throw "FAIL: No test parameters specified"
}


# Output test parameters so they are captured in log file
"TestParams : '${testParams}'"


# Parse test parameters
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

if ($null -eq $logdir) {
    "FAIL: Test parameter logdir was not specified"
    return $False
}


# Source tcutils.ps1
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


$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj) {
    LogPrint "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
    return $Aborted
}


# Hot plug two new NICs.
$networkName = "VM Network"
$total_nics = 5
$count = 1
while ($count -le $total_nics) {
    $newNIC = New-NetworkAdapter -VM $vmObj -NetworkName $networkName -WakeOnLan -StartConnected -Confirm:$false
    LogPrint "INFO: New Add NIC $newNIC."
    $count++
}


# Check hot plug NIC.
$all_nic_count = (Get-NetworkAdapter -VM $vmObj).Count
LogPrint "INFO: All NICs count: $all_nic_count."
if ($all_nic_count -eq ($total_nics + 1)) {
    LogPrint "INFO: Hot plug vmxnet3 successfully."
}
else {
    LogPrint "ERROR: Unknow issue after hot plug adapter, check it manually."
    return $Aborted
}


# Find new add vmxnet3 nic
$nics += @($(FindAllNewAddNIC $ipv4 $sshKey))
LogPrint "DEBUG: nics: $nics"
if ($null -eq $nics) {
    LogPrint "ERROR: Cannot find new add NIC." 
    DisconnectWithVIServer
    return $Failed
}
LogPrint "INFO: New NIC count is $($nics.Length)."


# Config new NIC
foreach ($nic in $nics) {
    $status = ConfigIPforNewDevice $ipv4 $sshKey $nic
    if ( $null -eq $status -or -not $status[-1]) {
        LogPrint "ERROR : Config IP Failed for $nic"
        DisconnectWithVIServer
        return $Failed
    }
    else {
        $retVal = $Passed
    }
    LogPrint "INFO: vmxnet3 NIC $nic, IP setup successfully" 
}


DisconnectWithVIServer
return $retVal
