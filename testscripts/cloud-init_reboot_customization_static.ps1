########################################################################################
## Description:
##  [cloud-init]Reboot guest and check IP status after case RHEL-137083 Customize Guest uses static IP with cloud-init
##
## Revision:
##  v1.0.0 - ldu - 01/02/2020 - Build the script
##  v1.1.0 - ldu - 01/02/2020 - add remove clone vm function
########################################################################################


<#
.Synopsis
   
[cloud-init]Reboot guest and check IP status after case RHEL-137083 Customize Guest uses static IP with cloud-init
.Description
<test>
            <testName>cloud-init_reboot_customization_static</testName>
            <testID>ESX-cloud-init-006</testID>
            <setupScript>setupscripts\add_vmxnet3.ps1</setupScript>
            <testScript>testscripts/cloud-init_reboot_customization_static.ps1</testScript  >
            <files>remote-scripts/utils.sh</files>
            <testParams>
                <param>nicName=auto-test</param>
                <param>TC_COVERED=RHEL6-0000,RHEL-153099</param>
            </testParams>
            <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
            <timeout>1800</timeout>
            <onError>Continue</onError>
            <noReboot>False</noReboot>
        </test>

.Parameter vmName
    Name of the test VM.

.Parameter testParams
    Semicolon separated list of test parameters.
#>


param([String] $vmName, [String] $hvServer, [String] $testParams)


# Checking the input arguments
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
if ($DISTRO -ne "RedHat7"-and $DISTRO -ne "RedHat8"-and $DISTRO -ne "RedHat6") {
    LogPrint "ERROR: Guest OS ($DISTRO) isn't supported, MUST UPDATE in Framework / XML / Script"
    DisconnectWithVIServer
    return $Skipped
}

$Command = "yum install cloud-init -y"
$status = SendCommandToVM $ipv4 $sshkey $command
if (-not $status) {
    LogPrint "ERROR : install cloud-init failed"
    $retVal = $Aborted
}
else {
       LogPrint "Pass : install cloud-init passed"
}

#clone vm
$cloneName = $vmName + "-clone"
$OSSpecs = Get-OSCustomizationSpec -Name "ldu-test-multinic"
$clone = New-VM -VM $vmObj -Name $cloneName -OSCustomizationSpec $OSSpecs -VMHost $hvServer

$cloneVM = Get-VMHost -Name $hvServer | Get-VM -Name $cloneName
# Start clone vm
Start-VM -VM $cloneName -Confirm:$false -RunAsync:$true -ErrorAction SilentlyContinue
if (-not $?) {
    LogPrint "ERROR : Cannot start VM"
    RemoveVM -vmName $cloneName -hvServer $hvServer
    DisconnectWithVIServer
    return $Aborted
}


# Wait for clone VM SSH ready
if ( -not (WaitForVMSSHReady $cloneName $hvServer $sshKey 300)) {
    LogPrint "ERROR : Cannot start SSH"
    RemoveVM -vmName $cloneName -hvServer $hvServer
    DisconnectWithVIServer
    return $Aborted
}
LogPrint "INFO: Ready SSH"


# Get another VM IP addr
$ipv4Addr_clone = GetIPv4 -vmName $cloneName -hvServer $hvServer
$cloneVM = Get-VMHost -Name $hvServer | Get-VM -Name $cloneName


#Check the static IP for second NIC
$staticIP = bin\plink.exe -i ssh\${sshKey} root@${ipv4Addr_clone} "ip addr |grep '192.168.1.88'"
if ($null -eq $staticIP)
{
    Write-Host -F Red " Failed:  the customization gust Failed with static IP for second NIC $staticIP"
    Write-Output " Failed:  the customization gust Failed with static IP for second NIC $staticIP"
    RemoveVM -vmName $cloneName -hvServer $hvServer
    return $Aborted
}


# Check the log 
$loginfo = bin\plink.exe -i ssh\${sshKey} root@${ipv4Addr_clone} "cat /var/log/vmware-imc/toolsDeployPkg.log |grep 'Deployment for cloud-init succeeded'"
if ($null -eq $loginfo)
{
    Write-Host -F Red " Failed:  the customization gust Failed with log $loginfo"
    Write-Output " Failed:  the customization gust Failed with log $loginfo"
    RemoveVM -vmName $cloneName -hvServer $hvServer
    return $Failed
}
else
{
    Write-Host -F Red " Passed:  the customization gust passed with log $loginfo"
    Write-Output " Passed:  the customization gust passed with log $loginfo"
}

#reboot cloned guest
$reboot = bin\plink.exe -i ssh\${sshKey} root@${ipv4Addr_clone} 'reboot'


# Sleep for seconds to wait for the VM stopping firstly
Start-Sleep -seconds 6

# Wait for the VM booting
$ret = WaitForVMSSHReady $cloneName $hvServer ${sshKey} 300
if ($ret -eq $true)
{
    Write-Host -F Red "PASS: Complete the rebooting"
    Write-Output "PASS: Complete the rebooting"
}
else
{
    Write-Host -F Red "FAIL: The rebooting failed"
    Write-Output "FAIL: The rebooting failed"
    RemoveVM -vmName $cloneName -hvServer $hvServer
    return $Aborted
}


#Check the static IP after reboot guest
$staticIP = bin\plink.exe -i ssh\${sshKey} root@${ipv4Addr_clone} "ip addr |grep '192.168.1.88'"
if ($null -eq $staticIP)
{
    Write-Host -F Red " Failed:  the customization gust Failed with static IP for second NIC $staticIP"
    Write-Output " Failed:  the customization gust Failed with static IP for second NIC $staticIP"
    RemoveVM -vmName $cloneName -hvServer $hvServer
    return $Failed
}
else
{
    $retVal = $Passed
    Write-Host -F Red " Passed:  the customization gust passed with static IP for second NIC $staticIP"
    Write-Output " Passed:  the customization gust passed withstatic IP for second NIC $staticIP"
}    

#Delete the clone VM
$remove = RemoveVM -vmName $cloneName -hvServer $hvServer
if ($null -eq $remove) {
    LogPrint "ERROR: Cannot remove cloned guest"    
    DisconnectWithVIServer
    return $Aborted
}

DisconnectWithVIServer
return $retVal
