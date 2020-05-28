########################################################################################
## Description:
##  Check NIC name after unload and load vmxnet3. Like the original nic named ens192,
##	after add two nics nes193, ens194, and remove ens193, after reload vmxnet3 driver,
##	ens194 name can't be changed to ens193 or others, should be kept nes194.
##
## Revision:
##  v1.0.0 - ruqin - 08/02/2018 - Build the script.
########################################################################################

<#
.Synopsis
    Check NIC name after unload and load vmxnet3
.Description
       <test>
            <testName>nw_check_nic_name</testName>
            <testID>ESX-NW-019</testID>
            <setupScript>
                <file>setupscripts\add_vmxnet3.ps1</file>
                <file>setupscripts\add_vmxnet3.ps1</file>
            </setupScript>
            <testScript>testscripts\nw_check_nic_name.ps1</testScript>
            <testParams>
                <param>TC_COVERED=RHEL-111702</param>
            </testParams>
            <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
            <timeout>240</timeout>
            <onERROR>Continue</onERROR>
            <noReboot>False</noReboot>
        </test>
.Parameter vmName
    Name of the test VM.
.Parameter testParams
    Semicolon separated list of test parameters.
#>


# Checking the input arguments
param([String] $vmName, [String] $hvServer, [String] $testParams)
if (-not $vmName) {
    "ERROR: VM name cannot be null!"
    exit 100
}

if (-not $hvServer) {
    "ERROR: hvServer cannot be null!"
    exit 100
}

if (-not $testParams) {
    Throw "ERROR: No test parameters specified."
}


# Output test parameters so they are captured in log file
"TestParams : '${testParams}'"


# Parse the test parameters.
$rootDir = $null
$sshKey = $null
$ipv4 = $null

$params = $testParams.Split(";")
foreach ($p in $params) {
    $fields = $p.Split("=")
    switch ($fields[0].Trim()) {
        "sshKey"    { $sshKey = $fields[1].Trim() }
        "rootDir"   { $rootDir = $fields[1].Trim() }
        "ipv4"      { $ipv4 = $fields[1].Trim() }
        default     {}
    }
}


# Check all parameters are valid
if (-not $rootDir) {
    "WARN : no rootdir was specified"
}
else {
    if ( (Test-Path -Path "${rootDir}") ) {
        Set-Location $rootDir
    }
    else {
        "WARN : rootdir '${rootDir}' does not exist"
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


function findNICByMAC ([String] $AdapterName, $vmObj, [String] $ipv4, [String] $sshKey) 
{
    $nics = Get-NetworkAdapter -VM $vmObj
    $Command = "cat /sys/class/net/$AdapterName/address"
    $MacAddr = bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command
    LogPrint "DEBUG: MacAddr: ${MacAddr}."

    if ($null -eq $MacAddr) {
        LogPrint "WARN: Cannot find required Mac address ${MacAddr}." 
        return $null
    }

    foreach ($nic in $nics) {
        if ($nic.MacAddress -eq $MacAddr) {
            LogPrint "INFO: NIC found is ${nic}."
            return $nic
        }
    }

    LogPrint "WARN: Cannot find required NIC."
    return $null
}


$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj) {
    LogPrint "ERROR: Unable to Get-VM with ${vmName}."
    DisconnectWithVIServer
    return $Aborted
}


# Get the Guest version.
$DISTRO = GetLinuxDistro ${ipv4} ${sshKey}
LogPrint "DEBUG: DISTRO: $DISTRO"
if (-not $DISTRO) {
    LogPrint "ERROR: Guest OS version is NULL."
    DisconnectWithVIServer
    return $Aborted
}


# Different Guest DISTRO.
if ($DISTRO -ne "RedHat7" -and $DISTRO -ne "RedHat8" -and $DISTRO -ne "RedHat6") {
    LogPrint "ERROR: Guest OS ($DISTRO) isn't supported, MUST UPDATE in Framework / XML / Script."
    DisconnectWithVIServer
    return $Skipped
}


# Get Old Adapter Name of VM.
$Command = "ip a | grep `$(echo `$SSH_CONNECTION| awk '{print `$3}')| awk '{print `$(NF)}'"
$Old_Adapter = Write-Output y | bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command
LogPrint "DEBUG: Old_Adapter: ${Old_Adapter}."
if ( $null -eq $Old_Adapter) {
    LogPrint "ERROR : Cannot get Server_Adapter from first adapter."
    DisconnectWithVIServer
    return $Aborted
}


# Get other two nics.
$Command = "ls /sys/class/net | grep e | grep -v $Old_Adapter | awk 'NR==1'"
$Second_Adapter = Write-Output y | bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command
LogPrint "DEBUG: Second_Adapter: ${Second_Adapter}."
if ( $null -eq $Second_Adapter) {
    LogPrint "ERROR : Cannot get Server_Adapter from Second adapter."
    DisconnectWithVIServer
    return $Aborted
}


$Command = "ls /sys/class/net | grep e | grep -v $Old_Adapter | awk 'NR==2'"
$Thrid_Adapter = Write-Output y | bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command
LogPrint "DEBUG: Thrid_Adapter: ${Thrid_Adapter}."
if ( $null -eq $Thrid_Adapter) {
    LogPrint "ERROR : Cannot get Server_Adapter from Thrid adapter."
    DisconnectWithVIServer
    return $Aborted
}


# Remove vmxnet3 NIC.
$Second_NIC = findNICByMAC -AdapterName $Second_Adapter -vmObj $vmObj -ipv4 $ipv4 -sshKey $sshKey
LogPrint "DEBUG: Second_NIC: ${Second_NIC}."


# Because new patch is not online so have to poweroff.
$status = Stop-VM $vmObj -Confirm:$False


# Enough time to stop the VM.
Start-Sleep -Seconds 30


$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj) {
    LogPrint "ERROR: Unable to Get-VM with ${vmName}."
    DisconnectWithVIServer
    return $Aborted
}


