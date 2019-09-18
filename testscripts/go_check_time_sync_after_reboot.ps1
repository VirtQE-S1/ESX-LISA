#######################################################################################
## Description:
##  Check Guest time sync with a clock server after reboot
## Revision:
##  v1.0.0 - xinhu - 09/17/2019 - Build the script
#######################################################################################


<#
.Synopsis
    Check Guest time drift with clock server after suspend

.Description
    Check Guest time drift with clock server after suspend
    
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


#######################################################################################
# Main Body
#######################################################################################
$retVal = $Failed
# Current version doesn't support "Sync Guest Time" from Setting GUI

# Target offset as 1 sec, after , offset should be less than $minOffset
$minOffset = 1

# Confirm the VM power state is PoweredOn
function CheckVMState($hvServer,$vmName)
{
    $vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
    $state = $vmObj.PowerState
    Write-Host -F Red "DEBUG: state: $state"
    Write-Output "DEBUG: state: $state"
    if ($state -ne "PoweredOn")
    {
        Write-Error -Message "ABORTED: $vmObj is not poweredOn, power state is $state" -Category ObjectNotFound -ErrorAction SilentlyContinue
        return $False
    } 
    return $True
}


# Stop and Disable ntpdate/chronyd
function StopTimeService($linuxOS,${sshKey},${ipv4})
{
    if ($linuxOS -eq "RedHat6")
    {
        $serviceName = 'ntp'
    }
    else
    {
        $serviceName = 'chronyd'
    }    

    $ntpStop = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "systemctl stop $serviceName ; echo `$? "
    $ntpDisable = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "systemctl disable $serviceName ; echo `$? "
    Write-Host -F Red "DEBUG: stop $serviceName status: $ntpStop"
    Write-Output "DEBUG: stop $serviceName status: $ntpStop"
    if ($ntpStop -ne 0)
    {
        Write-Host -F Red "ERROR: stop $serviceName failed"
        #Write-Output "ERROR: stop $serviceName failed"
        return "Aborted"
    }
    Write-Host -F Green "INFO: Success to stop $serviceName"
    Write-Output "INFO: Success to stop $serviceName"

    if ($ntpDisable -ne 0)
    {
        Write-Host -F Red "ERROR: disable $serviceName failed"
        return $False
    }
    Write-Host -F Green "INFO: Success to disable $serviceName"
    Write-Output "INFO: Success to disable $serviceName"
    return $True
}


# Config, start and enable ntpdate/chronyd
function StartTimeService($linuxOS,${sshKey},${ipv4})
{
    if ($linuxOS -eq "RedHat6")
    {
        $serviceName = 'ntp'
        $configNTP = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo clock.redhat.com > /etc/ntp/step-tickers;echo `$?"
    }
    else
    {
        $serviceName = 'chronyd'
        $configNTP = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo server clock.redhat.com >> /etc/chrony.conf;echo `$?"
    }
    
    Write-Host -F Red "DEBUG: Add clock server: $configNTP"
    Write-Output "DEBUG: Add clock server: $configNTP"
    if ($configNTP -ne 0)
    {
        Write-Host -F Red "ERROR: Add clock.server to $serviceName failed"
        Write-Output "ERROR: Add clock.server to $serviceName failed"
        return $False
    }

    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "systemctl enable $serviceName"
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "systemctl start $serviceName"
    $enableNtpdate =  bin\plink.exe -i ssh\${sshKey} root@${ipv4} "systemctl status $serviceName | grep Loaded"
    $startNtpdate = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "systemctl status $serviceName | grep running"
    $enableNtpdate = $enableNtpdate.Split(';')[1]

    if (!$startNtpdate)
    {
        Write-Host -F Red "ERROR: start $serviceName failed"
        Write-Output "ERROR: start $serviceName failed"
        return $False
    }
    Write-Host -F Green "INFO: Success to start $serviceName : $startNtpdate"
    Write-Output "INFO: Success to start $serviceName : $startNtpdate"

    if ($enableNtpdate -ne " enabled")
    {
        Write-Host -F Red "ERROR: enable $serviceName failed"
        Write-Output "ERROR: enable $serviceName failed"
        return $False
    }
    Write-Host -F Green "INFO: Success to enable $serviceName : $enableNtpdate"
    Write-Output "INFO: Success to enable $serviceName : $enableNtpdate"
    return $True
}


