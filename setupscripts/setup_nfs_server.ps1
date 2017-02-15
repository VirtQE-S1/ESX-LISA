###############################################################################
##
## Description:
##   This script will set up nfs server on assistant VM
##
###############################################################################
##
## Revision:
## v1.0 - xuli - 02/08/2017 - Draft script for seting up nfs server.
##
###############################################################################
<#
.Synopsis
    This script will set up nfs server for assistant VM
.Description
    The script will set up nfs server for assistant VM, the assistant VM name gets by replacing current VM name "A" to "B", nfs path is /nfs_share.
    The .xml entry to specify this startup script would be:
    <setupScript>SetupScripts\setup_nfs_server.ps1</setupScript>

.Parameter vmName
    Name of the VM to add disk.

.Parameter hvServer
    Name of the ESXi server hosting the VM.

.Parameter testParams
    Test data for this test case

.Example
    setupScripts\setup_nfs_server
#>
param ([String] $vmName, [String] $hvServer, [String] $testParams)

function SetupNFSServer([String] $ipv4, [String] $sshkey)
{
    $sta = SendCommandToVM $ipv4 $sshkey "mkdir -p /nfs_share"
    if (-not $sta)
    {
        Throw "Error : Cannot create /nfs_share path "
        return $false
    }

    $sta = SendCommandToVM $ipv4 $sshkey "echo '/nfs_share    *(rw,nohide,no_root_squash,sync)' > /etc/exports"
    if (-not $sta)
    {
        Throw "Error : Cannot update /etc/export on VM $vmName"
        return $false
    }

    $sta = SendCommandToVM $ipv4 $sshkey "service rpcbind restart"
    if (-not $sta)
    {
        Throw "Error : restart rpcbind on VM $vmName"
        return $false
    }

    $sta = SendCommandToVM $ipv4 $sshkey "service nfs restart"
    if (-not $sta)
    {
        Throw "Error : restart rpcbind on VM $vmName"
        return $false
    }
    return $true
}

############################################################################
#
# Main entry point for script
#
############################################################################
#
# Check input arguments
#
if ($vmName -eq $null -or $vmName.Length -eq 0)
{
    "Error: VM name is null"
    return $false
}

if ($testParams -eq $null -or $testParams.Length -lt 3)
{
    "The script change_cpu.ps1 requires the VCPU test parameter"
    return $false
}

#
# Source the tcutils.ps1 file
#
. .\setupscripts\tcutils.ps1
#
# Parse the testParams string
#
$params = $testParams.TrimEnd(";").Split(";")
foreach ($p in $params)
{
    $fields = $p.Split("=")
    switch ($fields[0].Trim())
    {
    "sshKey"       { $sshKey = $fields[1].Trim() }
    "ipv4"         { $ipv4 = $fields[1].Trim() }
    default        {}
    }
}

$vmNameB = $vmName -replace "A$","B"
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmNameB
if (-not $vmObj)
{
    "Error: setup_nfs_server.ps1 Unable to get assistant VM object for VM $vmNameB"
    return $false
}

$snapsOut = Get-Snapshot -VM $vmObj

Set-VM -VM $vmObj -Snapshot $snapsOut -Confirm:$False
if (-not $?)
{
    "Error: Failed to set snapshot for VM $vmNameB"
    return $false
}
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmNameB

if ( $vmObj.PowerState -ne "PoweredOn")
{
    Start-VM -VM $vmObj -Confirm:$false

    $timeout = 240
    while ($timeout -gt 0)
    {
        $v = Get-VMHost -Name $hvServer | Get-VM -Name $vmNameB
        if ($v -and $v.PowerState -eq "PoweredOn")
        {
            #GetIPv4([String] $vmName, [String] $hvServer)
            $ipv4B = GetIPv4 $vmNameB $hvServer
            if ($ipv4B -ne $null)
            {
                break
            }
        }
        start-sleep -seconds 1
        $timeout -= 1
    }
}

$sta = SetupNFSServer $ipv4B $sshkey
if (-not $($sta[-1]))
{
    "Error: Failed to set NFS on assistant VM $vmNameB"
    return $false
}
return $true
