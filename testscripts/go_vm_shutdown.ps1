###############################################################################
##
## Description:
##   shutdown vm, in the guest, execute command: shutdown
##   Return passed, case is passed; return failed, case is failed
##
###############################################################################
##
## Revision:
## v1.0 - hhei - 2/21/2017 - shutdown vm.
##
###############################################################################

<#
.Synopsis
    reboot in vm.

.Description
    Check reboot in vm.

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

$Result = $Failed
$vmOut = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmOut)
{
    Write-Error -Message "go_vm_shutdown: Unable to create VM object for VM $vmName" -Category ObjectNotFound -ErrorAction SilentlyContinue
}
else
{
    $DISTRO = ""
    $command = ""
    $DISTRO = GetLinuxDistro ${ipv4} ${sshKey}
    if ( -not $DISTRO )
    {
        "Error : Guest OS version is NULL"
        $Result = $Failed
    }
    elseif ( $DISTRO -eq "RedHat6" )
    {
        $command = "poweroff"
        $Result = $Passed
    }
    elseif ( $DISTRO -eq "RedHat7" )
    {
        $command = "systemctl poweroff"
        $Result = $Passed
    }
    else
    {
        "Error : Guest OS version is $DISTRO"
        $Result = $Failed
    }

    "Info : Guest OS version is $DISTRO"

    if ( $Result -eq $Passed )
    {
        "Info : Poweroff $vmName now"
        bin\plink.exe -i ssh\${sshKey} root@${ipv4} "$command"
        Start-Sleep -seconds 5

        $timeout = 300
        while ( $timeout -gt 0 )
        {
            $vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
            if ($vmObj.PowerState -ne "PoweredOff")
            {
                Start-Sleep -seconds 1
                $timeout -= 1
            }
            else
            {
                $Result = $Passed
                break
            }
        }

    }

}

DisconnectWithVIServer
return $result