# Get the offset time
function GetOffset($linuxOS,${sshKey},${ipv4})
{
    if ($linuxOS -eq "RedHat6")
    {
        $serviceName = 'ntp'
        $offset_temp = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ntpdate -q clock.redhat.com | awk 'NR == 5 {print `$10`}'"
    }
    else
    {
        $serviceName = 'chronyd'
        $offset_temp = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "chronyc tracking | grep 'Last offset' | awk '{print `$4`}'"
    }

    $offset = [Math]::Abs($offset_temp)
    Write-Host -F Green "INFO: offset is $offset"
    Write-Output "INFO: offset is $offset"
    if ($offset -gt $minOffset)
    {
        Write-Host -F Yellow "ERROR: Offset is greater than 1s"
        Write-Output "ERROR: Offset is greater than 1s"
        return $False
    }
    return $True
}


$linuxOS = GetLinuxDistro $ipv4 $sshKey

# Skip Readhat 6
if ($linuxOS -eq "RedHat6")
{
    Write-Host -F Red "INFO: The linuxOS is $linuxOS, Skipping"
    Write-Output "INFO: The linuxOS is $linuxOS, Skipping"
    DisconnectWithVIServer
    return $Skipped
}

Write-Host -F Green "INFO: check state"
Write-Output "INFO: check state"
$result = CheckVMState $hvServer $vmName
Write-Host -F Red "$result"
Write-Output "$result"
if ($result[-1] -eq $False) 
{
    DisconnectWithVIServer
    return $Aborted
}

Write-Host -F Green "INFO: stop time sync"
Write-Output "INFO: stop time sync"
$result = StopTimeService $linuxOS ${sshKey} ${ipv4}
Write-Host -F Red "$result"
Write-Output "$result"
if ($result[-1] -eq $False) 
{
    DisconnectWithVIServer
    return $Aborted
}

Write-Host -F Green "INFO: restart time sync"
Write-Output "INFO: restart time sync"
$result = StartTimeService $linuxOS ${sshKey} ${ipv4}
Write-Host -F Red "$result"
Write-Output "$result"
if ($result[-1] -eq $False)
{
    DisconnectWithVIServer
    return $Aborted
}

# Before reboot, check offset which should be less than $minOffset
$result = GetOffset $linuxOS ${sshKey} ${ipv4}
Write-Host -F Red "$result"
Write-Output "$result"
if ($result[-1] -eq $False) 
{
    DisconnectWithVIServer
    return $Aborted
}

# Reboot the VM and confirm the power state
Write-Host -F Red "INFO: Rebooting the VM"
Write-Output "INFO: Rebooting the VM......."
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
$reboot = Restart-VM -VM $vmObj -Confirm:$False

# WaitForVMSSHReady
$ret = WaitForVMSSHReady $vmName $hvServer ${sshKey} 300

# Get the new VM power status
$result = CheckVMState $hvServer $vmName
Write-Host -F Green "$result"
Write-Output "$result"

if ($result[-1] -eq $False) 
{
    DisconnectWithVIServer
    return $Aborted
}

# After power on, check offset which should be less than $minOffset
$result = GetOffset $linuxOS ${sshKey} ${ipv4}
Write-Host -F Green "$result"
Write-Output "$result"
if ($result[-1] -eq $True) 
{
    
    Write-Host -F Green "PASS: After reboot, offset is correct"
    Write-Output "PASS: After reboot, offset is correct"
    $retVal = $Passed
}

DisconnectWithVIServer
return $retVal
