###############################################################################
##
## Description:
##  Test Hot add memory from low size to high size
##
## Revision:
##  v1.0.0 - ruqin - 7/20/2018 - Build the script
##
###############################################################################

<#
.Synopsis
    Hot add memory from a low size to high size (such as from 8GB to 80GB)

.Description
        <test>
            <testName>bl_add_memory_low_to_high</testName>
            <testID>ESX-BL-002</testID>
            <setupScript>
                <file>SetupScripts\change_memory.ps1</file>
                <file>SetupScripts\enable_hot_memory.ps1</file>
            </setupScript>
            <testScript>testscripts\bl_add_memory_low_to_high.ps1</testScript>
            <testParams>
                <param>VMMemory=8GB</param>
                <param>TC_COVERED=RHEL7-80171</param>
            </testParams>
            <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
            <timeout>400</timeout>
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
    LogPrint "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
    return $Aborted
}


# Get the Guest version
$DISTRO = GetLinuxDistro ${ipv4} ${sshKey}
LogPrint "DEBUG: DISTRO: $DISTRO"
if (-not $DISTRO) {
    LogPrint "ERROR: Guest OS version is NULL"
    DisconnectWithVIServer
    return $Aborted
}
LogPrint "INFO: Guest OS version is $DISTRO"


# Different Guest DISTRO
if ($DISTRO -ne "RedHat7" -and $DISTRO -ne "RedHat8" -and $DISTRO -ne "RedHat6") {
    LogPrint "ERROR: Guest OS ($DISTRO) isn't supported, MUST UPDATE in Framework / XML / Script"
    DisconnectWithVIServer
    return $Skipped
}


# check system dmesg
$command = "dmesg | grep -i `"call trace`" | wc -l"
$error_num = [int] (bin\plink.exe -i ssh\${sshkey} root@${ipv4} $command)
if ($error_num -ne 0) {
    LogPrint "ERROR : hot add memory has error call trace in $vmname"
    disconnectwithviserver
    return $Failed
}

# Hot Add
$dst_mem = $vmObj.MemoryGB * 10 
$status = Set-VM $vmObj -MemoryGB $dst_mem -Confirm:$false
if (-not $?) {
    LogPrint "ERROR : Failed Hot Add memeory to the VM $vmName"
    DisconnectWithVIServer
    return $Failed
}
LogPrint "Info :Change memory for $vmName to $dst_mem"


# Wait seconds for Hot Add memory
Start-Sleep -Seconds 6


# check system dmesg again
$command = "dmesg | grep -i `"call trace`" | wc -l"
$error_num = [int] (bin\plink.exe -i ssh\${sshkey} root@${ipv4} $command)
if ($error_num -ne 0) {
    LogPrint "ERROR : hot add memory has error call trace in $vmname"
    disconnectwithviserver
    return $Failed
}

# Now Total Memory
$Command = "free -m | awk '{print `$2}' | awk 'NR==2'"
$Total_Mem = [int] (bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command)

LogPrint "INFO :current memory is $total_mem"

$dst_mem = $dst_mem * 1024

# Check new Add memory range
if ( $total_mem -le ($dst_mem * 0.95) -or $total_mem -gt ($dst_mem * 1.05)) {
    LogPrint  "ERROR : new hot add memory not fit $dst_mem mb in $vmname"
    disconnectwithviserver
    return $failed
} else {
    $retVal = $Passed
}


DisconnectWithVIServer
return $retVal
