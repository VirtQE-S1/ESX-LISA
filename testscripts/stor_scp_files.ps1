###############################################################################
##
## Description:
##   SCP a large file from the VM A to VM B with different disk type.
##
###############################################################################
##
## Revision:
## v1.0 - ldu - 07/31/2018 - Build the script
##
###############################################################################
<#
.Synopsis
    SCP a large file from the VM A to VM B with different disk type
.Description
 <test>
            <testName>stor_scp_big_files</testName>
            <testID>ESX-Stor-015</testID>
            <setupScript>
                <file>SetupScripts\revert_guest_B.ps1</file>
                <file>setupscripts\add_hard_disk.ps1</file>
            </setupScript>
            <testScript>testscripts/stor_scp_files.ps1</testScript>
            <files>remote-scripts/utils.sh</files>
            <files>remote-scripts/stor_scp_big_files.sh</files>
            <testParams>
                <param>DiskType=IDE</param>
                <param>StorageFormat=Thin</param>
                <param>CapacityGB=10</param>
                <param>nfs=10.73.198.145:/mnt/ceph-block/esx</param>
                <param>TC_COVERED=RHEL-34931,RHEL7-50911</param>
            </testParams>
            <cleanupScript>
                <file>SetupScripts\shutdown_guest_B.ps1</file>
                <file>SetupScripts\remove_hard_disk.ps1</file>
            </cleanupScript>
            <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
            <timeout>9000</timeout>
            <onError>Continue</onError>
            <noReboot>False</noReboot>
        </test>
.Parameter vmName
    Name of the VM to add disk.

.Parameter hvServer
    Name of the ESXi server hosting the VM.

.Parameter testParams
    Test data for this test case
#>

param([String] $vmName, [String] $hvServer, [String] $testParams)
#
# Checking the input arguments
#
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

#
# Display the test parameters so they are captured in the log file
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
if (-not $vmObj) {
    Write-Host -F Red "ERROR: Unable to Get-VM with $vmName"
    Write-Output "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
    return $Aborted
}


# Get another VM by change Name
$VMBName = $vmObj.Name.Split('-')
$VMBName[-1] = "B"
$VMBName = $VMBName -join "-"
$vmObjectB = Get-VMHost -Name $hvServer | Get-VM -Name $VMBName


# Start another VM
Start-VM -VM $vmObjectB -Confirm:$false -RunAsync:$true -ErrorAction SilentlyContinue
if (-not $?) {
    LogPrint "ERROR : Cannot start VM"
    DisconnectWithVIServer
    return $Aborted
}


# Get another VM IP addr
if ( -not (WaitForVMSSHReady $VMBName $hvServer $sshKey 300)) {
    LogPrint "ERROR : Cannot start SSH"
    DisconnectWithVIServer
    return $Aborted
}
LogPrint "INFO: Ready VM B SSH"


# Get Guest B IP addr
$ipv4B = GetIPv4 -vmName $VMBName -hvServer $hvServer
$vmObjectB = Get-VMHost -Name $hvServer | Get-VM -Name $


# Add ipv4B addr to constants.sh
$result = SendCommandToVM $ipv4 $sshKey "echo 'ipv4B=$ipv4B' >> ~/constants.sh"
if (-not $result[-1])
{
    LogPrint "ERROR: Cannot add ipv4B addr into constants.sh file"
	DisconnectWithVIServer
	return $Failed
}


# Will use a shell script to change VM's MTU = 9000 and DD a file > 5G and scp it
RunRemoteScript  "stor_scp_big_files.sh" | Write-Output -OutVariable result
if (-not $result[-1])
{
	LogPrint "FAIL: Failed to execute stor_scp_big_files.sh in VM"
	DisconnectWithVIServer
	return $Failed
}
else
{
    LogPrint "PASS: Execute stor_scp_big_files script in VM successfully, and power off the VM B"
    $retVal = $Passed
}


DisconnectWithVIServer
return $retVal
