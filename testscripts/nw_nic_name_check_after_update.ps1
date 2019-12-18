########################################################################################
## Description:
##  Check the NIC name, yum update the Guest, check NIC name again.
##
##
## Revision:
##  v1.0.0 - boyang - 03/28/2018 - Draft the script
##  v2.0.0 - boyang - 09/06/2019 - Rebuild whole script
########################################################################################


<#
.Synopsis
	Check the NIC name, yum update the Guest, check NIC name again.

.Description
	Check the NIC name, yum update the Guest, check NIC name again.

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
        "Kernel"     { $kernel = $fields[1].Trim() }
        "Kernel_Firmware"{ $kernel_firmware = $fields[1].Trim() }
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
## Main Body
########################################################################################
$retVal = $Failed


# Confirm NIC interface types. RHELs has different NIC types, like "eth0" "ens192:" "enp0s25:"
$eth = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ls /sys/class/net/ | grep ^e[tn][hosp]"


# The nightly / latest repo for rhel6, NO extra or optional repo.
$rhel6_repo = "http://download.eng.pek2.redhat.com/pub/nightly/rhel-6/latest-RHEL-6/compose/Server/x86_64/os/"

# The nightly / latest repo for rhel7.
$rhel7_repo = "http://download.eng.pek2.redhat.com/pub/nightly/latest-RHEL-7/compose/Server/x86_64/os/"
$rhel7_optional_repo = "http://download.eng.pek2.redhat.com/pub/nightly/latest-RHEL-7/compose/Server-optional/x86_64/os/"
$rhel7_extra_repo = "http://download-node-02.eng.bos.redhat.com/rhel-7/rel-eng/EXTRAS-7/latest-EXTRAS-7-RHEL-7/compose/Server/x86_64/os/"

# The nightly / latest repo for rhel8, the same extra repo to rhel7.
$rhel8_repo_appstream = "http://download.eng.pek2.redhat.com/pub/nightly/latest-RHEL-8/compose/AppStream/x86_64/os/"
$rhel8_repo_baseos = "http://download.eng.pek2.redhat.com/pub/nightly/latest-RHEL-8/compose/BaseOS/x86_64/os/"
$rhel8_extra_repo = "http://download-node-02.eng.bos.redhat.com/rhel-7/rel-eng/EXTRAS-7/latest-EXTRAS-7-RHEL-7/compose/Server/x86_64/os/"

Write-Host -F Red "INFO: Move repo files under /etc/yum.repos.d/ to /tmp/"
Write-Output "INFO: Move repo files under /etc/yum.repos.d/ to /tmp/"
bin\plink.exe -i ssh\${sshKey} root@${ipv4} "mv /etc/yum.repos.d/* /tmp/"

Write-Host -F Red "INFO: Creat a new nightly repor for Yum Update"
Write-Output "INFO: Creat a new nightly repor for Yum Update"
bin\plink.exe -i ssh\${sshKey} root@${ipv4} "touch /etc/yum.repos.d/rhel_nightly.repo"

