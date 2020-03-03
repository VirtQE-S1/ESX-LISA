########################################################################################
## Description:
## 	Add a CD drive to the VM
##
## Revision:
## 	v1.1.0 - ldu - 07/23/2018 - Draft script for add cd driver.
## 	v1.2.0 - boyang - 12/23/2019 - Check power state should be off although in setup.
########################################################################################


<#
.Synopsis
    This script will add cd drive to VM.

.Description
    This script will add cd drive to VM.

.Parameter vmName
    Name of the VM to remove disk from.

.Parameter hvServer
    Name of the ESXi server hosting the VM.

.Parameter testParams
    Semicolon separated list of test parameters.

#>


param([string] $vmName, [string] $hvServer, [string] $testParams)


# Checking the input arguments
if (-not $vmName)
{
    "FAIL: VM name cannot be null!"
    exit 100
}

if (-not $hvServer)
{
    "FAIL: hvServer cannot be null!"
    exit 100
}

if (-not $testParams)
{
    Throw "FAIL: No test parameters specified"
}


# Output test parameters so they are captured in log file
"TestParams : '${testParams}'"


# Parse test parameters
$params = $testParams.Split(";")
foreach ($p in $params)
{
	$fields = $p.Split("=")
	switch ($fields[0].Trim())
	{
        "cd_num"     { $cd_num = $fields[1].Trim() }
        "iso"     { $iso = $fields[1].Trim() }
		default			{}
    }
}


# Source tcutils.ps1
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


# VM is in powered off status, as a setup script to add CD driver.
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
$state = $vmObj.PowerState
LogPrint "DEBUG: state: $state"
if ($state -ne "PoweredOff")
{
    LogPrint "ERROR: VM power state should be powered off."
    return $Aborted
}


# Add CD driver.
$CDList =  Get-CDDrive -VM $vmObj
$current_cd = $CDList.Length
while ($current_cd -lt $cd_num)
{
    $add_cd=New-CDDrive -VM $vmObj -ISOPath "$iso" -StartConnected:$true -Confirm:$false -WarningAction SilentlyContinue
    $current_cd=$current_cd+1
    LogPrint "DEBUG: current_cd: $current_cd"
}


# Check the CD drive add successfully
$CDList =  Get-CDDrive -VM $vmObj
$CDLength = $CDList.Length
if ($CDLength -eq $cd_num)
{
    LogPrint "INFO: Add CD driver successfully, find $CDLength CD(s)."
    $retVal = $Passed
}
else
{
    LogPrint "ERROR: Add CD driver failed in setup. There are $CDLength CD(s)."
    DisconnectWithVIServer
    return $retVal
}


DisconnectWithVIServer
return $retVal
