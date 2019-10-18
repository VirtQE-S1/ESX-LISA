#######################################################################################
## Description:
##  Upload/load vmxnet3 module during flood ping
## Revision:
##  v1.0.0 - xinhu - 10/18/2019 - Build the script
#######################################################################################


<#
.Synopsis
    Upload/load vmxnet3 module during flood ping

.Description
<test>
        <testName>perf_unloadload_vmxnet3</testName>
        <testID>ESX-PERF-013</testID>
        <testScript>testscripts/perf_unloadload_vmxnet3.ps1</testScript>
        <files>remote-scripts/load_unload_vmxnet3.sh</files>
        <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
        <timeout>6000</timeout>
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


# Checking the input arguments
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
$HostIP = $null


$params = $testParams.Split(";")
foreach ($p in $params) {
    $fields = $p.Split("=")
    switch ($fields[0].Trim()) {
        "rootDir" { $rootDir = $fields[1].Trim() }
        "sshKey" { $sshKey = $fields[1].Trim() }
        "ipv4" { $ipv4 = $fields[1].Trim() }
        "TestLogDir"	{ $logdir = $fields[1].Trim()}
        "HostIP" {$HostIP = $fields[1].Trim()}
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


#######################################################################################
## Main Body
#######################################################################################
# Current version only install sshpass by rpm link
$retValdhcp = $Failed

$linuxOS = GetLinuxDistro $ipv4 $sshKey
$linuxOS = $linuxOS[-1]
$vmOut = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
$vmNameB = $vmName -replace "A","B"
Write-Host -F Red "INFO: RevertSnap $vmNameB..."
Write-Output "INFO: RevertSnap $vmNameB..."
$result = RevertSnapshotVM $vmNameB $hvServer
if ($result[-1] -ne $true)
{
    Write-Host -F Red "INFO: RevertSnap $vmNameB failed"
    Write-Output "INFO: RevertSnap $vmNameB failed"
    DisconnectWithVIServer
    return $Aborted
}
# Refresh status
$vmObjB = Get-VMHost -Name $hvServer | Get-VM -Name $vmNameB
Write-Host -F Red "INFO: Starting $vmNameB..."
Write-Output "INFO: Starting $vmNameB..."
# Start Guest
Start-VM -VM $vmObjB -Confirm:$false -RunAsync:$true -ErrorAction SilentlyContinue
Write-Host -F Red  "DEBUG: Finish start VM_B"
# Wait for VM_B start and gei ip address
$ret = WaitForVMSSHReady $vmNameB $hvServer ${sshKey} 300
if ( $ret -ne $true )
{
    Write-Output "Failed: Failed to start VM."
    write-host -F Red "Failed: Failed to start VM."
    DisconnectWithVIServer
    return $Aborted
}
# Refresh status
$vmObjB = Get-VMHost -Name $hvServer | Get-VM -Name $vmNameB
$IPB = GetIPv4ViaPowerCLI $vmNameB $hvServer
Write-Host -F Red "DEBUG: IP address of VM_B: ${IPB}"
Write-Output "DEBUG: IP address of VM_B: ${IPB}"

# Confirm the vmxnet3 nic and get nic name
$Command = 'lspci | grep -i Ethernet | grep -i vmxnet3' 
$IsNIC = bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command
Write-Host -F Red "DEBUG: Info of NIC: $IsNIC"
Write-Output "DEBUG: Info of NIC: $IsNIC"
if (!$IsNIC)
{
    Write-Host -F Red "ERROR: NIC is not vmxnets"
    Write-Output "ERROR: NIC is not vmxnets"
    DisconnectWithVIServer
    return $Aborted
}

# Ping -f VMB from VMA for one hour
$during = 3600
$result = bin\pscp.exe -i ssh\${sshKey} remote-scripts/ping.sh root@${IPB}:/root/
if (!$result)
{
    Write-Host -F Red "ERROR: SCP ping from ${ipv4} to ${IPB} Failed"
    Write-Output "ERROR: SCP ping from ${ipv4} to ${IPB} Failed"
    DisconnectWithVIServer
    return $Failed
}
Write-Host -F Red "DEBUG: Start to ping -f ${ipv4}"
Write-Output "DEBUG: Start to ping -f ${ipv4}"
$command = "ping ${ipv4}"
Start-Process ".\bin\plink.exe" "-i .\ssh\demo_id_rsa.ppk  root@${IPB} $command " -PassThru -WindowStyle Hidden
$PING = Start-Process ".\bin\plink.exe" "-i .\ssh\demo_id_rsa.ppk  root@${IPB} bash ping.sh $during" -PassThru -WindowStyle Hidden

# Load/Unload vmxnets
Write-Host -F Red "DEBUG: Start to load/unload vmxnet3 of ${ipv4}"
Write-Output "DEBUG: Start to load/unload vmxnet3 of ${ipv4}"
$Startload = "bash /root/load_unload_vmxnet3.sh $during"
$load= .\bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Startload
Write-Host -F Red "DEBUG: During one hour flood ping, load and unload vmxnet3, $load"

$IsNet = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ping ${IPB} -c 1;echo `$?"
Write-Host -F Red "DEBUG: During one hour flood ping, load and unload vmxnet3, result is $IsNet"
Write-Output "DEBUG: During one hour flood ping, load and unload vmxnet3, result is $IsNet"
if ($($IsNet[-1]) -ne 0)
{
    Write-Host -F Red "ERROR: During one hour flood ping, load and unload vmxnet3, result is $IsNet, failed"
    Write-Output "ERROR: During one hour flood ping, load and unload vmxnet3, result is $IsNet, failed"
    DisconnectWithVIServer
    return $retValdhcp
}
$retValdhcp = $Passed
$vmObjB = Get-VMHost -Name $hvServer | Get-VM -Name $vmNameB
Stop-VM -VM $vmObjB -Confirm:$false -RunAsync:$true -ErrorAction SilentlyContinue
DisconnectWithVIServer
return $retValdhcp