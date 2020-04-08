########################################################################################
## Description:
##  Change the MTU of a vmxnet3.
##
## Revision:
##  v1.0.0 - ruqin - 8/23/2018 - Build the script.
########################################################################################


<#
.Synopsis
    Change the MTU of a vmxnet3
.Description
       <test>
            <testName>nw_arbitrary_mtu</testName>
            <testID>ESX-NW-020</testID>
            <setupScript>
                <file>SetupScripts\revert_guest_B.ps1</file>
            </setupScript>
            <cleanupScript>
                <file>SetupScripts\shutdown_guest_B.ps1</file>
            </cleanupScript>
            <testScript>testscripts\nw_arbitrary_mtu.ps1</testScript>
            <testParams>
                <param>TC_COVERED=RHEL7-50930,RHEL6-34949</param>
                <param>mtu=9000</param>
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


# Checking the input arguments.
param([String] $vmName, [String] $hvServer, [String] $testParams)
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


########################################################################################
# Main Body
########################################################################################
$retVal = $Failed

function setMTU {
    param (
        [String] $ipv4, 
        [String] $sshkey,
        [String] $con,
        [int] $Set_MTu
    )

    $DISTRO = GetLinuxDistro ${ipv4} ${sshKey}
    # Start NetworkManager
    if ($DISTRO -eq "RedHat6") {
        SendCommandToVM $ipv4 $sshKey "service network restart"
        # Set New MTU
        SendCommandToVM $ipv4 $sshKey "ifconfig $con mtu $Set_MTU"
        # Restart NetworkManager
        SendCommandToVM $ipv4 $sshKey "service network restart"
        # Get New MTU
        $Command = "ifconfig $con | grep -i mtu | awk '{print `$(NF-1)}' | awk 'BEGIN{FS=\`":\`"}{print `$2}'"
        $MTU = bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command
    }
    else {
        SendCommandToVM $ipv4 $sshKey "systemctl restart NetworkManager"
        # Set New MTU
        SendCommandToVM $ipv4 $sshKey "nmcli connection modify `$(nmcli connection show | grep $con | awk '{print `$(NF-2)}') mtu $Set_MTU"
        # Restart NetworkManager
        SendCommandToVM $ipv4 $sshKey "systemctl restart NetworkManager"
        # Get New MTU
        $Command = "nmcli connection show `$(nmcli connection show | grep $con | awk '{print `$(NF-2)}') | grep -w mtu | awk '{print `$2}'"
        $MTU = bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command
    }
    
    if ($MTU -ne $Set_MTU) {
        LogPrint "ERROR: Unable to Set MTU to $Set_MTU, Current MTU is $MTU"
        return $false
    }
    else {
        LogPrint "INFO: Success Set MTU to $Set_MTU"
        return $true
    }
    
}


# Get VM object
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
$GuestB = Get-VMHost -Name $hvServer | Get-VM -Name $GuestBName
if (-not $GuestB) {
    LogPrint "ERROR: Unable to Get GuestB: $GuestBName"
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


# Get NIC guest A
$Command = "ip a|grep `$(echo `$SSH_CONNECTION| awk '{print `$3}')| awk '{print `$(NF)}'"
$vmxnet_A = bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command
LogPrint "DEBUG: vmxnet_A: ${vmxnet_A}."


# Setup new MTU
$setA = setMTU $ipv4 $sshKey $vmxnet_A $mtu
LogPrint "DEBUG: setA: ${setA}."
if (-not $setA[-1]) {
    LogPrint "ERROR: Setup new MTU failed in VM-A."
    DisconnectWithVIServer
    return $Aborted
}


# Install tcpdump at GuestA
$install = SendCommandToVM $ipv4 $sshKey "yum install tcpdump -y"
if (-not $install[-1]) {
    LogPrint "Error: Cannot install tcpdump."
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
LogPrint "DEBUG: ipv4Addr_B: ${ipv4Addr_B}."


# Get NIC guest B
$Command = "ip a|grep `$(echo `$SSH_CONNECTION| awk '{print `$3}')| awk '{print `$(NF)}'"
$vmxnet_B = bin\plink.exe -i ssh\${sshKey} root@${ipv4Addr_B} $Command
LogPrint "DEBUG: vmxnet_B: ${vmxnet_B}."


# Setup new MTU
$setB = setMTU $ipv4Addr_B $sshKey $vmxnet_B $mtu
LogPrint "DEBUG: setB: ${setB}."
if (-not $setB[-1]) {
    LogPrint "ERROR: Setup new MTU failed in VM-B."
    DisconnectWithVIServer
    return $Aborted
}


$packetSize = $mtu - 28
# Ping Guest A from Guest B
$Command = "ping -s $packetSize -M do -c 50 -W 1 -I $vmxnet_B $ipv4"
$proc = Start-Process .\bin\plink.exe -ArgumentList "-i ssh\${sshKey} root@${ipv4Addr_B} ${Command}" -PassThru -WindowStyle Hidden


# Use tcpdump to check the packet is not fragmented
LogPrint "INFO: Start tcpdump to receive Ping."
$Command = "timeout 100 tcpdump -n -v -i $vmxnet_A -l -c 20 icmp and src $ipv4Addr_B | grep 'offset 0'| grep 'length $mtu' | wc -l"
$packetsCount = [int] (bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command)
if ($packetsCount -ne 20) {
    LogPrint "ERROR: packet is fragmented or tcpdump is timeout. Found packetsCount is $packetsCount, Command is $Command"
    DisconnectWithVIServer
    return $Failed
}


# Check Ping results.
$handle = $proc.Handle
$proc.WaitForExit()
LogPrint "INFO: Handle is $handle, Exit Code is $($proc.ExitCode)"
if ($proc.ExitCode -ne 0) {
    LogPrint "ERROR: Exit Code is not 0." 
    DisconnectWithVIServer
    return $Failed 
}
else {
    $retVal = $Passed
}


DisconnectWithVIServer
return $retVal
