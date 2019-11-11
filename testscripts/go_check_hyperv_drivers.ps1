###############################################################################
##
## Description:
##  Verify hyper-v drivers and hyperv-daemons are disabled on non-hyperv platform
##
##
## Revision:
##  v1.0.0 - ldu - 11/11/2019 - Build Scripts
##
###############################################################################


<#
.Synopsis
Verify hyper-v drivers and hyperv-daemons are disabled on non-hyperv platform

.Description
    <test>
        <testName>go_check_hyperv_drivers</testName>
        <testID>ESX-GO-022</testID>
        <testScript>testscripts/go_check_hyperv_drivers.ps1</testScript  >
        <files>remote-scripts/utils.sh</files>
        <testParams>
            <param>TC_COVERED=RHEL6-0000,RHEL-178654</param>
        </testParams>
        <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
        <timeout>600</timeout>
        <onError>Continue</onError>
        <noReboot>False</noReboot>
    </test

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
    exit 100
}

if (-not $hvServer)
{
    "Error: hvServer cannot be null!"
    exit 100
}

if (-not $testParams)
{
    Throw "Error: No test parameters specified"
}


#
# Output test parameters so they are captured in log file
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


#
# Check all parameters are valid
#
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


###############################################################################
#
# Main Body
#
###############################################################################


$retVal = $Failed


$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj)
{
    Write-Host -F Red "ERROR: Unable to Get-VM with $vmName"
    Write-Output "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
	return $Aborted
}

#check hyperv related service status
$hyperv_check = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "systemctl is-enabled hyperv{kvpd,vssd,fcopyd} | grep static |wc -l"
if (3 -eq $hyperv_check)
{
    Write-host -F Red "INFO: After boot,  the hyperv related service status all static $hyperv_check"
    Write-Output "INFO: After boot,  the hyperv related service status all static  $hyperv_check"
}
else
{
    Write-Output "ERROR: After boot, the hyperv related service status not static $hyperv_check"
    DisconnectWithVIServer
    return $Failed
}

#Check the hyperv related drivers
$hyperv_check = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "lsmod | grep -E 'hv|hyperv'"
if ($null -eq $hyperv_check)
{
    $retVal = $Passed
    Write-host -F Red "INFO: After boot, NO $hyperv_check hyperv related driver found"
    Write-Output "INFO: After boot, NO $hyperv_check hyperv related driver found"
}
else{
    Write-Output "ERROR: After boot, FOUND $hyperv_check hyperv related driver in demsg"
}


DisconnectWithVIServer
return $retVal