# Check the guest os big version.
$DISTRO = GetLinuxDistro ${ipv4} ${sshKey}
Write-Host -F Red "INFO: Guest OS: $DISTRO"
Write-Output "INFO: Guest OS: $DISTRO"
if ($DISTRO -eq "RedHat6")
{
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo [rhelx] > /etc/yum.repos.d/rhel_nightly.repo"
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo name=rhelx >> /etc/yum.repos.d/rhel_nightly.repo"
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo baseurl=$rhel6_repo >> /etc/yum.repos.d/rhel_nightly.repo"
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo enabled=1 >> /etc/yum.repos.d/rhel_nightly.repo"
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo gpgcheck=0 >> /etc/yum.repos.d/rhel_nightly.repo"
}
if ($DISTRO -eq "RedHat7")
{
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo [rhelx] > /etc/yum.repos.d/rhel_nightly.repo"
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo name=rhelx >> /etc/yum.repos.d/rhel_nightly.repo"
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo baseurl=$rhel7_repo >> /etc/yum.repos.d/rhel_nightly.repo"
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo enabled=1 >> /etc/yum.repos.d/rhel_nightly.repo"
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo gpgcheck=0 >> /etc/yum.repos.d/rhel_nightly.repo"

    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo [rhelx-optional] >> /etc/yum.repos.d/rhel_nightly.repo"
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo name=rhelx-optional >> /etc/yum.repos.d/rhel_nightly.repo"
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo baseurl=$rhel7_optional_repo >> /etc/yum.repos.d/rhel_nightly.repo"
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo enabled=1 >> /etc/yum.repos.d/rhel_nightly.repo"
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo gpgcheck=0 >> /etc/yum.repos.d/rhel_nightly.repo"

    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo [rhelx-extra] >> /etc/yum.repos.d/rhel_nightly.repo"
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo name=rhelx-extra >> /etc/yum.repos.d/rhel_nightly.repo"
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo baseurl=$rhel7_extra_repo >> /etc/yum.repos.d/rhel_nightly.repo"
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo enabled=1 >> /etc/yum.repos.d/rhel_nightly.repo"
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo gpgcheck=0 >> /etc/yum.repos.d/rhel_nightly.repo"
}
if ($DISTRO -eq "RedHat8")
{
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo [rhelx] > /etc/yum.repos.d/rhel_nightly.repo"
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo name=rhelx >> /etc/yum.repos.d/rhel_nightly.repo"
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo baseurl=$rhel8_repo_baseos >> /etc/yum.repos.d/rhel_nightly.repo"
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo enabled=1 >> /etc/yum.repos.d/rhel_nightly.repo"
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo gpgcheck=0 >> /etc/yum.repos.d/rhel_nightly.repo"

    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo [appstream] >> /etc/yum.repos.d/rhel_nightly.repo"
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo name=appstream >> /etc/yum.repos.d/rhel_nightly.repo"
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo baseurl=$rhel8_repo_appstream >> /etc/yum.repos.d/rhel_nightly.repo"
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo enabled=1 >> /etc/yum.repos.d/rhel_nightly.repo"
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo gpgcheck=0 >> /etc/yum.repos.d/rhel_nightly.repo"

    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo [rhelx-extra] >> /etc/yum.repos.d/rhel_nightly.repo"
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo name=rhelx-extra >> /etc/yum.repos.d/rhel_nightly.repo"
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo baseurl=$rhel8_extra_repo >> /etc/yum.repos.d/rhel_nightly.repo"
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo enabled=1 >> /etc/yum.repos.d/rhel_nightly.repo"
    bin\plink.exe -i ssh\${sshKey} root@${ipv4} "echo gpgcheck=0 >> /etc/yum.repos.d/rhel_nightly.repo"
}


# Before update, how many kernels
$orginal_kernel_num = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "rpm -qa kernel | wc -l"


# Check the default kernel version.
$default_kernel = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "uname -r"
Write-Host -F Red "DEBUG: default_kernel: $default_kernel"
Write-Output "DEBUG: default_kernel: $default_kernel"


# Update the Guest
$update_guest = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "yum clean all && yum makecache && yum update -y && echo $?"
if ($update_guest[-1] -ne "True")
{
    Write-Host -F Red "ERROR: Yum update failed"
    Write-Output "ERROR: Yum update failed"
    return $Aborted
}


Start-Sleep -seconds 6


# Check the new kernel installed or not.
$kernel_num = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "rpm -qa kernel | wc -l"
Write-Host -F Red "DEBUG: kernel_num: $kernel_num"
Write-Output "DEBUG: kernel_num: $kernel_num"
if ($kernel_num -eq $orginal_kernel_num)
{
    write-Output "ERROR: NO new kernel installed,no new compose for update."
    return $Skipped
}
else
{
    write-Output "INFO: Installed a new kernel,The guest updated successfully."
}


# Reboot the guest
$reboot = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "init 6"


Start-Sleep -seconds 6


# Wait for the VM
$ssh = WaitForVMSSHReady $vmName $hvServer ${sshKey} 360
if ($ssh -ne $true)
{
	Write-Host -F Red "ERROR: Failed to start VM."
    Write-Output "ERROR: Failed to start VM."
    return $Aborted
}


# Check the new kernel version
$new_kernel = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "uname -r"
Write-Host -F red "INFO: After reboot the current kernel is $new_kernel."
write-Output "INFO: After reboot the current kernel is $new_kernel."


$status = CheckCallTrace $ipv4 $sshKey
if (-not $status[-1]) {
    Write-Host -F Red "ERROR: Found $(status[-2]) in msg."
    Write-Output "ERROR: Found $(status[-2]) in msg."
    DisconnectWithVIServer
    return $Failed
}
else {
    Write-Host -F Red "INFO: NO call trace found with new kernel."
    Write-Output "INFO: NO call trace found with new kernel."
}


# Check NIC name.
$new_eth = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "ls /sys/class/net/ | grep ^e[tn][hosp]"
if ($eth -eq $new_eth)
{
	Write-Host -F Red "INFO: PASS. NIC keep the orignal anme after update."
	Write-Output "INFO: PASS. NIC keep the orignal anme after update."
	$retVal = $Passed
}
else
{
	Write-Host -F Red "ERROR: FAIL. NIC name has been chagned."
	Write-Output "ERROR: FAIL. NIC name has been chagned."
}


DisconnectWithVIServer
return $retVal
