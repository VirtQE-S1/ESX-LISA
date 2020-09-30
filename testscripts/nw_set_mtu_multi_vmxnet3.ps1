########################################################################################
## Description:
##	Check vscock modules version in the VM
##
## Revision:
##	v1.0.0 - ruqin - 7/6/2018 - Build the script.
########################################################################################

<#
.Synopsis
    Demo script ONLY for test script.

.Description
        <test>
            <testName>nw_set_mtu_multi_vmxnet3</testName>
            <testID>ESX-NW-016</testID>
            <testScript>testscripts\nw_set_mtu_multi_vmxnet3.ps1</testScript>
            <testParams>
                <param>TC_COVERED=RHEL-111700</param>
            </testParams>
            <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
            <timeout>240</timeout>
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


$MTU_list = 9000, 8000, 7000, 6000, 5000, 4000, 3000, 2000, 1000
foreach ($Set_MTU in $MTU_list) {
    # Get current network adapter name
    $Command = "ip a|grep `$(echo `$SSH_CONNECTION| awk '{print `$3}')| awk '{print `$(NF)}'"
    $Server_Adapter = bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command

    # Start NetworkManager
    if ($DISTRO -eq "RedHat6") {
        SendCommandToVM $ipv4 $sshKey "service network restart"
        # Set New MTU
        SendCommandToVM $ipv4 $sshKey "ifconfig $Server_Adapter mtu $Set_MTU"
        # Restart NetworkManager
        SendCommandToVM $ipv4 $sshKey "service network restart"
        # Get New MTU
        $Command = "ifconfig $Server_Adapter | grep -i mtu | awk '{print `$(NF-1)}' | awk 'BEGIN{FS=\`":\`"}{print `$2}'"
        $MTU = bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command
    }
    else {
        SendCommandToVM $ipv4 $sshKey "systemctl restart NetworkManager"
        # Set New MTU
        SendCommandToVM $ipv4 $sshKey "nmcli connection modify `$(nmcli connection show | grep $Server_Adapter | awk '{print `$(NF-2)}') mtu $Set_MTU"
        # Restart NetworkManager
        SendCommandToVM $ipv4 $sshKey "systemctl restart NetworkManager"
        # Get New MTU
        $Command = "nmcli connection show `$(nmcli connection show | grep $Server_Adapter | awk '{print `$(NF-2)}') | grep -w mtu | awk '{print `$2}'"
        $MTU = bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command
    }

    if ($MTU -ne $Set_MTU) {
        LogPrint "ERROR: Unable to Set MTU to $Set_MTU, Current MTU is $MTU"
        DisconnectWithVIServer
        return $Failed
    }
    else {
        LogPrint "INFO: Success Set MTU to $Set_MTU"

    }
    $retVal = $Passed
}


DisconnectWithVIServer
return $retVal
