###############################################################################
##
## Description:
##  Shutdown the vm in the Guest, execute command: shutdown
##
## Revision:
##  v1.0.0 - hhei - 2/21/2017 - Shutdown the VM
##  v1.0.1 - boyang - 05/14/2018 - Enhance the script in rhel8 support
##
###############################################################################


<#
.Synopsis
    reboot in vm.

.Description
    Check reboot in vm.

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
$command = ""


$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj)
{
    Write-Host -F Red "ERROR: Unable to Get-VM with $vmName"
    Write-Output "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
	return $Aborted
}


# Get the Guest version
$DISTRO = GetLinuxDistro ${ipv4} ${sshKey}
Write-Host -F red "DEBUG: $DISTRO"
if (-not $DISTRO)
{
    Write-Host -F Red "ERROR: Guest OS version is NULL"
    Write-Output "ERROR: Guest OS version is NULL"
    DisconnectWithVIServer
	return $Aborted
}
Write-Host -F Red "INFO: Guest OS version is $DISTRO"
Write-Output "INFO: Guest OS version is $DISTRO"


# Different Guest DISTRO, different modules
if ($DISTRO -eq "RedHat6")
{
    $command = "poweroff"
}
elseif ($DISTRO -eq "RedHat7")
{
    $command = "systemctl poweroff"
}
elseif ($DISTRO -eq "RedHat8")
{
    $command = "systemctl poweroff"
}
else
{
    Write-Host -F Red "ERROR: Guest OS version isn't belong to test scope"
    Write-Output "ERROR: Guest OS version isn't belong to test scope"
    DisconnectWithVIServer
	return $Aborted
}


Write-Host -F Red "INFO: Is Poweroffing $vmName"
Write-Output "INFO: Is Poweroffing $vmName"
bin\plink.exe -i ssh\${sshKey} root@${ipv4} "$command"


# Confirm the commnad works in the VM
Start-Sleep -seconds 6


$timeout = 300
while ($timeout -gt 0)
{
    $vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
    if (-not $vmObj)
    {
        Write-Host -F Red "ERROR: After start VM $vmObj, lost it"
        Write-Output "ERROR: After start VM $vmObj, lost it"
        DisconnectWithVIServer
        return $Aborted
    }

    if ($vmObj.PowerState -ne "PoweredOff")
    {
        Write-Host -F Red "FAIL: Can't poweroff VM, try again"
        Write-Output "FAIL: Can't poweroff VM, try again"
        Start-Sleep -seconds 1
        $timeout -= 1
    }
    else
    {
        Write-Host -F Red "PASS: Complete the shutdown of the VM"
        Write-Output "PASS: Complete the shutdown of the VM"
        $retVal = $Passed
        break
    }


}


DisconnectWithVIServer
return $retVal
