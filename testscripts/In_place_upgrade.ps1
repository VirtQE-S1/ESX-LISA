########################################################################################
## Description:
## After in place upgrade from RHEL 7 to RHEL 8, run sanity check for guest.
##
## Revision:
##  v1.0.0 - ldu - 09/27/2020 - Build scripts.
########################################################################################


<#
.Synopsis

.Description
        <test>
            <testName>In_place_upgrade</testName>
            <testID>ESX-GO-033</testID>
            <testScript>testscripts\in_place_upgrade1.ps1</testScript>
            <files>remote-scripts/utils.sh,remote-scripts/In_place_upgrade.sh</files>
            <testParams>
                <param>TC_COVERED=RHEL7-80008</param>
            </testParams>
            <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
            <timeout>12000</timeout>
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
# Checking the input arguments
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

# Get the VM
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName

$result = SendCommandToVM $ipv4 $sshKey "cd /root && dos2unix In_place_upgrade.sh && chmod u+x In_place_upgrade.sh && ./In_place_upgrade.sh"
if (-not $result)
{
	LogPrint "ERROR: The upgrade shell script run failed, please check the summary log."
	$retVal = $Failed
}
else
{
	LogPrint "INFO: The in place upgrade shell schript run successfully.please wait the guest reboot."
}

# Wait for GuestA SSH ready.
if ( -not (WaitForVMSSHReady $vmObj $hvServer $sshKey 600)) {
    LogPrint "ERROR : Cannot start SSH."
    DisconnectWithVIServer
    return $Aborted
}
else
{
    LogPrint "INFO: Ready SSH."
}

#Check guest version after upgrade
$grep = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "cat /etc/redhat-release |grep 8."
LogPrint "DEBUG: grep: ${grep}."
if ($null -eq $grep)
{
	LogPrint "ERROR: After upgrade the RHEL version not right."
    DisconnectWithVIServer
	return $Failed
}
else
{
	LogPrint "INFO:  After upgrade the RHEL version as expected."
}

#Run os-test after guest upgrade
$os_tests = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "python3 -m unittest -v os_tests.os_tests_all"
if (-not $os_tests)
{
	LogPrint "ERROR: Failed to run os-tests."
}
else
{
    LogPrint "INFO: The os-tests run completed, please check the result under /tmp/."
    $retVal = $Passed
}

DisconnectWithVIServer
return $retVal
