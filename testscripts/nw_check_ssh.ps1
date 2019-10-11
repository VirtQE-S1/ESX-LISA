#######################################################################################
## Description:
##  Check ssh connection from other VM and Host
## Revision:
##  v1.0.0 - xinhu - 09/19/2019 - Build the script
##  v1.0.1 - xinhu - 10/10/2019 - Update the script of way to install sshpass
#######################################################################################


<#
.Synopsis
    Check ssh connection from other VM and Host

.Description
    Check ssh connection from other VM and Host
    <test>
            <testName>nw_check_ssh</testName>
            <testID>ESX-NW-022</testID>
            <testScript>testscripts/nw_check_ssh.ps1</testScript>
            <testParams>
                <param>HostIP=10.73.196.33</param>
            </testParams>
            <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
            <timeout>360</timeout>
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
$HostIP = $null


$params = $testParams.Split(";")
foreach ($p in $params) {
    $fields = $p.Split("=")
    switch ($fields[0].Trim()) {
        "rootDir" { $rootDir = $fields[1].Trim() }
        "sshKey" { $sshKey = $fields[1].Trim() }
        "ipv4" { $ipv4 = $fields[1].Trim() }
        "TestLogDir"	{ $logdir = $fields[1].Trim()}
        "HostIP" {$HostIP = $fields[1].Trim()}
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
# Current version only install sshpass by rpm link
$retValdhcp = $False


# Function to ssh Host and BVM
function checkssh(${sshKey},${ipv4},$HostIP)
{
    $SSH1 = $False
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "wget http://sourceforge.net/projects/sshpass/files/latest/download -O sshpass.tar.gz && tar -xvf sshpass.tar.gz && cd sshpass-* && ./configure && make install"
    $SshHost = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "sshpass -p '123qweP' ssh -o StrictHostKeyChecking=no root@$hvServer ls;echo `$? "

    Write-Host -F Red "DEBUG: Using DHCP IP SSH $hvServer : $SshHost"
    Write-Output "DEBUG: Using DHCP IP SSH $hvServer : $SshHost"
    if ($SshHost[-1] -ne 0)
    {
        Write-Host -F Red "ERROR: Using DHCP IP SSH $hvServer Failed"
        Write-Output "ERROR: Using DHCP IP SSH $hvServer Failed"
    }
    else{$SSH1 = $True}
    return $SSH1
}

$linuxOS = GetLinuxDistro $ipv4 $sshKey
$linuxOS = $linuxOS[-1]
$vmOut = Get-VMHost -Name $hvServer | Get-VM -Name $vmName

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
$result = checkssh ${sshKey} ${ipv4} $HostIP
Write-Host -F Red "DEBUG: DHCP SSH result is $result"
Write-Output "DEBUG: DHCP SSH result is $result"
$retValdhcp = $result[-1]

DisconnectWithVIServer
if ($retValdhcp)
{
    return $Passed
}
return $Failed
