###############################################################################
##
## Description:
##   This script will mount nfs path from assistant VM to local path.
##
###############################################################################
##
## Revision:
## v1.0 - xuli - 02/08/2017 - Draft script for mount nfs server to local path.
##
###############################################################################
<#
.Synopsis
    This script will mount nfs server to local path.
.Description
    The script will set up nfs server for assistant VM, the assistant VM name gets by replacing current VM name "A" to "B", nfs path is /nfs_share, dd file under mount point, then umount path.
    unmount path.
    The .xml entry to specify this startup script would be:

    <test>
            <testName>stor_vhdx_mount_nfs_server</testName>
            <testID>ESX-STOR-002</testID>
            <testScript>testscripts\stor_nfs_client.ps1</testScript>
            <files>
                remote-scripts/utils.sh, remote-scripts/stor_utils.sh
            </files>
            <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
            <timeout>900</timeout>
            <testparams>
                <param>TC_COVERED=RHEL6-34925,RHEL7-50903</param>
            </testparams>
            <onError>Continue</onError>
        </test>
.Parameter vmName
    Name of the VM to add disk.

.Parameter hvServer
    Name of the ESXi server hosting the VM.

.Parameter testParams
    Test data for this test case

.Example
    setupScripts\stor_nfs_client
#>


param([String] $vmName, [String] $hvServer, [String] $testParams)
#
# Checking the input arguments
#
if (-not $vmName) {
    "Error: VM name cannot be null!"
    exit 1
}

if (-not $hvServer) {
    "Error: hvServer cannot be null!"
    exit 1
}

if (-not $testParams) {
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
foreach ($p in $params) {
    $fields = $p.Split("=")
    switch ($fields[0].Trim()) {
        "sshKey" { $sshKey = $fields[1].Trim() }
        "rootDir" { $rootDir = $fields[1].Trim() }
        "ipv4" { $ipv4 = $fields[1].Trim() }
        "TestLogDir" { $testLogDir = $fields[1].Trim() }
        default {}
    }
}

if (-not $rootDir) {
    "Warn : no rootdir was specified"
}
else {
    if ( (Test-Path -Path "${rootDir}") ) {
        cd $rootDir
    }
    else {
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


$result = $Failed
$sts = SendCommandToVM $ipv4 $sshkey "echo NFS_Path=10.73.196.210:/mnt/MainVolume/nfs-smb/esx/nfs_case >> ~/constants.sh"
if (-not $sts) {
    LogPrint "Error : Cannot send command to vm for setting NFS_Path"
}


$remoteScript = "stor_lis_nfs.sh"
$sta = RunRemoteScript $remoteScript
if (-not $($sta[-1])) {
    LogPrint "Error: Failed to run for $remoteScript"
}
else {
    $result = $Passed
}
LogPrint "Info : stor_nfs_client script completed"


DisconnectWithVIServer
return $result
