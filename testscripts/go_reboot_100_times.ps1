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


# Checking the input arguments.
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

    Start-Sleep -seconds 18
    
    # Wait for the VM booting.
    $ssh = WaitForVMSSHReady $vmName $hvServer ${sshKey} 360
    if ($ssh -ne $true)
    {
        LogPrint "ERROR: Failed to start the VM in round ${round}."
        return $Aborted
    }

    $round = $round + 1
    LogPrint "DEBUG: Round: ${round}."
}


# Check rebooting times and error logs.
if ($round -eq 100)
{
	$status = CheckCallTrace $ipv4 $sshKey
	if (-not $status[-1]) {
   	 	LogPrint "ERROR: Found $($status[-2]) in dmesg."
	}
	else {
	    LogPrint "INFO: NOT found Call Trace in dmesg."
		$retVal = $Passed
	}
}
else
{
    LogPrint "ERROR: The guest can't boot with 100 times, only $round times."
}


DisconnectWithVIServer
return $retVal
