########################################################################################
## Description:
##	Reboot guet 100 times then check system status.
##
## Revision:
##	v1.0.0 - ldu - 02/28/2018 - Reboot guest 100 times then check system status.
##	v1.1.0 - boyang - 12/18/2019 - Improve call check scope with a function.
########################################################################################


<#
.Synopsis
    Reboot guest 100 times.

.Description
    Reboot guest 100 times.

.Parameter vmName
    Name of the test VM.

.Parameter hvServer
    Name of the VIServer hosting the VM.

.Parameter testParams
    Semicolon separated list of test parameters.
#>


# Checking the input arguments
param([String] $vmName, [String] $hvServer, [String] $testParams)
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
        "VMMemory"     { $mem = $fields[1].Trim() }
        "standard_diff"{ $standard_diff = $fields[1].Trim() }
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


# Reboot the guest 100 times.
$round = 0
while ($round -lt 100)
{
    $reboot = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "init 6"

    Start-Sleep -seconds 6
    
    # Wait for VM booting
    $ssh = WaitForVMSSHReady $vmName $hvServer ${sshKey} 300
    if ($ssh -ne $true)
    {
        Write-Output "ERROR: Failed to start VM,the round is $round"
        Write-Host -F Red "ERROR: Failed to start VM,the round is $round"
        return $Aborted
    }

    $round=$round+1
    Write-Output "INFO: Round: $round "
    Write-Host -F Red "INFO: Round: $round"
}


# Check rebooting times and error logs.
if ($round -eq 100)
{
	$status = CheckCallTrace $ipv4 $sshKey
	if (-not $status[-1]) {
   		Write-Host -F Red "ERROR: Found $(status[-2]) in msg after 100 times rebooting."
   	 	Write-Output "ERROR: Found $(status[-2]) in msg after 100 times rebooting."

	    DisconnectWithVIServer
	    return $Failed
	}
	else {
	    LogPrint "INFO: NOT found Call Trace in VM msg after 100 times rebooting."
		$retVal = $Passed
	}
}
else
{
    Write-host -F Red "ERROR: The guest can't boot 100 times, only $round times."
    Write-Output "ERROR: The guest can't boot 100 times, only $round times."
}


DisconnectWithVIServer
return $retVal
