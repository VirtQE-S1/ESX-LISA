########################################################################################
## Description:
##  [open-vm-tools]Check the Guest customization with DHCP
##
## Revision:
##  v1.0.0 - ldu - 12/01/2019 - Build the script
##  v1.1.0 - ldu - 01/02/2020 - add remove clone vm function
########################################################################################


<#
.Synopsis
   [open-vm-tools]Check the Guest customization with DHCP

.Description

<test>
        <testName>ovt_customization_DHCP</testName>
        <testID>ESX-OVT-036</testID>
        <testScript>testscripts/ovt_customization_DHCP.ps1</testScript  >
        <files>remote-scripts/utils.sh</files>
        <testParams>
            <param>TC_COVERED=RHEL6-0000,RHEL7-93437</param>
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


#set clone vm name follow each host
$cloneName = $vmName + "-clone"
$OSSpecs = Get-OSCustomizationSpec -Name "ldu-auto-dhcp"
$clone = New-VM -VM $vmObj -Name $cloneName -OSCustomizationSpec $OSSpecs -VMHost $hvServer

$cloneVM = Get-VMHost -Name $hvServer | Get-VM -Name $cloneName
Start clone vm
Start-VM -VM $cloneName -Confirm:$false -RunAsync:$true -ErrorAction SilentlyContinue
if (-not $?) {
    LogPrint "ERROR : Cannot start VM"
    DisconnectWithVIServer
    return $Aborted
}


# Wait for clone VM SSH ready
if ( -not (WaitForVMSSHReady $cloneName $hvServer $sshKey 300)) {
    LogPrint "ERROR : Cannot start SSH"
    DisconnectWithVIServer
    return $Aborted
}
LogPrint "INFO: Ready SSH"


# Get another VM IP addr
$ipv4Addr_clone = GetIPv4 -vmName $cloneName -hvServer $hvServer
$cloneVM = Get-VMHost -Name $hvServer | Get-VM -Name $cloneName

#Check the DNS
$DNSinfo = bin\plink.exe -i ssh\${sshKey} root@${ipv4Addr_clone} "cat /etc/resolv.conf |grep '192.168.1.2'"
if ($null -eq $DNSinfo)
{
    Write-Host -F Red "Failed: the customization gust DNS failed as default with 192.168.1.2, $DNSinfo"
    Write-Output "Failed: the customization gust DNS failed as default with 192.168.1.2, $DNSinfo"
    RemoveVM -vmName $cloneName -hvServer $hvServer
    return $Failed
}


# Check the log for customization
$loginfo = bin\plink.exe -i ssh\${sshKey} root@${ipv4Addr_clone} "cat /var/log/vmware-imc/toolsDeployPkg.log |grep 'Ran DeployPkg_DeployPackageFromFile successfully'"
if ($null -eq $loginfo)
{
    Write-Host -F Red "failed: the customization gust failed with log $loginfo"
    Write-Output "failed: the customization gust failed with log $loginfo"
    RemoveVM -vmName $cloneName -hvServer $hvServer
    return $Failed
}
else
{
    $retVal = $Passed
    Write-Host -F Red "Passed:  the customization gust passed with log $loginfo"
    Write-Output "Passed:  the customization gust passed with log $loginfo"
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