# Must be [-1] due to powershell return value
Remove-NetworkAdapter -NetworkAdapter $Second_NIC[-1] -Confirm:$false
if (-not $?) {
    LogPrint "ERROR: Cannot remove seoncd NIC."
    DisconnectWithVIServer
    return $Aborted
}


$status = Start-VM -VM $vmObj -Confirm:$false -RunAsync:$true -ERRORAction SilentlyContinue
if (-not $?) {
    LogPrint "ERROR: Cannot start VM."
    DisconnectWithVIServer
    return $Aborted
}


# Get VM IP addr.
if ( -not (WaitForVMSSHReady $vmName $hvServer $sshKey 300)) {
    LogPrint "ERROR : Cannot start SSH."
    DisconnectWithVIServer
    return $Aborted
}
LogPrint "INFO: Ready SSH."


# Refresh vmobj.
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj) {
    LogPrint "ERROR: Unable to Get-VM with ${vmName}."
    DisconnectWithVIServer
    return $Aborted
}


# Load and Unload vmxnet3.
$Command = "modprobe -r vmxnet3 && modprobe vmxnet3 && systemctl restart NetworkManager"
if ($DISTRO -eq "RedHat6") {
    $Command = "modprobe -r vmxnet3 && modprobe vmxnet3 && service network restart."
}

$status = SendCommandToVM $ipv4 $sshKey $Command
LogPrint "DEBUG: status: ${status}."
if (-not $status) {
    LogPrint "ERROR : Cannot reload vmxnet3."
    DisconnectWithVIServer
    return $Aborted
}


# Wait for reload
Start-Sleep -Seconds 6


# Get New Adapter Name Again
$Command = "ls /sys/class/net | grep e | grep -v $Old_Adapter"
$Reload_Adapter = bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command
LogPrint "DEBUG: Reload_Adapter: ${Reload_Adapter}."
if ( $null -eq $Reload_Adapter) {
    LogPrint "ERROR: Cannot get Server_Adapter From third Adapter."
    DisconnectWithVIServer
    return $Aborted
}


# Check NIC name
if ($Reload_Adapter -ne $Thrid_Adapter) {
    LogPrint "ERROR: NIC name changed after reload vmxnet3."
    DisconnectWithVIServer
    return $Failed
}
else {
    $retVal = $Passed
}


DisconnectWithVIServer
return $retVal
