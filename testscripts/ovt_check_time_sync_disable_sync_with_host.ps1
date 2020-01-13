#######################################################################################
## Description:
##   Check guest time sync when disable via the VMware UI (Uncheck "Synchronice clock
##   with ESXI host"
#######################################################################################
## Revision:
## v1.0 - xinhu - 12/05/2019 - Build script for case ESX-OVT-036.
#######################################################################################

<#
.Synopsis
    Check guest time sync when disable via the VMware UI (Uncheck "Synchronice clock with ESXI host")
    
.Description
    <test>
        <testName>ovt_check_time_sync_disable_sync_with_host</testName>
        <testID>ESX-OVT-036</testID>
        <testScript>testscripts/ovt_check_time_sync_disable_sync_with_host.ps1</testScript>
        <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
        <timeout>1800</timeout>
        <testParams>
            <param>TC_COVERED=RHEL-173220</param>
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
# Current version skip the step to uncheck the box of "syncchronize guest time with host"
# through Vmware UI, because it is a default configure about VMs.

# Function to get the date of VM
Function Get_date($sshKey,$IP)
{
    $date = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "date"
    Write-host -F Green "INFO: The date of $IP is $date"
    $year = [int]$($date.split(" "))[-1]
    return $year
}


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
$year_check = Get_date $sshKey ${ipv4}
$year_set = $year_check+2
$newdate = [string]$year_set+"0101"
bin\plink.exe -i ssh\${sshKey} root@${ipv4} "date -s $newdate"
$res_restvmt = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "systemctl restart vmtoolsd"
$year_check = Get_date $sshKey ${ipv4}
if ($year_check -eq $year_set)
{
    $retVal = $Passed
    Write-host -F Green "INFO: Time didnot sync with host after restart vmtoold when disable with host"
    Write-output "INFO: Time didnot sync with host after restart vmtoold when disable with host"
}
else
{
    Write-host -F Red "ERROR: Time change after restart vmtoold when disable with host, year_check: ${year_check}, year_set: ${year_set}"
    Write-output "ERROR: Time change after restart vmtoold when disable with host, year_check: ${year_check}, year_set: ${year_set}"
}

DisconnectWithVIServer
return $retVal
