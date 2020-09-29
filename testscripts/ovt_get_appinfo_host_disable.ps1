######################################################################################
## Description:
## Check open-vm-tools appinfo plugin from ESXi host after disable appinfo plugin.
#######################################################################################
## Revision:
## v1.0.0 - ldu - 09/28/2020 - Build script.
#######################################################################################

<#
.Synopsis
    Check open-vm-tools appinfo plugin from ESXi host  after disable appinfo plugin.
.Description
    <test>
        <testName>ovt_get_appinfo_host_disable</testName>
        <testID>ESX-OVT-052</testID>
        <testScript>testscripts/ovt_get_appinfo_host_disable.ps1</testScript>
        <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
        <timeout>900</timeout>
        <testParams>
            <param>TC_COVERED=RHEL-189924</param>
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

# #Get the open vm tools version, if version old then 11, then skip it.
$appinfo = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "rpm -ql open-vm-tools |grep libappInfo" 
if ($appinfo) {
    LogPrint "Info: The OVT support appinfo plugin. $appinfo"
}
else{
    LogPrint "ERROR: The OVT not support appinfo plugin.$appinfo"
    DisconnectWithVIServer
    return $Skipped
}

$vmOut = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmOut)
{
    Write-Error -Message " Unable to create VM object for VM $vmName" -Category ObjectNotFound -ErrorAction SilentlyContinue
    DisconnectWithVIServer
    return $Aborted
}

#Make sure the captures the app information in gust every 1 seconds
bin\plink.exe -i ssh\${sshKey} root@${ipv4} "vmware-toolbox-cmd config set appinfo poll-interval 1" 

#Then disable the appinfo plugin in guest with below command
bin\plink.exe -i ssh\${sshKey} root@${ipv4} "vmware-toolbox-cmd config set appinfo disabled true" 

Start-Sleep 6

bin\plink.exe -i ssh\${sshKey} root@${ipv4} "wget http://sourceforge.net/projects/sshpass/files/latest/download -O sshpass.tar.gz && tar -xvf sshpass.tar.gz && cd sshpass-* && ./configure && make install"
$vminfo = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "sshpass -p '123qweP' ssh -o StrictHostKeyChecking=no root@$hvServer vim-cmd vmsvc/getallvms | grep $vmName"
LogPrint "INFO: The item of $vmName is $vminfo"

$vmid = $($vminfo.split(" "))[0]
LogPrint "INFO: The $vmName's vmid is $vmid"

$res_appinfo = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "sshpass -p '123qweP' ssh -o StrictHostKeyChecking=no root@$hvServer vim-cmd vmsvc/get.config $vmid |grep systemd"
if ($res_appinfo)
{
    LogPrint "Error: Get running appinfo from host: $res_appinfo"
}
else
{
    LogPrint "Pass: Didnot find running appinfo from host: $res_appinfo after disable appinfo plugin"
    $retVal = $Passed
}

DisconnectWithVIServer
return $retVal
