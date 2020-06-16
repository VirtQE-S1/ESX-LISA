########################################################################################
## Description:
##  VM ping ESXi host and other guest.
##
## Revision:
## 	v1.0.0 - boyang - 03/18/2017 - Build script and only support ping ESXi Host.
########################################################################################


<#
.Synopsis
    Target VM ping function
.Description
    Trigger VM ping function with ESXi Host and other Guest
.Parameter vmName
    Name of the test VM.
.Parameter hvServer
    Name of the VIServer hosting the VM.
.Parameter testParams
    Semicolon separated list of test parameters.
#>


param([String] $vmName, [String] $hvServer, [String] $testParams)
# Checking the input arguments
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
$retVal = $Failed
$package = 600


# Confirm NIC interface names. RHELs has different NIC names, like "eth0" "ens192:" "enp0s25:" "eno167832:"
# After snapshot, defalut, NIC works and MTU is 1500
$eth = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ls /sys/class/net/ | grep ^e[tn][hosp]"
LogPrint "DEBUG: eth: $eth"


# Ping Esxi Host. After snapshot, only one NIC(eth0, ens192, eno1678032, enp0s25) can ping $hvServer
$vmOut = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmOut)
{
    Write-Error -Message "nw_ping.ps1: Unable to create VM object for VM $vmName" -Category ObjectNotFound -ErrorAction SilentlyContinue
}
else
{
	LogPrint "INFO: Ping VM's ESXi Host."
	$result = SendCommandToVM $ipv4 $sshKey "ping -I $eth -f $hvServer -c $package"
	if ($result)
	{
		LogPrint "INFO: NIC $eth ping ESXi host successfully."
		$retVal = $Passed
	}
}


DisconnectWithVIServer
return $retVal
