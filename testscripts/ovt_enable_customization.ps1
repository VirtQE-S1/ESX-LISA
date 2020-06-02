########################################################################################
## Description:
##   Enable the guest customization in the guest after disable guest customization.
##
## Revision:
##  v1.0.0 - ldu - 05/28 /2020 - Build the script
## 
########################################################################################


<#
.Synopsis
   Enable guest customization
.Description

<test>
        <testName>ovt_enable_customization</testName>
        <testID>ESX-OVT-047</testID>
        <testScript>testscripts/ovt_enable_customization.ps1</testScript  >
        <files>remote-scripts/utils.sh</files>
        <testParams>
            <param>TC_COVERED=RHEL6-0000,RHEL-187727</param>
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
    LogPrint "ERROR: Unable to Get-VM with ${vmName}."
    DisconnectWithVIServer
    return $Aborted
}



# Get the Guest version
$DISTRO = GetLinuxDistro ${ipv4} ${sshKey}
LogPrint "DEBUG: DISTRO: ${DISTRO}."
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

#check the ovt version, if version old then 11, skip it.
$version = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "rpm -qa open-vm-tools" 
$ver_num = $($version.split("-"))[3]
LogPrint "DEBUG: version: ${version} and ver_num is $ver_num."
if ($ver_num -ge 11.1) {
    LogPrint "Info: The OVT version is $ver_num."
}
else
{
    LogPrint "Info: The OVT version is $ver_num."
    LogPrint "ERROR: The OVT version older then 11.1, not support disable customization个."
    DisconnectWithVIServer
    return $Skipped
}

#Disable customization in guest
$Command = "vmware-toolbox-cmd config set deployPkg enable-customization false"
$status = SendCommandToVM $ipv4 $sshkey $command
if (-not $status) {
    LogPrint "ERROR : Disable customization failed"
    $retVal = $Aborted
}
else {
       LogPrint "INFO: Disable customization passed"
}

Start-Sleep 3

#Enable customization in guest
$Command = "vmware-toolbox-cmd config set deployPkg enable-customization true"
$status = SendCommandToVM $ipv4 $sshkey $command
if (-not $status) {
    LogPrint "ERROR : Enable customization failed"
    $retVal = $Aborted
}
else {
       LogPrint "INFO: Enable customization passed"
}

# Set the clone vm name
$cloneName = $vmName + "-clone-" + (Get-Random -Maximum 600 -Minimum 301)
LogPrint "DEBUG: cloneName: ${cloneName}."


# Create the customization specification
$linuxSpec = New-OSCustomizationSpec -Type NonPersistent -OSType Linux -Domain redhat.com -NamingScheme VM
if ($null -eq $linuxSpec) {
    LogPrint "ERROR: Create linuxspec failed."
    RemoveVM -vmName $cloneName -hvServer $hvServer
    DisconnectWithVIServer
    return $Aborted
}
LogPrint "INFO: Create linuxspec well."


# Clone the vm with new OSCustomization Spec
$clone = New-VM -VM $vmObj -Name $cloneName -OSCustomizationSpec $linuxSpec -VMHost $hvServer -Confirm:$false
LogPrint "INFO: Complete clone operation. Below will check VM cloned."


# Refresh the new cloned vm
$cloneVM = Get-VMHost -Name $hvServer | Get-VM -Name $cloneName
if (-not $cloneVM) {
    LogPrint "ERROR: Unable to Get-VM with ${cloneName}."
    RemoveVM -vmName $cloneName -hvServer $hvServer
    DisconnectWithVIServer
    return $Aborted
}
LogPrint "INFO: Found the VM cloned - ${cloneName}."


# Power on the clone vm
LogPrint "INFO: Powering on $cloneName"
$on = Start-VM -VM $cloneName -Confirm:$false -ErrorAction SilentlyContinue


# Wait for clone VM SSH ready
LogPrint "INFO: Wait for SSH to confirm VM booting."
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


# Check the log for customization
$loginfo = bin\plink.exe -i ssh\${sshKey} root@${ipv4Addr_clone} "cat /var/log/vmware-imc/toolsDeployPkg.log |grep 'Ran DeployPkg_DeployPackageFromFile successfully'"
if ($null -eq $loginfo)
{
    LogPrint "ERROR: Enable customization gust failed with log ${loginfo}."
    RemoveVM -vmName $cloneName -hvServer $hvServer
    return $Failed
}
else
{
    $retVal = $Passed
    LogPrint "INFO: Enable customization gust passed with log ${loginfo}."
}


# Delete the clone VM
$remove = RemoveVM -vmName $cloneName -hvServer $hvServer
if ($null -eq $remove) {
    LogPrint "ERROR: Cannot remove cloned guest."    
    DisconnectWithVIServer
    return $Aborted
}


DisconnectWithVIServer
return $retVal
