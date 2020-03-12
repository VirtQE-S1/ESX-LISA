########################################################################################
##  Description:
##  	SCP a large file from the VM A to VM B with different disk type.
##
##  Revision:
##		v1.0.0 - ldu - 07/31/2018 - Build the script
##      v1.0.1 - boyang - 05/10/2019 - Enhance and normalize script
########################################################################################


<#
.Synopsis
    SCP a large file from the VM A to VM B with different disk types
.Description
    cases.xml
.Parameter vmName
    Name of the VM to add disk.
.Parameter hvServer
    Name of the ESXi server hosting the VM.
.Parameter testParams
    Test data for this test case
#>


param([String] $vmName, [String] $hvServer, [String] $testParams)
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


# Display the test parameters so they are captured in the log file
"TestParams : '${testParams}'"


# Parse the test parameters
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
    "TestLogDir"   { $testLogDir = $fields[1].Trim() }
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


# Source the tcutils.ps1 file
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


$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj) {
    LogPrint "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
    return $Aborted
}


# Get VMB by Name
$vmBName = $vmName -replace "-A$","-B"
$vmObjectB = Get-VMHost -Name $hvServer | Get-VM -Name $VMBName
if (-not $vmObjectB) {
    LogPrint "ERROR: Unable to Get-VM with ${vmObjectB}."
    DisconnectWithVIServer
    return $Aborted
}
LogPrint "INFO: Found the VM cloned - ${vmObjectB}."


# Start VMB
$on = Start-VM -VM $vmObjectB -Confirm:$false -RunAsync:$true -ErrorAction SilentlyContinue


# Confirm VMB SSH
if (-not (WaitForVMSSHReady $VMBName $hvServer $sshKey 300)) {
    LogPrint "ERROR : Cannot start SSH"
    DisconnectWithVIServer
    return $Aborted
}


# Get VMB IP addr
$ipv4B = GetIPv4 -vmName $VMBName -hvServer $hvServer
LogPrint "DEBUG: ipv4B $ipv4B"


# Add ipv4B addr to constants.sh
$result = SendCommandToVM $ipv4 $sshKey "echo 'ipv4B=$ipv4B' >> ~/constants.sh"
if (-not $result[-1])
{
    LogPrint "ERROR: Cannot add ipv4B addr into constants.sh file"
	DisconnectWithVIServer
	return $Aborted
}


# Run scp script
RunRemoteScript "stor_scp_big_files.sh" | Write-Output -OutVariable result
if (-not $result[-1])
{
	LogPrint "ERROR: Failed to execute stor_scp_big_files.sh in VM"
	DisconnectWithVIServer
	return $Failed
}
else
{
    LogPrint "INFO: Execute stor_scp_big_files script in VM successfully, and power off the VM B"
    $retVal = $Passed
}


DisconnectWithVIServer
return $retVal
