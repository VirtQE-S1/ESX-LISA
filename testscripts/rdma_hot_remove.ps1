########################################################################################
## Description:
##  Boot a Guest with RDMA NIC and remove it after boot.
##
## Revision:
##  v1.0.0 - ldu - 9/07/2018 - Build the script.
##  v1.1.0 - boyang - 10/16.2019 - Skip test when host hardware hasn't RDMA NIC.
########################################################################################


<#
.Synopsis
    Check RDMA NIC after boot guest and hot remove it

.Description
       <test>
            <testName>rdma_hot_remove</testName>
            <testID>ESX-RDMA-006</testID>
            <setupScript>
                <file>setupscripts\add_pvrdma.ps1</file>
            </setupScript>
            <testScript>testscripts\rdma_hot_remove.ps1</testScript>
            <testParams>
                <param>TC_COVERED=RHEL6-49158,RHEL-111935</param>
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


# Checking the input arguments.
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


$skip = SkipTestInHost $hvServer "6.0.0","6.5.0","6.7.0"
if($skip)
{
    return $Skipped
}


$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj) {
    LogPrint "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
    return $Aborted
}

# Get pci status
$Command = "lspci | grep -i infiniband"
$pciInfo = Write-Output y | bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command
if ( $pciInfo -notlike "*Infiniband controller: VMware Paravirtual RDMA controller*") {
    LogPrint "ERROR : Cannot get pvRDMA info from guest"
    DisconnectWithVIServer
    return $Aborted
}

$nics = Get-NetworkAdapter -VM $vmObj
foreach ($nic in $nics)
{
    Write-Host -F red nic is ${nic} , nic.NetworkName is ${nic}.NetworkName
    if (${nic}.NetworkName -eq "DPortGroup")
    {
        $result = Remove-NetworkAdapter -NetworkAdapter $nic -Confirm:$false
        if ($? -eq 0)
        {
            Write-Output "PASS: Remove-NetworkAdapter RDMA well"
            $retVal = $Passed
        }
        else
        {
            Write-Host -F red nic.NetworkName is ${nic}.NetworkName
            write-output "FAIL: Remove-NetworkAdapter RDMA Failed"
        }
    }
}

DisconnectWithVIServer
return $retVal