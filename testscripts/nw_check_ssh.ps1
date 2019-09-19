###############################################################################
## Description:
##  Check ssh 
## Revision:
##  v1.0.0 - xinhu - 09/19/2019 - Build the script
###############################################################################


<#
.Synopsis
    Check NIC operstate when ifup / ifdown

.Description
    Check NIC operstate when ifup / ifdown, operstate owns up / down states

     <test>
            <testName>nw_check_operstate</testName>
            <testID>ESX-NW-009</testID>
            <testScript>testscripts\nw_check_operstate.ps1</testScript>
            <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
            <timeout>600</timeout>
            <testParams>
                <param>TC_COVERED=RHEL6-34937,RHEL7-50917</param>
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


###############################################################################
## Main Body
###############################################################################
# Current version only execute ssh by dhcp ip.
$retValdhcp = $False
#$retValsta = $False


# Function to ssh Host and BVM
function checkssh(${sshKey},${ipv4},$hvServer,${BvmIP},$linuxOS)
{
    $SSH1 = $False
    $SSH2 = $False
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "rpm -i http://download.eng.bos.redhat.com/brewroot/vol/rhel-$linuxOS/packages/sshpass/1.06/2.el$linuxOS/x86_64/sshpass-1.06-2.el$linuxOS.x86_64.rpm"
    #bin\plink.exe -i ssh\${sshKey} root@${ipv4} "wget https://jaist.dl.sourceforge.net/project/sshpass/1.06/sshpass-1.06.tar.gz"
    #bin\plink.exe -i ssh\${sshKey} root@${ipv4} "tar -zxf sshpass-1.06.tar.gz && sshpass-1.06.tar.gz"
    #bin\plink.exe -i ssh\${sshKey} root@${ipv4} "./configure && make && make install"
    $SshHost = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "sshpass -p '123qweP' ssh -o StrictHostKeyChecking=no root@$hvServer ls;echo `$? "
    $SshVM = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ssh -i .ssh/id_rsa_private -o StrictHostKeyChecking=no root@${BvmIP} ls; echo `$? "

    Write-Host -F Red "DEBUG: Using DHCP IP SSH $BvmName : $SshVM"
    Write-Output "DEBUG: Using DHCP IP SSH $BvmName : $SshVM"
    if ($SshVM[-1] -ne 0)
    {
        Write-Host -F Red "ERROR: Using DHCP IP SSH $BvmName Failed"
        Write-Output "ERROR: Using DHCP IP SSH $BvmName Failed"
    }
    else
    {
        $SSH1 = $True
    }

    Write-Host -F Red "DEBUG: Using DHCP IP SSH $hvServer : $SshHost"
    Write-Output "DEBUG: Using DHCP IP SSH $hvServer : $SshHost"
    if ($SshHost[-1] -ne 0)
    {
        Write-Host -F Red "ERROR: Using DHCP IP SSH $hvServer Failed"
        Write-Output "ERROR: Using DHCP IP SSH $hvServer Failed"
    }
    else{$SSH2 = $True}
    return $SSH1 -and $SSH2
}


$linuxOS = GetLinuxDistro $ipv4 $sshKey
$linuxOS = $linuxOS[-1]
Write-Host -F Red "DEBUG: Using $linuxOS"
Write-Output "DEBUG: Using $linuxOS"

$vmOut = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
$BvmName = $vmName -replace 'A',"B"
$BvmOut = Get-VMHost -Name $hvServer | Get-VM -Name $BvmName
if (-not $BvmOut) {
    LogPrint "ERROR: Unable to Get-VM with $BvmName"
    DisconnectWithVIServer
    return $Aborted
}
Write-Host -F Red "DEBUG: Rebooting...: $BvmName"
Write-Output "DEBUG: Rebooting...: $BvmName"
$reboot = Start-VM -VM $BvmOut -Confirm:$False

# WaitForVMSSHReady
$ret = WaitForVMSSHReady $BvmName $hvServer ${sshKey} 300

$BvmOut = Get-VMHost -Name $hvServer | Get-VM -Name $BvmName
$state = $BvmOut.PowerState
Write-Host -F Red "DEBUG: state: $state"
Write-Output "DEBUG: state: $state"
if ($state -ne "PoweredOn")
{
    Write-Error -Message "ABORTED: $BvmOut is not poweredOn, power state is $state" -Category ObjectNotFound -ErrorAction SilentlyContinue
    DisconnectWithVIServer
    return $Aborted
} 

$BvmIP = $BvmOut.Guest.IPAddress[0]
Write-Host -F Red "DEBUG: vmName: $vmName, vmIP: ${ipv4}; BvmName: $BvmName, BvmIP: $BvmIP"
Write-Output "DEBUG: vmName: $vmName, vmIP: ${ipv4}; BvmName: $BvmName, BvmIP: $BvmIP"

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

# Set dhcp ip and check ssh 
$result = checkssh ${sshKey} ${ipv4} $hvServer ${BvmIP} $linuxOS
Write-Host -F Red "DEBUG: DHCP SSH result is $result"
Write-Output "DEBUG: DHCP SSH result is $result"
$retValdhcp = $result[-1]

DisconnectWithVIServer
if ($retValdhcp)
{
    return $Passed
}
return $Failed
