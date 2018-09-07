###############################################################################
##
## Description:
##   Change CPU of vm
##
###############################################################################
##
## Revision:
## v1.0 - hhei - 1/4/2017 - Change CPU of vm
## v1.1 - hhei - 1/10/2017 - Update log info
##
###############################################################################
<#
.Synopsis
    Modify the number of CPUs a VM has.

.Descriptioin
    Modify the number of CPUs the VM has.

.Parameter vmName
    Name of the VM to modify.

.Parameter hvServer
    Name of the ESXi server hosting the VM.

.Parameter testParams
    A semicolon separated list of test parameters.

.Example
    .\change_cpu.ps1 "testVM" "localhost" "VCPU=2"
#>

param([string] $vmName, [string] $hvServer, [string] $testParams)

$retVal = $false
#
# Check input arguments
#
if ($vmName -eq $null)
{
    "Error: VM name is null"
    return $retVal
}

if ($hvServer -eq $null)
{
    "Error: hvServer is null"
    return $retVal
}

if ($testParams -eq $null -or $testParams.Length -lt 3)
{
    "The script change_cpu.ps1 requires the VCPU test parameter"
    return $retVal
}

#
# Find the testParams we require.  Complain if not found
#
$numCPUs = 0

$params = $testParams.Split(";")
foreach ($p in $params)
{
    $fields = $p.Split("=")

    switch ($fields[0].Trim())
    {
    "VCPU"         { $numCPUs = [int]$fields[1].Trim() }
    default        {}
    }

}
#
# do a sanity check on the value provided in the testParams
#
$maxCPUs = 0
$procs = Get-VMHost -Name $hvServer | Select NumCpu
if ($procs)
{
    $maxCPUs = $procs.NumCpu
}

if ($numCPUs -lt 1 -or $numCPUs -gt $maxCPUs)
{
    "Error: Incorrect VCPU value: $numCPUs (max CPUs = $maxCPUs)"
    return $retVal
}

$vm = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vm)
{
    "Error: change_cpu: Unable to create VM object for VM $vmName"
    return $retVal
}
#
# Update VCPU on the VM, this is the total vcpu number, check number of cores per socket
#
if ($numCPUs -ne 0)
{
    Set-VM -VM $vm -NumCpu $numCPUs -Confirm:$False
    if ($? -eq "True")
    {
        "Info : CPU count updated to $numCPUs"
        $retVal = $true
    }
    else
    {
        write-host "Error: Unable to update CPU num"
        return $retVal
    }
}
else {
    "Error : VCPU test parameter not found in testParams"
}


return $retVal
