########################################################################################
## Description:
##   Change CPU number of a vm.
##
## Revision:
##  v1.0.0 - hhei - 01/04/2017 - Change CPU of a vm.
##  v1.1.0 - hhei - 01/10/2017 - Update log info.
########################################################################################


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
if ($vmName -eq $null)
{
    "ERROR: VM name is null."
    return $retVal
}

if ($hvServer -eq $null)
{
    "ERROR: hvServer is null."
    return $retVal
}

if ($testParams -eq $null -or $testParams.Length -lt 3)
{
    "ERROR: change_cpu.ps1 requires the VCPU test parameter."
    return $retVal
}


# Find the testParams we require.  Complain if not found.
$retVal = $false
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


# Do a sanity check on the value provided in the testParams
$maxCPUs = 0
$procs = Get-VMHost -Name $hvServer | Select NumCpu
if ($procs)
{
    $maxCPUs = $procs.NumCpu
}

if ($numCPUs -lt 1 -or $numCPUs -gt $maxCPUs)
{
    "ERROR: Incorrect VCPU value: $numCPUs (max CPUs = $maxCPUs)"
    return $retVal
}

$vm = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vm)
{
    "ERROR: change_cpu: Unable to create VM object for VM ${vmName}."
    return $retVal
}

# Update VCPU on the VM, this is the total vcpu number, check number of cores per socket
if ($numCPUs -ne 0)
{
    Set-VM -VM $vm -NumCpu $numCPUs -Confirm:$False
    if ($? -eq "True")
    {
        "INFO: CPU count updated to ${numCPUs}."
        $retVal = $true
    }
    else
    {
        write-host "ERROR: Unable to update CPU num."
        return $retVal
    }
}
else {
    "ERROR: VCPU test parameter not found in testParams."
}


return $retVal
