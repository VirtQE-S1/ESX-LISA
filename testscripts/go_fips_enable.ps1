########################################################################################
## Description:
## RHEL-182794 - [general operation] Boot up guest with fips enabled
##
## Revision:
##  v1.0.0 - ldu - 01/12/2020 - Build the script
########################################################################################


<#
.Synopsis
   [general operation] Boot up guest with fips enabled
.Description
<test>
        <testName>go_fips_enable</testName>
        <testID>ESX-go-021</testID>
        <testScript>testscripts/go_fips_enable.ps1</testScript>
        <files>remote-scripts/utils.sh</files>
        <testParams>
            <param>TC_COVERED=RHEL6-0000,RHEL-182794</param>
        </testParams>
        <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
        <timeout>1200</timeout>
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
    LogPrint "ERROR: Unable to Get-VM with $vmName."
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


# Different Guest DISTRO have different configure fips method
if ($DISTRO -ne "RedHat7"-and $DISTRO -ne "RedHat8"-and $DISTRO -ne "RedHat6") {
    LogPrint "ERROR: Guest OS ($DISTRO) isn't supported, MUST UPDATE in Framework / XML / Script."
    DisconnectWithVIServer
    return $Skipped
}

if ($DISTRO -eq "RedHat7") 
{
    $command = "df /boot | grep boot | awk '{print `$1}'"
    $bootDisk = Write-Output y | bin\plink.exe -i ssh\${sshKey} root@${ipv4} $command
    LogPrint "DEBUG: bootDisk: ${bootDisk}."
    if ($null -eq $bootDisk)
    {
        LogPrint "ERROR: Failed get the boot disk, ${bootDisk}."
        return $Aborted
    }
    else
    {
        LogPrint "INFO: The boot disk for guest is ${bootDisk}."
    }

    # Get boot disk's UUID.
    $command = "blkid $bootDisk |awk '{print `$2}'"
    $uuid = Write-Output y | bin\plink.exe -i ssh\${sshKey} root@${ipv4} $command
    LogPrint "DEBUG: uuid: ${uuid}."
    if ($null -eq $uuid)
    {
        LogPrint "ERROR: the boot disk's UUID is ${uuid}."
        return $Aborted
    }
    else
    {
        LogPrint "INFO: The boot disk's UUID is ${uuid}."
    }  

    # Cofigure fips enable in guest.
    $Command = "yum install dracut-fips dracut-fips-aesni -y && dracut -v -f && grubby --update-kernel=ALL --args='boot=$uuid' && grubby --update-kernel=ALL --args='fips=1'"
    $status = Write-Output y | bin\plink.exe -i ssh\${sshKey} root@${ipv4} $command
    LogPrint "DEBUG: status: ${status}."
    if (-not $status) 
    {
        LogPrint "ERROR: Configure fips commands failed."
        $retVal = $Aborted
    }
    else
    {
        LogPrint "INFO: Configure fips commands passed."
    }

    #Reboot guest to check the fips
    $reboot = bin\plink.exe -i ssh\${sshKey} root@${ipv4} 'reboot'
    LogPrint "INFO: reboot the guest after configure fips"
    
    # Sleep for seconds to wait for the VM stopping firstly
    Start-Sleep -seconds 6
    
    
    # Wait for the VM booting
    $ret = WaitForVMSSHReady $vmName $hvServer ${sshKey} 300
    if ($ret -ne $true)
    {
        LogPrint "INFO: The guest reboot failed after configure fips enabled."
        return $Aborted
    }
}
else
{
    LogPrint "INFO:The guest is not rehel7, configure the guest fips with fips-mode-setup command."
    $Command = "fips-mode-setup --enable"
    $status = SendCommandToVM $ipv4 $sshkey $command
    if (-not $status) {
        LogPrint "ERROR : Enable fips in $DISTRO guest failed."
        $retVal = $Aborted
    }
    else
    {
        LogPrint "INFO: Enable fips in $DISTRO guest successfully."
        #reboot guest to check the fips
        $reboot = bin\plink.exe -i ssh\${sshKey} root@${ipv4} 'reboot'
        LogPrint "INFO: reboot the guest after configure fips"
        # Sleep for seconds to wait for the VM stopping firstly
        Start-Sleep -seconds 6
        # Wait for the VM booting
        $ret = WaitForVMSSHReady $vmName $hvServer ${sshKey} 300
        if ($ret -ne $true)
        {
            LogPrint "INFO: The guest reboot failed after configure fips enabled."
            return $Aborted
        }
        else
        {
            LogPrint "INFO: The guest reboot successfully."
            $Command = "fips-mode-setup --check |grep enabled"
            $status = SendCommandToVM $ipv4 $sshkey $command
            if (-not $status) 
            {
                LogPrint "ERROR: After reboot, the fips enable failed. "
                return $Failed
            }
            else
            {
                LogPrint "INFO: After reboot, the fips enable passed."
            }
        }
    }
}

# Check the fips value after reboot guest.
$fips = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "cat /proc/sys/crypto/fips_enabled"
if ($fips -eq "1")
{
    LogPrint "INFO: The fips enabled with fips  /proc/sys/crypto/fips_enabled $fips"
    $retVal = $Passed
}
else
{
    LogPrint "ERROR: fips value is not 1 , the value is $fips"
    return $Failed
}    


DisconnectWithVIServer
return $retVal
