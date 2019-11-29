#######################################################################################
## Description:
##  Trigger kernel core dump through NFS under network traffic
## Revision:
##  v1.0.0 - xinhu - 11/28/2019 - Build the script
#######################################################################################


<#
.Synopsis
    Trigger kernel core dump through NFS under network traffic

.Description
    <test>
        <testName>kdump_3_types_storage</testName>
        <testID>ESX-KDUMP_07</testID>
        <testScript>testscripts/kdump_3_types_storage.ps1</testScript>
        <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
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
    LogPrint "ERROR: Guest OS version is NULL"
    DisconnectWithVIServer
    return $Aborted
}
LogPrint "INFO: Guest OS version is $DISTRO"
# Current version will skip the RHEL6.x.x
if ($DISTRO -ne "RedHat7" -and $DISTRO -ne "RedHat8") {
    LogPrint "ERROR: Guest OS ($DISTRO) isn't supported, MUST UPDATE in Framework / XML / Script"
    DisconnectWithVIServer
    return $Skipped
}


# Change the dir for changing crashkernel for EFI or BIOS on RHEL7/8
$dir = "/boot/grub2/grub.cfg"
$words = $vmName.split('-')
if ($words[-2] -eq "EFI")
{
    $dir = "/boot/efi/EFI/redhat/grub.cfg"
}
Write-host -F Red "DEBUG: $vmName $dir"


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


# Function to prepare VMB as SSH server
Function PrepareSSHserver($sshKey,$IP_B,$IP_A)
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
    Write-Host -F Green "INFO: Prepare to enable SSH method to store vmcore on $IP_A"
    Write-Output "INFO: Prepare to enable SSH method to store vmcore on ${IP_A}"
    bin\plink.exe -i ssh\${sshKey} root@$IP_A "sed -i 's?nfs ${IP_B}?#nfs my.server.com?' /etc/kdump.conf"
    bin\plink.exe -i ssh\${sshKey} root@$IP_A "sed -i 's?#ssh user@my.server.com?ssh root@${IP_B}?' /etc/kdump.conf"  
    bin\plink.exe -i ssh\${sshKey} root@$IP_A "sed -i 's?#sshkey /root/.ssh/kdump_id_rsa?sshkey /root/.ssh/id_rsa_private?' /etc/kdump.conf"
    bin\plink.exe -i ssh\${sshKey} root@$IP_A "sed -i 's?#core_collector makedumpfile -l --message-level -d 31?core_collector makedumpfile -F --message-level -d 31?' /etc/kdump.conf"
    $result = bin\plink.exe -i ssh\${sshKey} root@$IP_A "systemctl restart kdump"
    if ($result)
    {
        Write-Host -F Red "ERROR: Restart kdump failed: $result"
        Write-Output "ERROR: Restart kdump failed: $result"
        return $false
    }
    return $true
}


# Function to trigger VMA
Function TriggerVM($sshKey,${IP_A},${IP_B},$check_dir)
{
    Write-Host -F Green "INFO: Trigger the $ipv4"
    Start-Process ".\bin\plink.exe" "-i .\ssh\demo_id_rsa.ppk root@${IP_A} echo 1 > /proc/sys/kernel/sysrq && echo c > /proc/sysrq-trigger" -PassThru -WindowStyle Hidden
    sleep 120
    $crash = bin\plink.exe -i ssh\${sshKey} root@$IPB "du -h ${check_dir}" 
    Write-Host -F Green "DENUG: Show the result of nfs-server: $crash"
    $crash[0] -match "^\d{1,3}M\b"
    if ($($matches[0]).Substring(0,$matches[0].length-1) -gt 30)
    {
        Write-Host -F Red "INFO: Check ${check_dir}: $crash"
        Write-Output "INFO: Check ${check_dir}: $crash"
        return $true
    }
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


# Change crashkernel
Write-Host -F Green "INFO: Change the crashkernel = 512M of $ipv4"
$result = bin\plink.exe -i ssh\${sshKey} root@$ipv4 "sed -i 's?crashkernel=auto?crashkernel=512M?' /etc/default/grub && grub2-mkconfig -o $dir && echo `$? "
if ($result -ne 0)
{
    Write-Host -F Red "ERROR: Change crashkernel = 512M failed: $result"
    Write-Output "ERROR: Change crashkernel = 512M failed: $result"
    StopVMB $hvServer $vmNameB
    return $Aborted
}


# Prepare VMB as NFS-server
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
$check_result = TriggerVM $sshKey ${ipv4} ${IPB} $check_dir
if ($check_result[-1] -ne $true)
{
    Write-Host -F Red "ERROR: Trigger kdump throght NFS store failed: $check_result"
    Write-Output "ERROR: Trigger kdump throght NFS store failed: $check_result"
    StopVMB $hvServer $vmNameB
    return $retValdhcp
}

# Wait for VMA reboot
sleep 180


# Prepare the kdump store of VMA as SSH method
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
$check_result = TriggerVM $sshKey ${ipv4} ${IPB} $check_dir
if ($check_result[-1] -ne $true)
{
    Write-Host -F Red "ERROR: Trigger kdump throght NFS store failed: $check_result"
    Write-Output "ERROR: Trigger kdump throght NFS store failed: $check_result"
    StopVMB $hvServer $vmNameB
    return $retValdhcp
}

# Wait for VMA reboot
sleep 180


# Trigger the VMA through UUID storage, and check var/crash


$retValdhcp = $Passed
StopVMB $hvServer $vmNameB
return $retValdhcp
