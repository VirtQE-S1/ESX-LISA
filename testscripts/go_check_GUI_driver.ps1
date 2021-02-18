########################################################################################
## Description:
## 	Check the vmware driver xorg-x11-drv-vmware exist in guest.
##
## Revision:
## 	v1.0.0 - ldu - 05/20/2019 - Check xorg-x11-drv-vmware exists or not.
## 	v1.0.1 - boyang - 05/20/2019 - Skip test in RHEL-6.
########################################################################################


<#
.Synopsis
    Check the vmware driver xorg-x11-drv-vmware exist in guest.
.Description
    Check the vmware driver xorg-x11-drv-vmware exist in guest.
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
        "VMMemory"     	{ $mem = $fields[1].Trim() }
        "standard_diff"	{ $standard_diff = $fields[1].Trim() }
		default			{}
    }
}


# Check all parameters are valid
if (-not $rootDir)
{
	"WARNING: no rootdir was specified"
}
else
{
	if ( (Test-Path -Path "${rootDir}") )
	{
		cd $rootDir
	}
	else
	{
		"WARNING: rootdir '${rootDir}' does not exist"
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


# As last RHEL-6.10 has been released. All RHEL-6 VMs haven't GUI.
$DISTRO = GetLinuxDistro ${ipv4} ${sshKey}
LogPrint "DEBUG: DISTRO: $DISTRO."
if ($null -eq $DISTRO) {
    LogPrint "ERROR: Guest OS version is NULL."
    DisconnectWithVIServer
    return $Aborted
}

if ($DISTRO -eq "RedHat6") {
    LogPrint "INFO: Skip the test in RHEL-6."
    DisconnectWithVIServer
    return $Skipped
}


# If VM is installed by text mode. Skip.
$install_type = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "cat /root/anaconda-ks.cfg | grep -e ^graphical"
LogPrint "DEBUG: install_type: ${install_type}."
if ($null -eq $install_type) {
    LogPrint "INFO: VM is installed by text mode, skip its GUI driver checking."
    DisconnectWithVIServer
    return $Skipped
}


# Check the vmware driver xorg-x11-drv-vmware exists or not.
$vmware_driver = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "rpm -qa xorg-x11-drv-vmware"
LogPrint "DEBUG: vmware_driver: $vmware_driver."
if ($vmware_driver -eq $null)
{
	LogPrint "ERROR: There is no vmware GUI related driver."
}
else{
    LogPrint "INFO: Found VMware GUI related driver."
    $retVal = $Passed
}


DisconnectWithVIServer
return $retVal
