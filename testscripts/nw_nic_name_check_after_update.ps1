###############################################################################
#
# Description:
#	Check the NIC name of current Guest, yum update Guest, check NIC name again
#
#
# Revision:
#	v1.0.0 - boyang - 03/28/2018 - Draft the script
#
#
###############################################################################


<#
.Synopsis

.Description
<test>
	<testName>nw_nic_name_check_after_update</testName>
	<testID>ESX-NW-015</testID>			
	<testScript>nw_nic_name_check_after_update.ps1</testScript>
	<files>testscripts/nw_nic_name_check_after_update.ps1</files>			
	<files>remote-scripts/utils.sh</files>
	<RevertDefaultSnapshot>True</RevertDefaultSnapshot>
	<timeout>360</timeout>
	<testParams>
		<param>TC_COVERED=RHEL6-38522,RHEL7-80534</param>
	</testParams>
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


param([String] $vmName, [String] $hvServer, [String] $testParams)


#
# Checking the input arguments
#
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


#
# Output test parameters so they are captured in log file
#
"TestParams : '${testParams}'"


#
# Parse test parameters
#
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
        "Kernel"     { $kernel = $fields[1].Trim() }
        "Kernel_Firmware"{ $kernel_firmware = $fields[1].Trim() }
		default			{}
    }
}


#
# Check all parameters are valid
#
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


#
# Source tcutils.ps1
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


#
# Confirm NIC interface types. RHELs has different NIC types, like "eth0" "ens192:" "enp0s25:"
#
$eth = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ls /sys/class/net/ | grep ^e[tn][hosp]"


#
# The latest repo for rhel.X
# If need update the link, please contact developer
# Also, $repo_base can be defined in xml
#
$repo_base = "http://download.eng.pek2.redhat.com/pub/rhel/rel-eng"
$repo_last = "/compose/Server/x86_64/os/"
$rhel6_repo = $repo_base + "/latest-RHEL-6.*" + $repo_last
$rhel7_repo = $repo_base + "/latest-RHEL-7.*" + $repo_last
$rhel8_repo = $repo_base + "/latest-RHEL-8.*" + $repo_last


$DISTRO = GetLinuxDistro ${ipv4} ${sshKey}
if ( $DISTRO -eq "RedHat6" )
{
    $change_repo = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "sed -i '3c\baseurl=$rhel6_repo' /etc/yum.repos.d/rhel_new.repo"
    Write-Host -F red "The Guest OS is $DISTRO"
    Write-Output "The Guest OS is $DISTRO"
}
else
{
    if ( $DISTRO -eq "RedHat7" )
    {
        $change_repo = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "sed -i '3c\baseurl=$rhel7_repo' /etc/yum.repos.d/rhel_new.repo"
        Write-Host -F red "The Guest OS is $DISTRO"
        Write-Output "The Guest OS is $DISTRO"
    }
    else
    {
        $change_repo = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "sed -i '3c\baseurl=$rhel8_repo' /etc/yum.repos.d/rhel_new.repo"
        Write-Host -F red "The Guest OS is $DISTRO"
        Write-Output "The Guest OS is $DISTRO"
    }
}


# pdate the Guest
$update_guest = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "yum clean all && yum makecache && yum update -y"


# Check kernels counts to identify 'yum update' passed or not
$kernel_num = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "rpm -qa kernel |wc -l"
Write-Host -F red "DEBUG: kernel_num: $kernel_num"
Write-Output "DEBUG: kernel_num: $kernel_num"
if ($kernel_num -eq "1")
{
    Write-Host -F red "ERROR: Guest yum update failed"
    Write-Output "ERROR: Guest yum update failed"
	Return $Aborted
}


# Check the default kernel version
$default_kernel = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "uname -r"
Write-Host -F red "INFO: The default kernel is $default_kernel"
Write-Output "INFO: The default kernel is $default_kernel"


# CReboot the guest
$reboot = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "init 6"
Start-Sleep -seconds 6


# Wait for the VM
$ssh = WaitForVMSSHReady $vmName $hvServer ${sshKey} 360
if ( $ssh -ne $true )
{
	Write-Host -F Red "ERROR: Failed to start VM"
    Write-Output "ERROR: Failed to start VM"
    return $Aborted
}


# Check the new kernel version
$new_kernel = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "uname -r"
Write-Host -F red "INFO: New kernel is $new_kernel"
Write-Output "INFO: New kernel is $new_kernel"


if ($default_kernel -eq $new_kernel)
{
	Write-Host -F Red "ERROR: The new kernel booting failed"
	Write-Output "ERROR: The new kernel booting failed"
	return $Aborted
}


$calltrace_check = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "dmesg |grep "Call Trace""
Write-Host -F red "INFO: The call trace is $calltrace_check"
Write-Output "INFO: The call trace is $calltrace_check"


$new_eth = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ls /sys/class/net/ | grep ^e[tn][hosp]"


if ($null -eq $calltrace_check -and $eth -eq $new_eth)
{
	Write-Host -F Red "PASS: No call trace and NIC name no chage after update"
	Write-Output "PASS: No call trace and NIC name no change after update"
	$retVal = $Passed
}
else
{
	Write-Output "FAIL: Have call trace or NIC name has been chagned"
}


DisconnectWithVIServer


return $retVal
