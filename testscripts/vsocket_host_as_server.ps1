########################################################################################
## Description:
## 		A ESXi Host  as a Server communicates to a VM as a Client with CID
##
## Revision:
##  	v1.0.0 - boyang - 06/12/2019 - Draft script
########################################################################################


<#
.Synopsis
    A ESXi Host  as a Server communicates to a VM as a Client with CID

.Description
    A ESXi Host  as a Server communicates to a VM as a Client with CID
	
.Parameter vmName
    Name of the test VM

.Parameter hvServer
    Name of the VIServer hosting the VM

.Parameter testParams
    Semicolon separated list of test parameters
#>


param([String] $vmName, [String] $hvServer, [String] $testParams)


# Checking the input arguments
if (-not $vmName)
{
    "FAIL: VM name cannot be null!"
    return $Aborted
}

if (-not $hvServer)
{
    "FAIL: hvServer cannot be null!"
    return $Aborted
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
$crashkernel = $null
$logdir = $null
$nmi = $null
$tname = $null

$params = $testParams.Split(";")
foreach ($p in $params) 
{
	$fields = $p.Split("=")
	switch ($fields[0].Trim()) 
	{
		"rootDir"		{ $rootDir = $fields[1].Trim() }
		"sshKey"		{ $sshKey = $fields[1].Trim() }
		"ipv4"			{ $ipv4 = $fields[1].Trim() }
		"crashkernel"	{ $crashkernel = $fields[1].Trim() }
		"TestLogDir"	{ $logdir = $fields[1].Trim()}
		"NMI"			{ $nmi = $fields[1].Trim()}
		"TName"			{ $tname = $fields[1].Trim()}		
		default			{}
    }
}

# Check all parameters
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
		return $Aborted
	}
}

if ($null -eq $sshKey) 
{
	"FAIL: Test parameter sshKey was not specified"
	return $Aborted
}

if ($null -eq $ipv4) 
{
	"FAIL: Test parameter ipv4 was not specified"
	return $Aborted
}

if ($null -eq $crashkernel)
{
	"FAIL: Test parameter crashkernel was not specified"
	return $Aborted
}

if ($null -eq $logdir)
{
	"FAIL: Test parameter logdir was not specified"
	return $Aborted
}

# NMI is not supports now

if ($null -eq $tname)
{
	"FAIL: Test parameter tname was not specified"
	return $Aborted
}


# Source tcutils.ps1
. .\setupscripts\tcutils.ps1
PowerCLIImport
ConnectToVIServer $env:ENVVISIPADDR `
                  $env:ENVVISUSERNAME `
                  $env:ENVVISPASSWORD `
                  $env:ENVVISPROTOCOL

				  
########################################################################################
##  Main Body
########################################################################################

$retVal = $Failed

# Execute vsocket_host_as_server_cid.sh
Write-Host -F Red "INFO: Execute vsocket_host_as_server_cid.sh in VM."
Write-Output "INFO: Execute vsocket_host_as_server_cid.sh in VM."
$result = SendCommandToVM $ipv4 $sshKey "cd /root && sleep 1 && dos2unix vsocket_host_as_server_cid.sh && chmod u+x vsocket_host_as_server_cid.sh && sleep 1 && ./vsocket_host_as_server_cid.sh $hvServer"
if (-not $result)
{
	Write-Host -F Red "ERROR: Failed to execute vsocket_host_as_server_cid.sh in VM"
	Write-Output "ERROR: Failed to execute vsocket_host_as_server_cid.sh in VM"
	DisconnectWithVIServer
	return $Aborted
}
else
{
	$retVal = $Passed
}

DisconnectWithVIServer

return $retVal
