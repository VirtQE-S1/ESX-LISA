########################################################################################
## Description:
## 	Check Guest time drift with clock server after suspend
##
##
## Revision:
## 	v1.0.0 - boyang - 08/11/2017 - Build the script.
## 	v1.0.1 - boyang - 08/11/2017 - Format the output.
########################################################################################


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
	"Warn: no rootdir was specified."
}
else
{
	if ( (Test-Path -Path "${rootDir}") )
	{
		cd $rootDir
	}
	else
	{
		"WARN: rootdir '${rootDir}' does not exist."
	}
}

if ($null -eq $sshKey)
{
	"FAIL: Test parameter sshKey was not specified."
	return $False
}

if ($null -eq $ipv4)
{
	"FAIL: Test parameter ipv4 was not specified."
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


# Target offset as 1 sec, after ntpdate, offset should be less than $minOffset
$minOffset = 1


# Confirm the VM power state is PoweredOn
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
$state = $vmObj.PowerState
LogPrint "DEBUG: state: $state"
if ($state -ne "PoweredOn")
{
    Write-Error -Message "ABORTED: $vmObj is not poweredOn, power state is $state" -Category ObjectNotFound -ErrorAction SilentlyContinue
    return $Aborted
}

# Stop time rysnc service with different methods for RHEL 6 or RHEL7 / RHEL8 
$linuxOS = GetLinuxDistro $ipv4 $sshKey
if ($linuxOS -eq "RedHat6")
{
    $ntpdDisable = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "service ntpd stop"
    $ntpdStatus = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "service ntpd status"
    LogPrint "DEBUG: ntpdStatus: $ntpdStatus"
	# HERE. Need to enhance this kind of check. BAD.
    if ($ntpdStatus -ne "ntpd is stopped")
    {
        LogPrint "ERROR: NTPD stopping failed"
        DisconnectWithVIServer
        return $Aborted
    }
}
else
{
    # Stop ntpd / chronyd
    $ntpdStop = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "systemctl stop ntpd"
    $ntpdDisable = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "systemctl disable ntpd"
    $result = SendCommandToVM $ipv4 $sshKey "systemctl status ntpd | grep running"
    LogPrint "DEBUG: result: $result"
    if ($result -ne $False)
    {
        LogPrint "ERROR: NTPD stopping failed"
        DisconnectWithVIServer
        return $Aborted
    }
    
    $ntpdStop = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "systemctl stop chronyd"
    $ntpdDisable = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "systemctl disable chronyd"
    $result = SendCommandToVM $ipv4 $sshKey "systemctl status chronyd | grep running"
    LogPrint "DEBUG: result: $result"
    if ($result -ne $False)
    {
        LogPrint "ERROR: CHRONYD stopping failed."
        DisconnectWithVIServer
        return $Aborted
    }
    
    # Config ntp clock server and restart ntpdate
    $configNTP = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo clock.redhat.com > /etc/ntp/step-tickers"
    $enableNtpdate = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "systemctl enable ntpdate"
    $startNtpdate = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "systemctl start ntpdate"
    $timedatectlResult = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "timedatectl set-ntp 0"
}


# Before suspend, check offset which should be less than $minOffset
$offset_temp = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ntpdate -q clock.redhat.com | awk 'NR == 5 {print `$10`}'"
LogPrint "DEBUG: offset_temp: $offset_temp"
$offset = [Math]::Abs($offset_temp)
LogPrint "INFO: Before suspend, offset is $offset"
if ($offset -gt $minOffset)
{
    LogPrint "ERROR: Offset is wrong before suspend"
    DisconnectWithVIServer
    return $Aborted
}


# Suspend the VM and confirm the power state
LogPrint "INFO: Suspending the VM ${vmName}."
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
$suspend = Suspend-VM -VM $vmObj -Confirm:$False
Start-Sleep -S 60
# Get the new VM power status
$vmObjSuspend = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
$suspendState = $vmObjSuspend.PowerState
LogPrint "DEBUG: suspendState: $suspendState"
if ($suspendState -ne "Suspended")
{
    LogPrint "ERROR: Power state is $suspendState, should be Suspended." 
    DisconnectWithVIServer
    return $Aborted
}
else
{
    LogPrint "INFO: Power state is $suspendState, sleep 60s again in ${suspendState}" 
    Start-Sleep 60
}


# Power the VM, and confirm the power state
LogPrint "INFO: Powering On the VM $vmName"
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
$on = Start-VM -VM $vmObj -Confirm:$False


# WaitForVMSSHReady
$ret = WaitForVMSSHReady $vmName $hvServer ${sshKey} 300


# Get the new VM power status
$vmObjOn = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
$onState = $vmObjOn.PowerState
if ($onState -ne "PoweredOn")
{
    LogPrint "ERROR: Power state is not PoweredOn, power state is ${onState}."        
    DisconnectWithVIServer
    return $Aborted
}


# After power on, check offset which should be less than $minOffset
$offset_temp = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ntpdate -q clock.redhat.com | awk 'NR == 5 {print `$10`}'"
$statusNtpdate = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "systemctl status ntpdate"
LogPrint "DEBUG: statusNtpdate: $statusNtpdate"


# Get offset_temp abs
$offset = [Math]::Abs($offset_temp)
LogPrint "DEBUG: offset: $offset"
if ($offset -gt $minOffset)
{
    LogPrint "FAIL: After suspend, offset is incorrect."
}
else
{
    LogPrint "PASS: After suspend, offset is correct"
    $retVal = $Passed
}


DisconnectWithVIServer
return $retVal
