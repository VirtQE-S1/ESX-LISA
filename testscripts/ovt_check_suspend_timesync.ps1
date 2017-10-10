###############################################################################
##
## Description:
##  Suspend and Resume the VM
##
###############################################################################
##
## Revision:
## V1.0 - boyang - 09/06/2017 - Build script
##
###############################################################################

<#
.Synopsis
    Suspend and Resume the VM

.Description
    Suspend and Resume the VM, NO call trace found

.Parameter vmName
    Name of the test VM.

.Parameter hvServer
    Name of the VIServer hosting the VM.

.Parameter testParams
    Semicolon separated list of test parameters.
#>

param([String] $vmName, [String] $hvServer, [String] $testParams)

#
# Checking the input arguments
#
if (-not $vmName)
{
    "FAIL: VM name cannot be null!"
    exit
}

if (-not $hvServer)
{
    "FAIL: hvServer cannot be null!"
    exit
}

if (-not $testParams)
{
    Throw "FAIL: No test parameters specified"
}

#
# Output test parameters so they are captured in log file
#
"TestParams : '${testParams}'"

#
# Parse test parameters
#
$rootDir = $null
$sshKey = $null
$ipv4 = $null
$logdir = $null

$params = $testParams.Split(";")
foreach ($p in $params)
{
	$fields = $p.Split("=")
	switch ($fields[0].Trim())
	{
		"rootDir"		{ $rootDir = $fields[1].Trim() }
		"sshKey"		{ $sshKey = $fields[1].Trim() }
		"ipv4"			{ $ipv4 = $fields[1].Trim() }
		"TestLogDir"	{ $logdir = $fields[1].Trim()}
		default			{}
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

if ($null -eq $sshKey)
{
	"FAIL: Test parameter sshKey was not specified"
	return $False
}

if ($null -eq $ipv4)
{
	"FAIL: Test parameter ipv4 was not specified"
	return $False
}

if ($null -eq $logdir)
{
	"FAIL: Test parameter logdir was not specified"
	return $False
}

#
# Source tcutils.ps1
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
$state = $vmObj.PowerState
if ($state -ne "PoweredOn")
{
    Write-Error -Message "CheckModules: Unable to create VM object for VM $vmName" -Category ObjectNotFound -ErrorAction SilentlyContinue
    return $Aborted
}


    Write-Output "DONE. VM Power state is $state"
    $enable = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "vmware-toolbox-cmd timesync enable"

    if ($enable -ne "Enabled")
    {
        Write-Error -Message "timesync enable failed" -Category ObjectNotFound -ErrorAction SilentlyContinue
        return $Aborted
    }

    Write-Output "Now, will Suspend the VM......."
    $vmObj_suspend = Suspend-VM -VM $vmObj -Confirm:$False
    Start-Sleep -seconds 60
    $state = $vmObj_suspend.PowerState

    write-host -f red "==============$state" > log_a.txt

    if ($state -ne "Suspended")
    {
        Write-Error -Message "CheckModules: Unable to suspend VM $vmName" -Category ObjectNotFound -ErrorAction SilentlyContinue
        return $Aborted
    }
    else
    {
        write-host -f red "DONE. VM Power state is $state"
    }

    write-host -f red "Now, will Power On the VM......." > log_a.txt
    Start-VM -VM $vmObj -Confirm:$False

    $ret = WaitForVMSSHReady $vmName $hvServer ${sshKey} 300
    if ( $ret -eq $true )
    {

    write-host -f red "vm status starts up." > log_a.txt

      }
    else
    {
        write-host -f red "Failed: Failed to start VM."
        return $Aborted
    }

  $result = RunRemoteScript("ovt_check_suspend_timesync.sh")
   if (-not $($result[-1]))
   {
       "Error: Failed to run for $remoteScript"
        $retVal = $Failed
   }
   else
   {
       $retVal = $Passed
   }


DisconnectWithVIServer

return $retVal
