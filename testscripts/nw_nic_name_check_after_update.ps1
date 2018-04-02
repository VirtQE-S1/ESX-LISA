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
#
$rhel6_repo = "http://download.eng.pek2.redhat.com/pub/rhel/rel-eng/latest-RHEL-6.*/compose/Server/x86_64/os/"
$rhel7_repo = "http://download.eng.pek2.redhat.com/pub/rhel/rel-eng/latest-RHEL-7.*/compose/Server/x86_64/os/"
$rhel8_repo = "http://download.eng.pek2.redhat.com/pub/rhel/rel-eng/latest-RHEL-8.*/compose/Server/x86_64/os/"


#Check the guest os big version.
$DISTRO = ""
$DISTRO = GetLinuxDistro ${ipv4} ${sshKey}
if ( $DISTRO -eq "RedHat6" )
{
    $change_repo = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "sed -i '3c\baseurl=$rhel6_repo' /etc/yum.repos.d/rhel_new.repo"
    write-host -F red "The guest os is rhel6"
    write-output "The guest os is rhel6"

}
else
{
    if ( $DISTRO -eq "RedHat7" )
    {
        $change_repo = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "sed -i '3c\baseurl=$rhel7_repo' /etc/yum.repos.d/rhel_new.repo"
        write-host -F red "The guest os is rhel7"
        write-output "The guest os is rhel7"
    }
    else
    {
        $change_repo = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "sed -i '3c\baseurl=$rhel8_repo' /etc/yum.repos.d/rhel_new.repo"
        write-host -F red "The guest os is rhel8"
        write-output "The guest os is rhel8"
    }
}


#Update the whole guest to new version with yum command.
$update_guest = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "yum clean all && yum makecache && yum update -y"


#Check the new kernel installed or not.
$kernel_num = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "rpm -qa kernel |wc -l"
write-host -F red "The kernel number is $kernel_num"
if ($kernel_num -eq "1")
{
    write-Output "no new kernel installed,no new compose for update."
}
else
{
    write-Output "Installed a new kernel,The guest updated successfully."
}


#check the default kernel version.
$default_kernel = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "uname -r"
write-host -F red "The default kernel is $default_kernel. "
write-Output "The default kernel is $default_kernel. "

#Reboot the guest
$reboot = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "init 6"
Start-Sleep -seconds 6
# wait for vm to Start
$ssh = WaitForVMSSHReady $vmName $hvServer ${sshKey} 300
if ( $ssh -ne $true )
{
    Write-Output "Failed: Failed to start VM."
    return $Aborted
}
else
{
    #Check the kernel after reboot.
    $new_kernel = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "uname -r"
    Write-Host -F red "After reboot the current kernel is $new_kernel."
    write-Output "After reboot the current kernel is $new_kernel."
    #compaire the new kernel whether boot in guest.
    if ($default_kernel -eq $new_kernel)
    {
        Write-Output "The new kernel boot failed in guest."
        return $Aborted
    }
    else
    {
        $calltrace_check = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "dmesg |grep "Call Trace""
        Write-Host -F red "The call trace check result is $calltrace_check"
		$new_eth = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ls /sys/class/net/ | grep ^e[tn][hosp]"
        Write-Host -F red "DEBUG: new_eth: $new_eth"		
        if ($null -eq $calltrace_check -and $eth -eq $new_eth)
        {
            $retVal = $Passed
            Write-host -F Red "After update to new version, guest could reboot with new kernel with no crash, no Call Trace."
            Write-Output "PASS: After booting with new kernel $current_kernel, NO call trace $calltrace_check found."
        }
        else
        {
            Write-Output "FAIL: After booting, FOUND call trace $calltrace_check in demsg."
        }
    }
}

DisconnectWithVIServer

return $retVal
