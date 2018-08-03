###############################################################################
##
## Description:
##  Check the NIC large-receive-offload(LRO) status via ethtool
##
## Revision:
##  v1.0.0 - ruqin - 7/26/2018 - Build the script
##
###############################################################################

<#
.Synopsis
    Check the NIC large-receive-offload(LRO) status via ethtool(BZ918203)

.Description
       <test>
            <testName>nw_check_lro_status_ethtool</testName>
            <testID>ESX-NW-018</testID>
            <setupScript>
                <file>SetupScripts\change_cpu.ps1</file>
                <file>SetupScripts\revert_guest_B.ps1</file>
            </setupScript>
            <testScript>testscripts\nw_check_lro_status_ethtool.ps1</testScript>
            <testParams>
                <param>VCPU=1</param>
                <param>TC_COVERED=RHEL7-50919</param>
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

$params = $testParams.Split(";")
foreach ($p in $params) {
    $fields = $p.Split("=")
    switch ($fields[0].Trim()) {
        "sshKey" { $sshKey = $fields[1].Trim() }
        "rootDir" { $rootDir = $fields[1].Trim() }
        "ipv4" { $ipv4 = $fields[1].Trim() }
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
    LogPrint "ERROR: Unable to Get-VM with $vmName"
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


# Start another VM
$testVMName = $vmObj.Name.Split('-')
# Get another VM by change Name
$testVMName[-1] = "B"
$testVMName = $testVMName -join "-"
$testVM = Get-VMHost -Name $hvServer | Get-VM -Name $testVMName

# Start Guest-B
Start-VM -VM $testVM -Confirm:$false -RunAsync:$true -ErrorAction SilentlyContinue
if (-not $?) {
    LogPrint "ERROR : Cannot start VM"
    DisconnectWithVIServer
    return $Aborted
}

# Install Iperf3
if ($DISTRO -eq "RedHat6") {
    $command = "yum localinstall http://download.eng.bos.redhat.com/brewroot/vol/rhel-6/packages/iperf3/3.3/2.el6eng/x86_64/iperf3-3.3-2.el6eng.x86_64.rpm -y"
    $status = SendCommandToVM $ipv4 $sshkey $command
}
else {
    $command = "yum install iperf3 -y"
    $status = SendCommandToVM $ipv4 $sshkey $command
}

if ( -not $status) {
    LogPrint "Error : YUM failed in $vmName, may need to update iperf3 tool URL"
    DisconnectWithVIServer
    return $Aborted
}


# Get Adapter Name of VM
$Command = "ip a|grep `$(echo `$SSH_CONNECTION| awk '{print `$3}')| awk '{print `$(NF)}'"
$Server_Adapter = bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command

if ( $null -eq $Server_Adapter) {
    LogPrint "ERROR : Cannot get Server_Adapter"
    DisconnectWithVIServer
    return $Aborted
}


# Ready iperf3 server in Guest-A
$Command = "iperf3 -s"
$Status = Start-Process .\bin\plink.exe -ArgumentList "-i ssh\${sshKey} root@${ipv4} ${Command}" -PassThru -WindowStyle Hidden
LogPrint "INFO: iperf3 is enable"


# Get another VM IP addr
if ( -not (WaitForVMSSHReady $testVMName $hvServer $sshKey 300)) {
    LogPrint "ERROR : Guest-B cannot start SSH"
    DisconnectWithVIServer
    return $Aborted
}

LogPrint "INFO: Guest-B Ready SSH"
$ipv4Addr_B = GetIPv4 -vmName $testVMName -hvServer $hvServer
$testVM = Get-VMHost -Name $hvServer | Get-VM -Name $testVMName


# Install Iperf3 in Guest-B
if ($DISTRO -eq "RedHat6") {
    $command = "yum localinstall http://download.eng.bos.redhat.com/brewroot/vol/rhel-6/packages/iperf3/3.3/2.el6eng/x86_64/iperf3-3.3-2.el6eng.x86_64.rpm -y"
    $status = SendCommandToVM $ipv4Addr_B $sshkey $command
}
else {
    $command = "yum install iperf3 -y"
    $status = SendCommandToVM $ipv4Addr_B $sshkey $command
}

if ( -not $status) {
    LogPrint "Error : YUM failed in $testVMName, may need to update iperf3 tool URL"
    DisconnectWithVIServer
    return $Aborted
}


# Test Network Connection
$Command = "ping $ipv4 -c 5"
$status = SendCommandToVM $ipv4Addr_B $sshkey $command
if ( -not $status) {
    LogPrint "Error : Cannot ping Guest-A from Guest-B"
    DisconnectWithVIServer
    return $Aborted
}
LogPrint "INFO: Network is working"



# Start iperf3 test
$Command = "iperf3  -c $ipv4 -t 100 -4 > /root/output"
$Process = Start-Process .\bin\plink.exe -ArgumentList "-i ssh\${sshKey} root@${ipv4Addr_B} ${Command}" -PassThru -WindowStyle Hidden
if ( -not $status) {
    LogPrint "Error : iperf3 failed in $testVMName"
    Stop-VM $testVM -Confirm:$False -RunAsync:$true
    DisconnectWithVIServer
    return $Aborted
}
LogPrint "INFO: iperf3 is Start"


# Get Current LRO rx pkts count
$Command = "ethtool -S $Server_Adapter |grep LRO | grep -i pkts | awk '{print `$(NF)}'"
$LRO_count = bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command
LogPrint "INFO : Before test LRO pkts rx should not be null: $LRO_count"
if ($null -eq $LRO_count ) {
    LogPrint "ERROR : Current LRO pkts rx should not be null: $LRO_count"
    Stop-VM $testVM -Confirm:$False -RunAsync:$true
    DisconnectWithVIServer
    return $Aborted
}


# Enable LRO
$Command = "ethtool -K $Server_Adapter lro on"
$LRO_status = bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command

$Command = "ethtool -k $Server_Adapter |grep large"
$LRO_status = bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command

if ($LRO_status -ne "large-receive-offload: on") {
    LogPrint "ERROR : LRO should be enable: $LRO_status"
    Stop-VM $testVM -Confirm:$False -RunAsync:$true
    DisconnectWithVIServer
    return $Aborted
}
LogPrint "INFO: LRO is enable"


# Wait for 12 seconds
Start-Sleep -Seconds 12


# Disable LRO
$Command = "ethtool -K $Server_Adapter lro off"
$LRO_status = bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command

$Command = "ethtool -k $Server_Adapter |grep large"
$LRO_status = bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command

if ($LRO_status -ne "large-receive-offload: off") {
    LogPrint "ERROR : LRO should be disable: $LRO_status"
    Stop-VM $testVM -Confirm:$False -RunAsync:$true
    DisconnectWithVIServer
    return $Aborted
}
LogPrint "INFO: LRO is disable"


# Get Current LRO rx pkts count
$Command = "ethtool -S $Server_Adapter |grep LRO | grep -i pkts | awk '{print `$(NF)}'"
$Before_LRO_status = [int](bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command)
LogPrint "INFO: During iperf3 test with LRO enable, LRO pkts rx is $Before_LRO_status"

# Check LRO rx pkts increasing
if (($Before_LRO_status - $LRO_count) -lt 500) {
    LogPrint "ERROR: During iperf3 test with LRO enable, LRO pkts rx is not increasing: Before:$LRO_count After:$Before_LRO_status"
    Stop-VM $testVM -Confirm:$False -RunAsync:$true
    DisconnectWithVIServer
    return $Failed
}


# Wait for 12 seconds
Start-Sleep -Seconds 12


# Get Current LRO rx pkts count
$Command = "ethtool -S $Server_Adapter |grep LRO | grep -i pkts | awk '{print `$(NF)}'"
$After_LRO_status = bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command
LogPrint "INFO: After iperf3 test with LRO disable, LRO pkts rx is $After_LRO_status"

if (($After_LRO_status - $Before_LRO_status) -gt 200) {
    LogPrint "ERROR: LRO pkts rx is increasing without LRO enable Before:$Before_LRO_status After:$After_LRO_status"
    Stop-VM $testVM -Confirm:$False -RunAsync:$true
    DisconnectWithVIServer
    return $Failed
}
else {
    $retVal = $Passed
}


# Clean up step
# Shutdown Guest-B
Stop-VM $testVM -Confirm:$False -RunAsync:$true

if (-not $?) {
    Write-Host -F Red "ERROR : Cannot stop VM $testVMName"
    Write-Output "ERROR : Cannot stop VM $testVMName"
    DisconnectWithVIServer
    return $Aborted
}


DisconnectWithVIServer
return $retVal
