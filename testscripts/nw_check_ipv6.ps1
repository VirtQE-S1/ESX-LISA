########################################################################################
## Description:
##  Set IPV6 DHCP IP for Guest
## Revision:
##  v1.0.0 - xinhu - 09/27/2019 - Build the script
##  v1.1.0 - boyang - 03/05/2020 - Build the script
########################################################################################


<#
.Synopsis
    [network]Set IPV6 DHCP IP for Guest

.Description
    <test>
        <testName>nw_check_ipv6</testName>
        <testID>ESX-NW-023</testID>
        <testScript>testscripts/nw_check_ipv6.ps1</testScript>
        <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
        <timeout>360</timeout>
        <onError>Continue</onError>
        <noReboot>False</noReboot>
    </test>
    
.Parameter vmName
    Name of the test VM.

.Parameter hvServer
    Name of the VIServer hosting the VM.

.Parameter testParams
    Semicolon separated list of test parameters.
#>


# Checking the input arguments
param([String] $vmName, [String] $hvServer, [String] $testParams)
if (-not $vmName)
{
    "FAIL: VM name cannot be null!"
    exit
}

if (-not $hvServer)
{
    "FAIL: hvServer cannot be null!"
    exit
}

if (-not $testParams)
{
    Throw "FAIL: No test parameters specified"
}


# Output test parameters so they are captured in log file
"TestParams : '${testParams}'"


# Parse test parameters
$rootDir = $null
$sshKey = $null
$ipv4 = $null
$logdir = $null

$params = $testParams.Split(";")
foreach ($p in $params)
{
	$fields = $p.Split("=")
	switch ($fields[0].Trim())
	{
		"rootDir"		{ $rootDir = $fields[1].Trim() }
		"sshKey"		{ $sshKey = $fields[1].Trim() }
		"ipv4"			{ $ipv4 = $fields[1].Trim() }
		"TestLogDir"	{ $logdir = $fields[1].Trim()}
		default			{}
    }
}


# Check all parameters are valid
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

if ($null -eq $sshKey)
{
	"FAIL: Test parameter sshKey was not specified"
	return $False
}

if ($null -eq $ipv4)
{
	"FAIL: Test parameter ipv4 was not specified"
	return $False
}

if ($null -eq $logdir)
{
	"FAIL: Test parameter logdir was not specified"
	return $False
}


# Source tcutils.ps1
. .\setupscripts\tcutils.ps1
PowerCLIImport
ConnectToVIServer $env:ENVVISIPADDR `
                  $env:ENVVISUSERNAME `
                  $env:ENVVISPASSWORD `
                  $env:ENVVISPROTOCOL


########################################################################################
# Main Body
########################################################################################
$retVal1 = $False
$retVal2 = $False


# Function ping6 VM_B
function ping-VM(${sshKey},${ipv4},$choice,$IPv6_B,$packages)
{
	LogPrint "DEBUG: choice: ${choice}, IPv6_B: ${IPv6_B}, packages: ${packages}."
    $SwitchIPv6 = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "sysctl -w net.ipv6.conf.${NIC}.disable_ipv6=$choice; echo `$?"
    LogPrint "DEBUG: SwitchIPv6[-1]: $($SwitchIPv6[-1])."
    if ($SwitchIPv6[-1] -ne 0)
    {
        LogPrint "ERROR: Set disable ipv6 = $choice failed"
        return $False
    }

    # Wait for completing switch ipv6 
    Sleep -seconds 6

    $result = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ping6 $IPv6_B -c $packages;echo `$?"
    LogPrint "DEBUG: result: ${result}."
    return $result
}


# Get NIC name of VM_A
$NIC = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ls /sys/class/net/ | grep ^e[tn][hosp]"
LogPrint "INFO: Get NIC name - ${NIC}."
if ([String]::IsNullOrEmpty(${NIC}))
{
    LogPrint "ERROR: NIC name is null."
    DisconnectWithVIServer
    return $Aborted
}


# Get ipv6 addr of VM_B
$vmNameB = $vmName -creplace ("-A$"),"-B"
$vmB = Get-VMHost -Name $hvServer | Get-VM -Name $vmNameB
if (-not $vmB)
{
    Write-Error -Message "nw_ping.ps1: Unable to create VM object for VM $vmNameB" -Category ObjectNotFound -ErrorAction SilentlyContinue
    return $Aborted
}


LogPrint "INFO: Revert snapshot of ${vmNameB}."
$result = RevertSnapshotVM $vmNameB $hvServer
if ($result[-1] -ne $true)
{
    LogPrint "INFO: Revert snapshot of $vmNameB failed."
    DisconnectWithVIServer
    return $Aborted
}


# Start Guest
LogPrint "INFO: Powering on VM_B."
$on = Start-VM -VM $vmB -Confirm:$false -RunAsync:$true -ErrorAction SilentlyContinue


# Wait for VM_B start and gei ip address
LogPrint "INFO: Wait for SSH to confirm VM_B booting."
$ret = WaitForVMSSHReady $vmNameB $hvServer ${sshKey} 300
if ($ret -ne $true)
{
	LogPrint "ERROR: SSH failed."
    DisconnectWithVIServer
    return $Aborted
}


# Refresh status
$vmB = Get-VMHost -Name $hvServer | Get-VM -Name $vmNameB
$IPADDB = $vmB.Guest.IPAddress
LogPrint "DEBUG: IP address of VM_B: $IPADDB"


# Current version get ipv6 method, (fe80 IPV6 add are not valid to ping6)
if ($IPADDB[1].contains("fe80"))
{
    $IPv6_B = $IPADDB[2]
}
else
{
    $IPv6_B = $IPADDB[1]
}
LogPrint "DEBUG: IPv6_B: $IPv6_B"


# Disable ipv6 for VM_A
$packages = 4
$Disable = 1
$Disresult = ping-VM ${sshKey} ${ipv4} $Disable $IPv6_B $packages
LogPrint "DEBUG: Disresult: $Disresult"
if ($Disresult -eq $False) 
{
    LogPrint "ERROR: Set disable ipv6 failed."
}
elseif ($Disresult -eq 0) 
{
    LogPrint "ERROR: set disable ipv6, but sucess to ping6, $Disresult"
}
else 
{
    LogPrint "INFO: Set disable ipv6, and failed to ping6"
    $retVal1 = $Passed
}

 
# Enable ipv6 for VM_A
$Enable = 0
$Enresult = ping-VM ${sshKey} ${ipv4} $Enable $IPv6_B $packages
LogPrint "DEBUG: Enresult: $Ensresult"
if ($Enresult[-1] -eq $False) 
{
    LogPrint "ERROR: Set enable ipv6 failed."
}
elseif ($Enresult[-1] -eq 0)
{
    LogPrint "INFO: Set enable ipv6, and sucess to ping6"
    $retVal2 = $True
}
else 
{
    LogPrint "ERROR: Set enable ipv6, and failed to ping6, $Enresult"
}


Stop-VM $vmB -Confirm:$False -RunAsync:$true -ErrorAction SilentlyContinue


if ($retVal1 -and $retval2)
{
    return $Passed
}
else
{
	return $Failed
}
