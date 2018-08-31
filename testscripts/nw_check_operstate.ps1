###############################################################################
##
## Description:
##  Check NIC operstate when ifup / ifdown
##
## Revision:
##  v1.0.0 - boyang - 08/31/2017 - Build the script
##  v1.0.1 - boyang - 05/10/2018 - Enhance the script in debug info
##
###############################################################################


<#
.Synopsis
    Check NIC operstate when ifup / ifdown

.Description
    Check NIC operstate when ifup / ifdown, operstate owns up / down states

     <test>
            <testName>nw_check_operstate</testName>
            <testID>ESX-NW-009</testID>
            <testScript>testscripts\nw_check_operstate.ps1</testScript>
            <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
            <timeout>360</timeout>
            <testParams>
                <param>TC_COVERED=RHEL6-34937,RHEL7-50917</param>
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


###############################################################################
#
# Main Body
#
###############################################################################


$retVal = $Failed
$new_network_name = "VM Network"
# Confirm VM
$vmOut = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmOut) {
    LogPrint "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
    return $Aborted
}


# Hot plug a new NIC
LogPrint "INFO: Is adding a new NIC"
$new_nic_obj_x = New-NetworkAdapter -VM $vmOut -NetworkName $new_network_name -WakeOnLan -StartConnected -Confirm:$false
LogPrint "DEBUG: new_nic_obj_x: $new_nic_obj_x"


# Confirm NIC count
$all_nic_count = (Get-NetworkAdapter -VM $vmOut).Count
LogPrint "DEBUG: all_nic_count: $all_nic_count"
if ($all_nic_count -ne 2) {
    LogPrint "ERROR: Hot plug vmxnet3 failed"
    DisconnectWithVIServer
    return $Aborted
}
LogPrint "INFO: Complete the hot plug of vmxnet3"


# Find new add vmxnet3 nic
$nics = FindAllNewAddNIC $ipv4 $sshKey
if ($null -eq $nics) {
    LogPrint "ERROR: Cannot find new add NIC" 
    DisconnectWithVIServer
    return $Failed
}
else {
    $vmxnetNic = $nics[-1]
}
LogPrint "INFO: New NIC is $vmxnetNic"


# Config new NIC
if ( -not (ConfigIPforNewDevice $ipv4 $sshKey $vmxnetNic)) {
    LogPrint "ERROR : Config IP Failed"
    DisconnectWithVIServer
    return $Failed
}
else {
    $retVal = $Passed
}
LogPrint "INFO: vmxnet3 NIC IP setup successfully"


for ($i = 0; $i -lt 10; $i++) {
    # Get current operstate
    $Command = "cat /sys/class/net/$vmxnetNic/operstate"
    $operstate = Write-Output y | bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command
    if ($operstate -ne "up") {
        LogPrint "ERROR: NIC operstate is not correct on up" 
        DisconnectWithVIServer
        return $Failed
    }
    Start-Sleep -Seconds 1


    # Set to down
    SendCommandToVM $ipv4 $sshKey "ifconfig $vmxnetNic down"
    LogPrint "INFO: Set operstate down"
    Start-Sleep -Seconds 1


    # Get current operstate
    $Command = "cat /sys/class/net/$vmxnetNic/operstate"
    $operstate = Write-Output y | bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command
    if ($operstate -ne "down") {
        LogPrint "ERROR: NIC operstate is not correct on down" 
        DisconnectWithVIServer
        return $Failed
    }
    Start-Sleep -Seconds 1


    # Set to up
    SendCommandToVM $ipv4 $sshKey "ifconfig $vmxnetNic up"
    LogPrint "INFO: Set operstate up"
    Start-Sleep -Seconds 6
}


$retVal = $Passed
DisconnectWithVIServer
return $retVal
