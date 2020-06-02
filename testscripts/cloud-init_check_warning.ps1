########################################################################################
## Description:
##  Check no "Warning" level message in /var/log/cloud-init.log
##
## Revision:
##  v1.0.0 - ldu - 05/21/2020 - Build the script
##  
########################################################################################


<#
.Synopsis
	 Check no "Warning" level message in /var/log/cloud-init.log

.Description
	<test>
        <testName>cloud-init_check_warning</testName>
        <testID>ESX-cloud-init-007</testID>
        <setupScript>setupscripts\add_vmxnet3.ps1</setupScript>
        <testScript>testscripts/cloud-init_check_warning.ps1</testScript  >
        <files>remote-scripts/utils.sh</files>
        <testParams>
            <param>nicName=auto-test</param>
            <param>TC_COVERED=RHEL6-0000,RHEL-187894</param>
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


# Checking the input arguments
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
    LogPrint "ERROR: Unable to Get-VM with ${vmName}."
    DisconnectWithVIServer
    return $Aborted
}


# Get the Guest version
$DISTRO = GetLinuxDistro ${ipv4} ${sshKey}
LogPrint "DEBUG: DISTRO: $DISTRO"
if (-not $DISTRO) {
    LogPrint "ERROR: Guest OS version is NULL."
    DisconnectWithVIServer
    return $Aborted
}
LogPrint "INFO: Guest OS version is ${DISTRO}."


# Different Guest DISTRO
if ($DISTRO -ne "RedHat7"-and $DISTRO -ne "RedHat8"-and $DISTRO -ne "RedHat6") {
    LogPrint "ERROR: Guest OS ($DISTRO) isn't supported, MUST UPDATE in Framework / XML / Script."
    DisconnectWithVIServer
    return $Skipped
}


#check cloud-init installed or not in guest, if not, install it.
$version = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "rpm -qa cloud-init" 
if ($null -eq $version) 
{
    LogPrint "INFO: The cloud-init not install on guest $version."
    $Command = "yum install cloud-init -y"
    $status = SendCommandToVM $ipv4 $sshkey $command
    if (-not $status) {
        LogPrint "ERROR : Install cloud-init failed"
        $retVal = $Aborted
    }
    else {
        LogPrint "INFO: Install cloud-init passed"
    }
}
else
{
    LogPrint "INFO: The cloud-init have installed on guest $version."
    $Command = "cloud-init clean -l"
    $status = SendCommandToVM $ipv4 $sshkey $command
    if (-not $status) {
        LogPrint "ERROR : Clean cloud-init log failed"
        $retVal = $Aborted
    }
    else {
        LogPrint "INFO: Clean cloud-init log passed"
    }
}


# Set the clone vm name
$cloneName = $vmName + "-clone-" + (Get-Random -Maximum 1500 -Minimum 1201)
LogPrint "DEBUG: cloneName: ${cloneName}."


# Acquire a new static IP
$ip = "172.19.1." + (Get-Random -Maximum 254 -Minimum 10)
LogPrint "DEBUG: ip: ${ip}."


#  Create the customization specification
$linuxSpec = New-OSCustomizationSpec -Type NonPersistent -OSType Linux -Domain redhat.com -NamingScheme VM
if ($null -eq $linuxSpec) {
    LogPrint "ERROR: Create linuxspec failed."
    DisconnectWithVIServer
    return $Aborted
}
else{
    LogPrint "INFO: Create linuxspec well."
}


# Remove any NIC mappings from the specification
$nicMapping = Get-OSCustomizationNicMapping -OSCustomizationSpec $linuxSpec
Remove-OSCustomizationNicMapping -OSCustomizationNicMapping $nicMapping -Confirm:$false


