###############################################################################
##
## Description:
##   Check vm has specified NIC, include: Vmxnet3, e1000e, e1000
##   If yes, do nothing; if no, add one
##
###############################################################################
##
## Revision:
## v1.0 - hhei - 1/23/2017 - Setup scripts.
##
###############################################################################

<#
.Synopsis
    Check vm has specified NIC, include: Vmxnet3, e1000e, e1000

.Description
    Check vm has specified NIC, include: Vmxnet3, e1000e, e1000

.Parameter vmName
    Name of the test VM.

.Parameter testParams
    Semicolon separated list of test parameters.
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
    "nic_type"     { $nic_type = $fields[1].Trim() }
    default        {}
    }
}

###############################################################################
#
# Main script
#
###############################################################################
$network_name = "VM Network"

if (-not $nic_type)
{
    "Error: No nic_type specified"
    return $false
}

$vmOut = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmOut)
{
    "Error : Unable to get VM object for VM $vmName"
    return $false
}

if ((Get-NetworkAdapter -VM $vmOut).Type -contains $nic_type)
{
    "Info : VM $vmName already has $nic_type NIC"
    return $true
}
else
{
    "Info : VM $vmName does not have $nic_type NIC, need to add one"
     New-NetworkAdapter -VM $vmOut -Type $nic_type -NetworkName "$network_name" -StartConnected
     if ( $? -ne $true )
     {
         "Error : New $nic_type to $vmName false"
         return $false
     }
     else
     {
         "Info : New $nic_type to $vmName successfully"
         return $true
     }
}
