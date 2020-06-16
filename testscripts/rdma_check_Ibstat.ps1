########################################################################################
## Description:
##  Boot a Guest with RDMA NIC and check the IB stata.
##
## Revision:
##  v1.0.0 - ldu - 08/23/2018 - Build the script.
##  v1.1.0 - boyang - 10/16.2019 - Skip test when host hardware hasn't RDMA NIC.
########################################################################################


<#
.Synopsis
    Boot a Guest with RDMA NIC and check the IB stata.
.Description
       <test>
            <testName>rdma_check_Ibstat</testName>
            <testID>ESX-RDMA-005</testID>
            <setupScript>
                <file>setupscripts\add_pvrdma.ps1</file>
            </setupScript>
            <testScript>testscripts\rdma_check_Ibstat.ps1</testScript>
            <testParams>
                <param>TC_COVERED=RHEL6-49155,RHEL-111208</param>
            </testParams>
            <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
            <timeout>240</timeout>
            <onError>Continue</onError>
            <noReboot>False</noReboot>
        </test>
.Parameter vmName
    Name of the test VM.
.Parameter testParams
    Semicolon separated list of test parameters.
#>


param([String] $vmName, [String] $hvServer, [String] $testParams)
# Checking the input arguments
if (-not $vmName) {
    "Error: VM name cannot be null!"
    exit 100
}

if (-not $hvServer) {
    "Error: hvServer cannot be null!"
    exit 100
}

if (-not $testParams) {
    Throw "Error: No test parameters specified"
}


# Output test parameters so they are captured in log file
"TestParams : '${testParams}'"


# Parse the test parameters
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
        default {}
    }
}


# Check all parameters are valid
if (-not $rootDir) {
    "Warn : no rootdir was specified"
}
else {
    if ( (Test-Path -Path "${rootDir}") ) {
        Set-Location $rootDir
    }
    else {
        "Warn : rootdir '${rootDir}' does not exist"
    }
}

if ($null -eq $sshKey) {
    "FAIL: Test parameter sshKey was not specified"
    return $False
}

if ($null -eq $ipv4) {
    "FAIL: Test parameter ipv4 was not specified"
    return $False
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


$skip = SkipTestInHost $hvServer "6.0.0"
if($skip)
{
    return $Skipped
}


$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj) {
    LogPrint "ERROR: Unable to Get-VM with ${vmName}."
    DisconnectWithVIServer
    return $Aborted
}


# Get the Guest version
$DISTRO = GetLinuxDistro ${ipv4} ${sshKey}
LogPrint "DEBUG: DISTRO: ${DISTRO}."
if (-not $DISTRO) {
    LogPrint "ERROR: Guest OS version is NULL"
    DisconnectWithVIServer
    return $Aborted
}


# Different Guest DISTRO
if ($DISTRO -ne "RedHat7" -and $DISTRO -ne "RedHat8" -and $DISTRO -ne "RedHat6") {
    LogPrint "ERROR: Guest OS ($DISTRO) isn't supported, MUST UPDATE in Framework / XML / Script"
    DisconnectWithVIServer
    return $Skipped
}


# Get new add RDMA NIC.
$nics = FindAllNewAddNIC $ipv4 $sshKey
LogPrint "DEBUG: nics: ${nics}."
if ($null -eq $nics[-1]) {
    LogPrint "ERROR: Cannot find new add SR-IOV NIC." 
    DisconnectWithVIServer
    return $Failed
}
else {
    $rdmaNIC = $nics[-1]
	LogPrint "INFO: New NIC: $rdmaNIC."
}


# Assign a new IP addr to new RDMA nic
$IPAddr = "172.31.1." + (Get-Random -Maximum 254 -Minimum 2)
LogPrint "DEBUG: IPAddr: ${IPAddr}."
if (-not (ConfigIPforNewDevice $ipv4 $sshKey $rdmaNIC ($IPAddr + "/24"))) {
    LogPrint "ERROR : Config IP Failed."
    DisconnectWithVIServer
    return $Failed
}


# Install required packages
$sts = SendCommandToVM $ipv4 $sshKey "yum install -y rdma-core infiniband-diags"
LogPrint "DEBUG: sts: ${sts}."
if (-not $sts) {
    LogPrint "ERROR : YUM cannot install required packages."
    DisconnectWithVIServer
    return $Failed
}


# Load mod ib_umad for ibstat check.
$Command = "modprobe ib_umad"
$modules = Write-Output y | bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command
LogPrint "DEBUG: modules: ${modules}."


# Make sure the ibstat is active.
$Command = "ibstat | grep Active | wc -l"
$ibstat = [int] (Write-Output y | bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command)
LogPrint "DEBUG: ibstat: ${ibstat}."
if ($ibstat -eq 0) {
    LogPrint "ERROR: The ibstat is not correct."
    DisconnectWithVIServer
    return $Failed
}
else {
    LogPrint "INFO: The ibstat is correct."
    $retVal = $Passed
}


DisconnectWithVIServer
return $retVal