#Create a new NIC mapping for the first NIC - it will use DHCP IP
New-OSCustomizationNicMapping -OSCustomizationSpec $linuxSpec -IpMode UseDhcp -Position 1
if (-not $?) {
    LogPrint "ERROR: Failed when New-OSCustomizationNicMapping with dhcp IP."
    DisconnectWithVIServer
    return $Aborted
}
else{
    LogPrint "INFO: DHCP NIC config done."
}



# Create another NIC mapping for the second NIC - it will use static IP -DefaultGateway 172.16.1.1 
New-OSCustomizationNicMapping -OSCustomizationSpec $linuxSpec -IpMode UseStaticIP -IpAddress $ip -SubnetMask 255.255.255.0 -DefaultGateway 172.16.1.1 -Position 2
if (-not $?) {
    LogPrint "ERROR: Failed when New-OSCustomizationNicMapping with static IP."
    DisconnectWithVIServer
    return $Aborted
}
else{
    LogPrint "INFO: Static NIC config done."
}


# Clone the vm with new OSCustomization Spec
$clone = New-VM -VM $vmObj -Name $cloneName -OSCustomizationSpec $linuxSpec -VMHost $hvServer -Confirm:$false
LogPrint "INFO: Complete clone operation. Below will check VM cloned."


# Refresh the new cloned vm
$cloneVM = Get-VMHost -Name $hvServer | Get-VM -Name $cloneName
if (-not $cloneVM) {
    LogPrint "ERROR: Unable to Get-VM with ${cloneName}."
    DisconnectWithVIServer
    return $Aborted
}
else{
    LogPrint "INFO: Found the VM cloned - ${cloneName}."
}


# Power on the clone vm
LogPrint "INFO: Powering on $cloneName"
$on = Start-VM -VM $cloneName -Confirm:$false -RunAsync:$true -ErrorAction SilentlyContinue


LogPrint "INFO: Wait for SSH to confirm VM booting."
# Wait for clone VM SSH ready
if ( -not (WaitForVMSSHReady $cloneName $hvServer $sshKey 300)) {
    LogPrint "ERROR : Cannot start SSH."
    RemoveVM -vmName $cloneName -hvServer $hvServer
    DisconnectWithVIServer
    return $Aborted
}
else {
    LogPrint "INFO: Ready SSH."
}


# Get another VM IP addr
$ipv4Addr_clone = GetIPv4 -vmName $cloneName -hvServer $hvServer
LogPrint "DEBUG: ipv4Addr_clone: ${ipv4Addr_clone}."


# Check the static IP for First NIC
$ip_debug = bin\plink.exe -i ssh\${sshKey} root@${ipv4Addr_clone} "ip addr"
LogPrint "DEBUG: ip_debug: ${ip_debug}."

$staticIP = bin\plink.exe -i ssh\${sshKey} root@${ipv4Addr_clone} "ip addr | grep $ip"
LogPrint "DEBUG: staticIP: ${staticIP}."
if ($null -eq $staticIP)
{
    LogPrint "ERROR: The customization gust Failed with static IP for First NIC."
    RemoveVM -vmName $cloneName -hvServer $hvServer
    return $Aborted
}


#  Check no "Warning" level message in /var/log/cloud-init.log
$loginfo = bin\plink.exe -i ssh\${sshKey} root@${ipv4Addr_clone} "grep 'WARNING' /var/log/cloud-init.log"
if ($null -eq $loginfo)
{
    $retVal = $Passed
    LogPrint "INFO: The customization gust passed with log: ${loginfo}."
}
else
{
    LogPrint "ERROR: The customization gust failed with log: ${loginfo}."
    RemoveVM -vmName $cloneName -hvServer $hvServer
    return $Failed
}


# Delete the clone VM.
$remove = RemoveVM -vmName $cloneName -hvServer $hvServer
LogPrint "DEBUG: remove: ${remove}."
if ($null -eq $remove) {
    LogPrint "ERROR: Cannot remove cloned guest." 
    DisconnectWithVIServer
    return $Aborted
}

DisconnectWithVIServer
return $retVal
