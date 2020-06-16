########################################################################################
## Description:
##  Suspend and Resume the VM
##
## Revision:
##  v1.0.0 - boyang - 09/06/2017 - Build script.
########################################################################################


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


# Checking the input arguments
if (-not $vmName)
{
    "FAIL: VM name cannot be null!"
	return $false
}

if (-not $hvServer)
{
    "FAIL: hvServer cannot be null!"
	return $false
}

if (-not $testParams)
{
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


# Check all parameters are valid
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
	    return $false
	}
}

if ($null -eq $sshKey) 
{
	"FAIL: Test parameter sshKey was not specified"
	return $false
}

if ($null -eq $ipv4) 
{
	"FAIL: Test parameter ipv4 was not specified"
	return $false
}

if ($null -eq $logdir)
{
	"FAIL: Test parameter logdir was not specified"
	return $false
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


# Check the VM
$vm_obj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vm_obj) {
    Write-Host -F Red "ERROR: Unable to Get-VM with $vmName."
    Write-Output "ERROR: Unable to Get-VM with $vmName."
    DisconnectWithVIServer
    return $Aborted
}


# Confirm the VM power state should be on
$state = $vm_obj.PowerState
Write-Host -F Red "DEBUG: state: $state."
Write-Output "DEBUG: state: $state."
if ($state -ne "PoweredOn")
{
    Write-Host -F Red "ERROR: VM power state should be powered on."
    Write-Output "ERROR: VM power state should be powered on."
    return $Aborted
}
else
{
	Write-Host -F Red "INFO: Will suspend the VM."
    Write-Output "INFO: Will suspend the VM."
    $suspend = Suspend-VM -VM $vm_obj -Confirm:$false

	# HERE. Hard Code. Hope all RHELs in ESXi Hosts complete the suspend in 180s
    Start-sleep 60

	# After suspend, get the VM and its power state again
    $vm_obj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
    $state = $vm_obj.PowerState
	Write-Host -F Red "DEBUG: state: $state."
	Write-Output "DEBUG: state: $state."
    if ($state -ne "Suspended")
    {
		Write-Host -F Red "ERROR: After suspend operation, the VM power state is incorrect."
        Write-Output "ERROR: After suspend operation, the VM power state is incorrect."
        return $Aborted
    }
    else
    {
		Write-Host -F Red "INFO: Will power on the VM."
    	Write-Output "INFO: Will power on the VM."
        $on = Start-VM -VM $vm_obj -Confirm:$false

		# HERE. Hard Code. Hope all RHELs in ESXi Hosts complete the resume in 360s
        Start-sleep 60
		
		# After resume, get the VM and its power state again		
        $vm_obj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
		$state = $vm_obj.PowerState		
		Write-Host -F Red "DEBUG: state: $state."
		Write-Output "DEBUG: state: $state."
        if ($state -ne "PoweredOn")
        {
			Write-Host -F Red "ERROR: After power on operation, the VM power state is incorrect."
            Write-Output "ERROR: After power on operation, the VM power state is incorrect."
            return $Aborted
        }
        else
        {
		    $status = CheckCallTrace $ipv4 $sshKey
		    if (-not $status[-1]) {
			    Write-Host -F Red "ERROR: Found somethings - $($status[-2])."
			    Write-Output "ERROR: Found somethins - $($status[-2])."
		    }
		    else {
		        LogPrint "INFO: NOT found Call Trace in VM msg after resume."
		        $retVal = $Passed
		    }
        }
    }
}


DisconnectWithVIServer
return $retVal
