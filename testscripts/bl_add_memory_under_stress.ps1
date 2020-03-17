########################################################################################
## Description:
##  Test Hot add memory under memory stress
##
## Revision:
##  v1.0.0 - ruqin - 7/16/2018 - Build the script
########################################################################################


<#
.Synopsis
    Hot add memory during memory stress

.Description
        <test>
            <testName>bl_add_memory_under_stress</testName>
            <testID>ESX-BL-001</testID>
            <setupScript>
                <file>SetupScripts\change_memory.ps1</file>
                <file>SetupScripts\enable_hot_memory.ps1</file>
            </setupScript>
            <testScript>testscripts\bl_add_memory_under_stress.ps1</testScript>
            <testParams>
                <param>VMMemory=4GB</param>
                <param>TC_COVERED=RHEL7-50938</param>
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


# Checking the input arguments
param([String] $vmName, [String] $hvServer, [String] $testParams)
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


$url = "http://download.eng.bos.redhat.com/brewroot/packages/stress/0.18.8/3.4.el7eng/x86_64/stress-0.18.8-3.4.el7eng.x86_64.rpm"
if ($DISTRO -eq "RedHat6") {
    $url = "http://download.eng.bos.redhat.com/brewroot/vol/rhel-6/packages/stress/0.18.8/2.4.el6eng/x86_64/stress-0.18.8-2.4.el6eng.x86_64.rpm"
}


# Install Stress Tools
$command = "yum localinstall $url -y"
$status = SendCommandToVM $ipv4 $sshkey $command
if ( -not $status) {
    LogPrint "ERROR: YUM failed in $vmName, may need to update stress tool URL"
    DisconnectWithVIServer
    return $Failed
}


# Configure udev file
$command = "echo 'SUBSYSTEM==`"memory`", ACTION==`"add`", ATTR{state}=`"online`" ATTR{state}==`"offline`"' > /etc/udev/rules.d/99-hv-balloon.rules"
$status = SendCommandToVM $ipv4 $sshkey $command
if ( -not $status) {
    LogPrint "ERROR: Cannot finish system Hot add configure in $vmName"
    DisconnectWithVIServer
    return $Failed
}


# Begin to stress memory
$Command = "stress --vm 45 --vm-keep --vm-bytes 100M --timeout 60s"


# Cannot use NoNewWindow Here because this will cause no ExitCode We could use WindowStyle Hidden instead
$Process = Start-Process .\bin\plink.exe -ArgumentList "-i ssh\${sshKey} root@${ipv4} ${Command}" -PassThru -WindowStyle Hidden


# Wait seconds for Hot Add memory
Start-Sleep -Seconds 6


# Hot Add
$status = Set-VM $vmObj -MemoryGB ($vmObj.MemoryGB * 2) -Confirm:$false
LogPrint "DEBUG: status: ${status}."
if (-not $?) {
    LogPrint "ERROR: Failed Hot Add memeory to the VM $vmName"
    DisconnectWithVIServer
    return $Failed
}


# Wait seconds for Hot Add memory (This value may need to change because case often fails here)
Start-Sleep -Seconds 30


# Clean Cache
$Command = "sync; echo 3 > /proc/sys/vm/drop_caches"
$status = SendCommandToVM $ipv4 $sshkey $command
if ( -not $status) {
    LogPrint "ERROR: Clean Cache Failed in $vmName"
    DisconnectWithVIServer
    return $Failed
}


# Now Total Memory
$Command = "free -m | awk '{print `$2}' | awk 'NR==2'"
$Total_Mem = [int] (bin\plink.exe -i ssh\${sshKey} root@${ipv4} $Command)
LogPrint "DEBUG: Total_Mem: $Total_Mem"


$dst_mem = $vmobj.memorymb * 2
if ( $total_mem -le ($dst_mem * 0.9) -or $total_mem -gt ($dst_mem * 1.1)) {
    LogPrint  "ERROR: New hot add memory not fit $dst_mem mb in $vmname"
    disconnectwithviserver
    return $failed
}


# check system dmesg
if (-not (CheckCallTrace $ipv4 $sshKey)) {
    LogPrint "ERROR: hot add memory has error call trace in $vmname"
    disconnectwithviserver
    return $Failed
}
else {
    $retVal = $Passed
}


# Wait seconds for Hot Add memory
Start-Sleep -Seconds 6


$Process.WaitForExit()
$exit = [int]$Process.ExitCode


# Wait seconds for Hot Add memory
Start-Sleep -Seconds 6


# Check Stress return value
if ($exit -ne 0) {
    LogPrint "ERROR: Stress Failed in $vmName With Command $Command and ExitCode $status"
    DisconnectWithVIServer
    return $Aborted
}


DisconnectWithVIServer
return $retVal
