###############################################################################
##
## Description:
##  Add and remove scsi disk multiple times in the VM
##
## Revision:
##  v1.0.0 - ruqin - 7/12/2018 - Build the script
##
###############################################################################

<#
.Synopsis
    Add and remove scsi disk mltiple times to make sure system doesn't have call trace.

.Description
        <test>
            <testName>stor_add_remove_multi_scsi</testName>
            <testID>ESX-Stor-012</testID>
            <testScript>testscripts\stor_add_remove_multi_scsi.ps1</testScript>
            <cleanupScript>SetupScripts\remove_hard_disk.ps1</cleanupScript>
            <testParams>
                <param>TC_COVERED=RHEL7-80195</param>
            </testParams>
            <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
            <timeout>600</timeout>
            <onError>Continue</onError>
            <noReboot>False</noReboot>
        </test>

.Parameter vmName
    Name of the test VM.

.Parameter testParams
    Semicolon separated list of test parameters.
#>


param([String] $vmName, [String] $hvServer, [String] $testParams)


#
# Checking the input arguments
#
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


#
# Output test parameters so they are captured in log file
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
        default {}
    }
}


#
# Check all parameters are valid
#
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


# Get the Guest version
$DISTRO = GetLinuxDistro ${ipv4} ${sshKey}
Write-Host -F Red "DEBUG: DISTRO: $DISTRO"
Write-Output "DEBUG: DISTRO: $DISTRO"
if (-not $DISTRO) {
    Write-Host -F Red "ERROR: Guest OS version is NULL"
    Write-Output "ERROR: Guest OS version is NULL"
    DisconnectWithVIServer
    return $Aborted
}
Write-Host -F Red "INFO: Guest OS version is $DISTRO"
Write-Output "INFO: Guest OS version is $DISTRO"


# Different Guest DISTRO, different modules
if ($DISTRO -ne "RedHat7" -and $DISTRO -ne "RedHat8") {
    Write-Host -F Red "ERROR: Guest OS ($DISTRO) isn't supported, MUST UPDATE in Framework / XML / Script"
    Write-Output "ERROR: Guest OS ($DISTRO) isn't supported, MUST UPDATE in Framework / XML / Script"
    DisconnectWithVIServer
    return $Skipped
}

# add multiple disks 10 times
for ($i = 1; $i -le 10; $i++) {
    $hd_num = Get-Random -Minimum 1 -Maximum 5
    for ($j = 1; $j -le $hd_num; $j++) {
        # Add Disk with size 5 to 10
        $hd_size = Get-Random -Minimum 5 -Maximum 10
        Write-Host -F Red "Info : Add $hd_nim disk(s) with size $hd_size GB to the VM $vmName"
        Write-Output "Info : Add $hd_nim disk(s) with size $hd_size GB to the VM $vmName"
        New-HardDisk -CapacityGB $hd_size -VM $vmObj -StorageFormat "Thin" -ErrorAction SilentlyContinue
        if (-not $?) {
            Write-Host -F Red "Error : Cannot add new hard disk to the VM $vmName"
            Write-Output "Error : Cannot add new hard disk to the VM $vmName"
            DisconnectWithVIServer
            return $Failed
        }
        Start-Sleep -Seconds 1
    }
    # Check System dmesg
    $Command = "dmesg | grep -i `"Call Trace`" | wc -l"
    $Error_Num = [int] (bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command)
    if ($Error_Num -ne 0) {
        Write-Host -F Red "Error : New disks have error Call Trace in $vmName"
        Write-Output "Error : New disks have error Call Trace in $vmName"
        DisconnectWithVIServer
        return $Failed
    }

    #Clean up new added disk and ready for next round
    Start-Sleep -Seconds 2
    $sysDisk = "Hard disk 1"
    if ( -not (CleanUpDisk -vmName $vmName -hvServer $hvServer -sysDisk $sysDisk)) {
        Write-Host -F Red "Error : Clean up failed in $vmName"
        Write-Output "Error : Clean up failed in $vmName"
        DisconnectWithVIServer
        return $Failed
    }
}
$retVal = $Passed

DisconnectWithVIServer
return $retVal