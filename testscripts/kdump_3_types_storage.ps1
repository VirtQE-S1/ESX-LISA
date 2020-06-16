########################################################################################
## Description:
##  Trigger kernel core dump through NFS under network traffic
## Revision:
##  v1.0.0 - xinhu - 12/03/2019 - Build the script.
########################################################################################


<#
.Synopsis
    Trigger kernel core dump through NFS under network traffic

.Description
    <test>
        <testName>kdump_3_types_storage</testName>
        <testID>ESX-KDUMP-07</testID>
        <testScript>testscripts/kdump_3_types_storage.ps1</testScript>
        <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
        <files>remote-scripts\utils.sh</files>
        <files>remote-scripts\ssh_storage.sh</files>
        <timeout>2400</timeout>
        <testParams>
            <param>TC_COVERED=RHEL7-50873</param>
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


# Checking the input arguments
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


$params = $testParams.Split(";")
foreach ($p in $params) {
    $fields = $p.Split("=")
    switch ($fields[0].Trim()) {
        "rootDir" { $rootDir = $fields[1].Trim() }
        "sshKey" { $sshKey = $fields[1].Trim() }
        "ipv4" { $ipv4 = $fields[1].Trim() }
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


# Get the Guest version
$DISTRO = GetLinuxDistro ${ipv4} ${sshKey}
LogPrint "DEBUG: DISTRO: $DISTRO"
if (-not $DISTRO) {
    LogPrint "ERROR: Guest OS version is NULL."
    DisconnectWithVIServer
    return $Aborted
}


# Current version will skip the RHEL6.x.x
if ($DISTRO -ne "RedHat7" -and $DISTRO -ne "RedHat8") {
    LogPrint "ERROR: Guest OS ($DISTRO) isn't supported, MUST UPDATE in Framework / XML / Script."
    DisconnectWithVIServer
    return $Skipped
}


# Function to stop VMB and disconnect with VIserver
Function StopVMB($hvServer,$vmNameB)
{
    $vmObjB = Get-VMHost -Name $hvServer | Get-VM -Name $vmNameB
    Stop-VM -VM $vmObjB -Confirm:$false -RunAsync:$true -ErrorAction SilentlyContinue
    DisconnectWithVIServer
}


# Function to prepare VMB as NFS server
Function PrepareNFSserver($sshKey,$IP_B,$IP_A)
{
    Write-Host -F Green "INFO: Prepare $IP_B as NFS server"
    Write-Output "INFO: Prepare $IP_B as NFS server"
    $result = bin\plink.exe -i ssh\${sshKey} root@${IP_B} "mkdir -p /export/tmp/var/crash && chmod 777 /export/tmp/var/crash && echo '/export/tmp ${IP_A}(rw,sync)' > /etc/exports && systemctl start nfs-server && exportfs -arv && echo `$?"
    if ($result[-1] -ne 0)
    {
        Write-Host -F Red "ERROR: Prepare $IP_B as NFS server failed: $result"
        Write-Output "ERROR: Prepare $IP_B as NFS server failed: $result"
        return $false
    }
    return $true
}


# Function to enable NFS method to store vmcore 
Function EnableNFS($sshKey,${IP_A},${IP_B})
{
    Write-Host -F Green "INFO: Prepare to enable NFS method to store vmcore on $IP_A"
    Write-Output "INFO: Prepare to enable NFS method to store vmcore on ${IP_A}"
    $result = bin\plink.exe -i ssh\${sshKey} root@$IP_A "sed -i 's?#nfs my.server.com?nfs ${IP_B}?' /etc/kdump.conf"
    $cmd = "mount -t nfs ${IP_B}:/export/tmp /mnt/nfs"
    $result = bin\plink.exe -i ssh\${sshKey} root@$IP_A "mkdir -p /mnt/nfs && $cmd"
    if ($result)
    {
        Write-Host -F Red "ERROR: Mount $IP_B failed: $result"
        Write-Output "ERROR: Mount $IP_B failed: $result"
        return $false
    }
    $result = bin\plink.exe -i ssh\${sshKey} root@$IP_A "systemctl restart kdump"
    if ($result)
    {
        Write-Host -F Red "ERROR: Restart kdump failed: $result"
        Write-Output "ERROR: Restart kdump failed: $result"
        return $false
    }
    return $true
}


# Function to enable SSH method to store vmcore 
Function EnableSSH($sshKey,${IP_A},${IP_B})
{
    Write-Host -F Green "INFO: Prepare to enable SSH method to store vmcore on ${IP_A}"
    Write-Output "INFO: Prepare to enable SSH method to store vmcore on ${IP_A}"
    bin\plink.exe -i ssh\${sshKey} root@$IP_A "sed -i 's?nfs ${IP_B}?#nfs my.server.com?' /etc/kdump.conf"
    bin\plink.exe -i ssh\${sshKey} root@$IP_A "sed -i 's?#ssh user@my.server.com?ssh root@${IP_B}?' /etc/kdump.conf"  
    bin\plink.exe -i ssh\${sshKey} root@$IP_A "sed -i 's?core_collector makedumpfile -l --message-level 1 -d 31?core_collector makedumpfile -F --message-level 1 -d 31?' /etc/kdump.conf"
    bin\plink.exe -i ssh\${sshKey} root@$IP_A "yum install -y expect && cd /root && dos2unix ssh_storage.sh && chmod u+x ssh_storage.sh && ./ssh_storage.sh"
    $result = bin\plink.exe -i ssh\${sshKey} root@$IP_A "systemctl restart kdump ; echo `$?"
    if ($result -ne 0)
    {
        Write-Host -F Red "ERROR: Restart kdump failed: $result"
        Write-Output "ERROR: Restart kdump failed: $result"
        return $false
    }
    return $true
}


Function EnableUUID($sshKey,$IP_A,$IP_B,$UUID,$UUID_type)
{
    Write-Host -F Green "INFO: Prepare to enable UUID method to store vmcore on $IP_A"
    Write-Output "INFO: Prepare to enable UUID method to store vmcore on ${IP_A}"
    bin\plink.exe -i ssh\${sshKey} root@$IP_A "sed -i 's?ssh root@${IP_B}?#ssh user@my.server.com?' /etc/kdump.conf"
    bin\plink.exe -i ssh\${sshKey} root@$IP_A "sed -i 's?core_collector makedumpfile -F --message-level 1 -d 31?core_collector makedumpfile -l --message-level 1 -d 31?' /etc/kdump.conf"
    bin\plink.exe -i ssh\${sshKey} root@$IP_A "echo $UUID_type $UUID >> /etc/kdump.conf"
    $result = bin\plink.exe -i ssh\${sshKey} root@$IP_A "systemctl restart kdump ; echo `$?"
    if ($result -ne 0)
    {
        Write-Host -F Red "ERROR: Restart kdump failed: $result"
        Write-Output "ERROR: Restart kdump failed: $result"
        return $false
    }
    return $true
}


# Function to trigger VMA
Function TriggerVM($sshKey,${IP_A},${IP_B},$check_dir,$storage)
{
    Write-Host -F Green "INFO: Trigger the $ipv4 by $storage storage"
    Start-Process ".\bin\plink.exe" "-i .\ssh\demo_id_rsa.ppk root@${IP_A} echo 1 > /proc/sys/kernel/sysrq && echo c > /proc/sysrq-trigger" -PassThru -WindowStyle Hidden
    sleep 300
    if ($storage -eq "UUID")
    {
        $crash = bin\plink.exe -i ssh\${sshKey} root@$IP_A "du -h ${check_dir}"
    }
    else
    {
        $crash = bin\plink.exe -i ssh\${sshKey} root@$IP_B "du -h ${check_dir}"
    }
    Write-Host -F Green "DENUG: Show the result of server: $($crash[0])"
    Write-Output "DENUG: Show the result of server: $($crash[0])"
    $crash[0] -match "^\d{1,3}M\b"
    $vmcore = $($matches[0]).Substring(0,$matches[0].length-1)
    if ([int]$vmcore -gt 30)
    {
        return $true
    }
    Write-Host -F Red "ERROR: Trigger kdump throght $storage store failed: $check_result"
    Write-Output "ERROR: Check ${check_dir}: $vmcore"
    return $false
}


# Prepare VMB
$vmOut = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
$vmNameB = $vmName -creplace ("-A$"),"-B"
Write-Host -F Green "INFO: RevertSnap $vmNameB..."
Write-Output "INFO: RevertSnap $vmNameB..."
$result = RevertSnapshotVM $vmNameB $hvServer
if ($result[-1] -ne $true)
{
    Write-Host -F Red "ERROR: RevertSnap $vmNameB failed"
    Write-Output "ERROR: RevertSnap $vmNameB failed"
    DisconnectWithVIServer
    return $Aborted
}
$vmObjB = Get-VMHost -Name $hvServer | Get-VM -Name $vmNameB
Write-Host -F Green "INFO: Starting $vmNameB..."
Write-Output "INFO: Starting $vmNameB..."
Start-VM -VM $vmObjB -Confirm:$false -RunAsync:$true -ErrorAction SilentlyContinue
$ret = WaitForVMSSHReady $vmNameB $hvServer ${sshKey} 300
if ($ret -ne $true)
{
    write-host -F Red "Failed: Failed to start VM."
    Write-Output "Failed: Failed to start VM."
    DisconnectWithVIServer
    return $Aborted
}
# Refresh status
$vmObjB = Get-VMHost -Name $hvServer | Get-VM -Name $vmNameB
$IPB = GetIPv4ViaPowerCLI $vmNameB $hvServer


# Prepare VMB as NFS-server
$storage = "NFS"
$result= PrepareNFSserver $sshKey $IPB $ipv4
if ($result[-1] -ne $true)
{
    Write-Host -F Red "ERROR: Failed to prepare $IPB as NFS server: $result"
    Write-Output "ERROR: Failed to prepare $IPB as NFS server: $result"
    StopVMB $hvServer $vmNameB
    return $Aborted
}

# Prepare the kdump store of VMA as NFS method
$result = EnableNFS $sshKey $ipv4 $IPB
if ($result[-1] -ne $true)
{
    Write-Host -F Red "ERROR: Enable kdump store as NFS method failed: $result"
    Write-Output "ERROR: Enable kdump store as NFS method failed: $result"
    StopVMB $hvServer $vmNameB
    return $Aborted
}

# Trigger the VMA through nfs storage, and check var/crash
$check_dir = "/export/tmp/var/crash/"
$check_result = TriggerVM $sshKey ${ipv4} ${IPB} $check_dir $storage
if ($check_result[-1] -ne $true)
{
    Write-Output "ERROR: Trigger kdump throght NFS store failed: $check_result"
    StopVMB $hvServer $vmNameB
    return $retValdhcp
}


# Prepare the kdump store of VMA as SSH method
$storage = "SSH"
$result = EnableSSH $sshKey ${ipv4} ${IPB}
if ($result[-1] -ne $true)
{
    Write-Host -F Red "ERROR: Enable kdump store as SSH method failed: $result"
    Write-Output "ERROR: Enable kdump store as SSH method failed: $result"
    StopVMB $hvServer $vmNameB
    return $Aborted
}

# Trigger the VMA through ssh storage, and check var/crash
$check_dir = "/var/crash/"
$check_result = TriggerVM $sshKey ${ipv4} ${IPB} $check_dir $storage
if ($check_result[-1] -ne $true)
{
    Write-Output "ERROR: Trigger kdump throght SSH store failed: $check_result"
    StopVMB $hvServer $vmNameB
    return $retValdhcp
}


# Prepare the kdump store of VMA as UUID method 
$storage = "UUID"
$UUID_item = bin\plink.exe -i ssh\${sshKey} root@$ipv4 "cat /etc/fstab |grep UUID"
$UUID_item = $UUID_item -split " ",3
$UUID = $UUID_item[0]
$UUID_dir = $UUID_item[1]
$UUID_type = $($UUID_item[2].Trim() -split " ")[0]
Write-Host -F Red "DEBUG: UUID_item: $UUID_item  UUID: $UUID UUID_dir: $UUID_dir UUID_type: $UUID_type "
$UUID_item = bin\plink.exe -i ssh\${sshKey} root@$ipv4 "mkdir -p $UUID_dir/var/crash && chmod 777 $UUID_dir/var/crash"
$result = EnableUUID $sshKey $ipv4 $IPB $UUID $UUID_type
if ($result[-1] -ne $true)
{
    Write-Host -F Red "ERROR: Enable kdump store as UUID method failed: $result"
    Write-Output "ERROR: Enable kdump store as UUID method failed: $result"
    StopVMB $hvServer $vmNameB
    return $Aborted
}

# Trigger the VMA through UUID storage, and check var/crash
$check_dir = $UUID_dir + "/var/crash/"
$check_result = TriggerVM $sshKey ${ipv4} ${IPB} $check_dir $storage
if ($check_result[-1] -ne $true)
{
    Write-Output "ERROR: Trigger kdump throght SSH store failed: $check_result"
    StopVMB $hvServer $vmNameB
    return $retValdhcp
}


$retValdhcp = $Passed
StopVMB $hvServer $vmNameB
return $retValdhcp
