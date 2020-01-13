#######################################################################################
## Description:
##   Check open-vm-tools report NetIpRouteInfo to vSphere APIs
#######################################################################################
## Revision:
## v1.0 - xinhu - 12/06/2019 - Build script for case ESX-OVT-036.
#######################################################################################

<#
.Synopsis
    Check open-vm-tools report NetIpRouteInfo to vSphere APIs
    
.Description
    <test>
        <testName>ovt_check_netiprouteconfigureinfo</testName>
        <testID>ESX-OVT-037</testID>
        <testScript>testscripts/ovt_check_netiprouteconfigureinfo.ps1</testScript>
        <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
        <timeout>1800</timeout>
        <testParams>
            <param>TC_COVERED=RHEL7-50876</param>
        </testParams>
        <onError>Continue</onError>
        <noReboot>False</noReboot> 
    </test>
.Parameter vmName
    Name of the test VM.
.Parameter testParams
    Semicolon separated list of test parameters.
#>

param([String] $vmName, [String] $hvServer, [String] $testParams)
#
# Checking the input arguments
#
if (-not $vmName)
{
    "Error: VM name cannot be null!"
    exit
}

if (-not $hvServer)
{
    "Error: hvServer cannot be null!"
    exit
}

if (-not $testParams)
{
    Throw "Error: No test parameters specified"
}

#
# Display the test parameters so they are captured in the log file
#
"TestParams : '${testParams}'"

#
# Parse the test parameters
#
$rootDir = $null
$sshKey = $null
$ipv4 = $null

$params = $testParams.Split(";")
foreach ($p in $params)
{
    $fields = $p.Split("=")
    switch ($fields[0].Trim())
    {
    "sshKey"       { $sshKey = $fields[1].Trim() }
    "rootDir"      { $rootDir = $fields[1].Trim() }
    "ipv4"         { $ipv4 = $fields[1].Trim() }
    default        {}
    }
}

if (-not $rootDir)
{
    "Warn : no rootdir was specified"
}
else
{
    if ( (Test-Path -Path "${rootDir}") )
    {
        cd $rootDir
    }
    else
    {
        "Warn : rootdir '${rootDir}' does not exist"
    }
}

#
# Source the tcutils.ps1 file
#
. .\setupscripts\tcutils.ps1

PowerCLIImport
ConnectToVIServer $env:ENVVISIPADDR `
                  $env:ENVVISUSERNAME `
                  $env:ENVVISPASSWORD `
                  $env:ENVVISPROTOCOL
#######################################################################################
## Main body
#######################################################################################
$retVal = $Failed


# OVT is skipped in RHEL6
$OS = GetLinuxDistro  $ipv4 $sshKey
if ($OS -eq "RedHat6")
{
    Write-host -F Red "Current scripts need version of RHEL >= 7"
    DisconnectWithVIServer
    return $Skipped
}

$vmOut = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmOut)
{
    Write-Error -Message " Unable to create VM object for VM $vmName" -Category ObjectNotFound -ErrorAction SilentlyContinue
    DisconnectWithVIServer
    return $Skipped
}

bin\plink.exe -i ssh\${sshKey} root@${ipv4} "wget http://sourceforge.net/projects/sshpass/files/latest/download -O sshpass.tar.gz && tar -xvf sshpass.tar.gz && cd sshpass-* && ./configure && make install"
$vminfo = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "sshpass -p '123qweP' ssh -o StrictHostKeyChecking=no root@$hvServer vim-cmd vmsvc/getallvms | grep $vmName"
Write-host -F Green "INFO: The item of $vmName is $vminfo"
Write-output "INFO: The item of $vmName is $vminfo"
$vmid = $($vminfo.split(" "))[0]
$res_userinfo = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "sshpass -p '123qweP' ssh -o StrictHostKeyChecking=no root@$hvServer vim-cmd vmsvc/get.guest $vmid | grep IpRouteConfigInfo"
if ($res_userinfo)
{
    $retVal = $Passed
    Write-host -F Green "INFO: Find NetIpRouteInfo from host: $res_userinfo"
    Write-output "INFO: Find NetIpRouteInfo from host: $res_userinfo"
}
else
{
    Write-host -F Red "ERROR: Didnot find NetIpRouteInfo from host "
    Write-output "ERROR: Didnot find NetIpRouteInfo from host "
}

DisconnectWithVIServer
return $retVal
