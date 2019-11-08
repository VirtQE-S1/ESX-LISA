#######################################################################################
## Description:
##  Upload/load vmxnet3 module during flood ping
## Revision:
##  v1.0.0 - xinhu - 10/18/2019 - Build the script
##  v1.0.1 - xinhu - 11/08/2019 - Update the parameters of script 
#######################################################################################


<#
.Synopsis
    Upload/load vmxnet3 module during flood ping

.Description
    <test>
        <testName>perf_nw_unloadload_vmxnet3</testName>
        <testID>ESX-PERF-013</testID>
        <testScript>testscripts/perf_nw_unloadload_vmxnet3.ps1</testScript>
        <files>remote-scripts/load_unload_vmxnet3.sh</files>
        <files>remote-scripts/ping.sh</files>
        <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
        <timeout>3600</timeout>
        <testParams>
            <param>TC_COVERED=RHEL7-50932</param>
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


#######################################################################################
## Main Body
#######################################################################################
$retValdhcp = $Failed

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


# Function dos2unix ping.sh and load_unload_vmxnet3.sh
$result = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "cd /root && sleep 1 && dos2unix ping.sh && chmod u+x ping.sh && sleep 1 && dos2unix load_unload_vmxnet3.sh && chmod u+x load_unload_vmxnet3.sh"

# SCP ping.sh from VMA to VMB
$result = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "scp -i `$HOME/.ssh/id_rsa_private -o StrictHostKeyChecking=no ping.sh root@${IPB}:/root/;echo `$? "
if (!$result)
{
    Write-Host -F Red "ERROR: SCP ping from ${ipv4} to ${IPB} Failed"
    Write-Output "ERROR: SCP ping from ${ipv4} to ${IPB} Failed"
    DisconnectWithVIServer
    return $Failed
}
Write-Host -F Red "DEBUG: Start to ping -f ${ipv4}"
Write-Output "DEBUG: Start to ping -f ${ipv4}"
$during = 3000
# Ping -f VMA from VMB for $during s.
$PING = Start-Process ".\bin\plink.exe" "-i .\ssh\demo_id_rsa.ppk root@${IPB} bash ping.sh $during ${ipv4}" -PassThru -WindowStyle Hidden

# Load/Unload vmxnets
$time=Get-date
Write-Host -F Red "DEBUG: Start to load/unload vmxnet3 of ${ipv4}, at ${time}"
Write-Output "DEBUG: Start to load/unload vmxnet3 of ${ipv4}, at ${time}"
$Startload = "bash /root/load_unload_vmxnet3.sh $during"
$load= .\bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Startload
$time=Get-date
Write-Host -F Red "DEBUG: During $during s flood ping, load and unload vmxnet3, $load, $time"
Write-Output "DEBUG: During $during s flood ping, load and unload vmxnet3, $load, $time"


# Check the NIC works whell after long time load/unload vmxnet3
$IsNet = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ping ${IPB} -c 1;echo `$?"
Write-Host -F Red "DEBUG: During $during s flood ping, load and unload vmxnet3, result is $IsNet"
Write-Output "DEBUG: During $during s flood ping, load and unload vmxnet3, result is $IsNet"
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
