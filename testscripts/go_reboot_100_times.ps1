###############################################################################
##
## Description:
## Reboot guet 100 times then check system status.
##
###############################################################################
##
## Revision:
## V1.0 - ldu - 02/28/2018 - Reboot guest 100 times then check system status.
##
##
###############################################################################

<#
.Synopsis
    Reboot guest 100 times.
.Description
<test>
    <testName>go_reboot_100_times</testName>
    <testID>ESX-GO-013</testID>
    <testScript>testscripts\go_reboot_100_times.ps1</testScript>
    <testParams>
        <param>TC_COVERED=RHEL6-49141,RHEL7-111697</param>
    </testParams>
    <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
    <timeout>6000</timeout>
    <onError>Continue</onError>
    <noReboot>False</noReboot>
</test>

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
        "VMMemory"     { $mem = $fields[1].Trim() }
        "standard_diff"{ $standard_diff = $fields[1].Trim() }
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

# Source tcutils.ps1
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

#Reboot the guest 100 times.
$round=0
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

if ($round -eq 100)
{
    $calltrace_check = bin\plink.exe -i ssh\${sshKey} root@${ipv4} 'dmesg | grep "Call Trace"'
    Write-Output "DEBUG: calltrace_check: $calltrace_check"
    Write-Host -F red "DEBUG: calltrace_check: $calltrace_check"

    if ($null -eq $calltrace_check)
    {
        $retVal = $Passed
        Write-host -F Red "INFO: After $round times booting, NO $calltrace_check found"
        Write-Output "INFO: After $round times booting, NO $calltrace_check found"
    }
    else{
        Write-Output "ERROR: After booting, FOUND $calltrace_check in demsg"
    }

}
else{
    Write-host -F Red "ERROR: The guest not boot 100 times, only $round times"
    Write-Output "ERROR: The guest not boot 100 times, only $round times"
}

DisconnectWithVIServer

return $retVal
