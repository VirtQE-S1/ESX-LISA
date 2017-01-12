###############################################################################
##
## Fork from github.com/LIS/lis-test, make it work with VMware ESX testing
##
## All rights reserved.
## Licensed under the Apache License, Version 2.0 (the ""License"");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##     http://www.apache.org/licenses/LICENSE-2.0
##
## THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS
## OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
## ANY IMPLIED WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR
## PURPOSE, MERCHANTABLITY OR NON-INFRINGEMENT.
##
## See the Apache Version 2.0 License for specific language governing
## permissions and limitations under the License.
##
###############################################################################
##
## Revision:
## v1.0 - hhei - 1/4/2017 - Change memory of vm
##
###############################################################################

###############################################################################
##
## Description:
##   Change memory of vm
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
    Name of the Hyper-V server hosting the VM.

.Parameter testParams
    A semicolon separated list of test parameters.

.Example
    .\change_memory.ps1 "testVM" "localhost" "VMMemory=2GB"
#>

param([string] $vmName, [string] $hvServer, [string] $testParams)
########################################################################
#
# ConvertStringToDecimal()
#
########################################################################
function ConvertStringToDecimal([string] $str)
{
    $uint64Size = $null

    #
    # Make sure we received a string to convert
    #
    if (-not $str)
    {
        Write-Error -Message "ConvertStringToDecimal() - input string is null" -Category InvalidArgument -ErrorAction SilentlyContinue
        return $null
    }

    if ($str.EndsWith("GB"))
    {
        $num = $str.Replace("GB","")
        $uint64Size = ([Convert]::ToDecimal($num))
    }
    elseif ($str.EndsWith("TB"))
    {
        $num = $str.Replace("TB","")
        $uint64Size = ([Convert]::ToDecimal($num)) * 1024
    }
    else
    {
        Write-Error -Message "Invalid newSize parameter: ${str}" -Category InvalidArgument -ErrorAction SilentlyContinue
        return $null
    }

    return $uint64Size
}

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

if (-not $testParams -or $testParams.Length -lt 3)
{
    Throw "Error: No test parameters specified"
}

#
# Find the testParams we require.  Complain if not found
#
$retVal = $False
$mem = $null

$params = $testParams.Split(";")
foreach ($p in $params)
{
    $fields = $p.Split("=")
    switch ($fields[0].Trim())
    {
    "VMMemory"       { $mem = $fields[1].Trim() }
    }
}

#
# do a sanity check on the value provided in the testParams
#
$maxMem = 0
$procs = Get-VMHost -Name $hvServer | Select MemoryTotalGB
if ($procs)
{
    $maxMem = $procs.MemoryTotalGB
}
$staticMemory = ConvertStringToDecimal $mem.ToUpper()
if ($staticMemory -lt 1 -or $staticMemory -gt $maxMem)
{
    "Error: Incorrect VMMemory value: $staticMemory (max VMMemory = $maxMem)"
    return $retVal
}

$vm = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vm)
{
    "Error: change_memory.ps1 Unable to create VM object for VM $vmName"
    return $retVal
}
#
# Update VMMemory on the VM
#
if ($staticMemory -ne $null)
{
    Set-VM $vm -MemoryGB $staticMemory -Confirm:$false
    if ($? -eq "True")
    {
        Write-output "Info : Memory updated to $mem"
        $retVal = $true
    }
    else
    {
        Write-output "Error : Unable to update memory $mem"
        return $retVal
    }
}
else {
    "Error : VMMemory test parameter not found in testParams"
}

return $retVal
