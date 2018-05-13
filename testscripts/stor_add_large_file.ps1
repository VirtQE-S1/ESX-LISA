###############################################################################
##
## Description:
##  Add a disk, do partition and formtion, then creat a 11g file
##
## Revision:
##  v1.0.0 - junfwang - 03/19/2018 - Build script
##  v1.0.1 - boyang - 05/14/2018 - Enhance the scripts
##
###############################################################################


<#
.Synopsis
   creat a 11g file in xfs or ext4

.Description

<test>
    <testName>stor_add_large_file</testName>
    <testID>ESX-STOR-010</testID>
    <testScript>testScripts\stor_add_large_file.ps1</testScript>
    <files>remote-scripts/utils.sh,remote-scripts/fdisk.sh</files>
    <cleanupScript>SetupScripts\remove_hard_disk.ps1</cleanupScript>
    <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
    <timeout>1800</timeout>
    <testparams>
       <param>TC_COVERED=RHEL6-38508,RHEL7-80181</param>
    </testparams>
    <onError>Continue</onError>
</test>

.Parameter vmName
    Name of the test VM.

.Parameter testParams
    Semicolon separated list of test parameters.
#>


param([String] $vmName, [String] $hvServer, [String] $testParams)


#
# Checking the input arguments
#
if (-not $vmName)
{
    "Error: VM name cannot be null!"
    exit 100
}

if (-not $hvServer)
{
    "Error: hvServer cannot be null!"
    exit 100
}

if (-not $testParams)
{
    Throw "Error: No test parameters specified"
}


#
# Output test parameters so they are captured in log file
#
"TestParams : '${testParams}'"


#
# Parse the test parameters
#
$rootDir = $null
$sshKey = $null
$ipv4 = $null

$params = $testParams.Split(";")
foreach ($p in $params)
{
    $fields = $p.Split("=")
    switch ($fields[0].Trim())
    {
    "sshKey"       { $sshKey = $fields[1].Trim() }
    "rootDir"      { $rootDir = $fields[1].Trim() }
    "ipv4"         { $ipv4 = $fields[1].Trim() }
    default        {}
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


#
# Source the tcutils.ps1 file
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
$touch_file_commnad = ""

$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj)
{
    Write-Host -F Red "ERROR: Unable to Get-VM with $vmName"
    Write-Output "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
	return $Aborted
}


# Add a disk
$addDisk = New-HardDisk -VM $vmObj -CapacityGB 12 -StorageFormat Thin -Persistence IndependentPersistent


# Get the Guest version
$OS = GetLinuxDistro $ipv4 $sshKey
if ($OS -eq "RedHat6")
{
    $touch_file_commnad = "mkfs.ext4 -F /dev/sdb1&&mount /dev/sdb1 /mnt&&cd /mnt&&dd if=/dev/zero of=11G.img count=1024 bs=11M"
}
elseif ($OS -eq "RedHat7")
{
    $touch_file_commnad = "mkfs.xfs -f /dev/sdb1&&mount /dev/sdb1 /mnt&&cd /mnt&&dd if=/dev/zero of=11G.img count=1024 bs=11M"
}
elseif ($OS -eq "RedHat8")
{
    $touch_file_commnad = "mkfs.xfs -f /dev/sdb1&&mount /dev/sdb1 /mnt&&cd /mnt&&dd if=/dev/zero of=11G.img count=1024 bs=11M"
}
else
{
    Write-Host -F Red "ERROR: Guest OS version isn't belong to test scope"
    Write-Output "ERROR: Guest OS version isn't belong to test scope"
    DisconnectWithVIServer
	return $Aborted
}


# The script in the VM executes fdisk
$guest_script = "fdisk.sh"
$sts =  RunRemoteScript $guest_script
if(-not $sts[-1]){
    Write-Host -F Red "ERROR: Error while running $guest_script"
    Write-Output "ERROR: Error while running $guest_script"
    return $Aborted
}
else
{
    $touchFile=bin\plink.exe -i ssh\${sshKey} root@${ipv4} $touch_file_commnad
    if(-not $touchFile)
    {
        Write-Host -F Red "FAIL: Create the large file failed"
        Write-Output "FAIL: Create the large file failed"
    }
    else
    {
        Write-Host -F Red "PASS: Complete the create of the large file"
        Write-Output "PASS: Complete the create of the large file"
        $retVal=$Passed
    }
}


DisconnectWithVIServer
return $retVal
