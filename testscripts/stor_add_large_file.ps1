###############################################################################
##
## Description:
##   add a disk,do partition and formtion(xfs in rhel7,ext4 in rhel6),
##   then creat a 11g file
##   
###############################################################################
##
## Revision:
## v1.0 - junfwang - 03/19/2018 -Build script
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
    exit
}

if (-not $hvServer)
{
    "Error: hvServer cannot be null!"
    exit
}

if (-not $testParams)
{
    Throw "Error: No test parameters specified"
}

#
# Display the test parameters so they are captured in the log file
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
#
# Confirm VM
#
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj){
    Write-Error -Message "CheckModules: Unable to create VM object for VM $vmName" -Category ObjectNotFound -ErrorAction SilentlyContinue
    DisconnectWithVIServer
    exit 1
}
#add disk
$addDisk=New-HardDisk -VM $vmObj -CapacityGB 12 -StorageFormat Thin -Persistence IndependentPersistent
#get linux version
$OS = GetLinuxDistro  $ipv4 $sshKey
if ($OS -eq "RedHat7")
{
    $guest_script = "fdisk.sh"
    $sts =  RunRemoteScript $guest_script
    if( -not $sts[-1] ){
        write-output "Error: Error while running $guest_script"
        $retVal=$Aborted
    }
    else{
    #creat file
    $touchFile=bin\plink.exe -i ssh\${sshKey} root@${ipv4} "mkfs.xfs -F /dev/sdb1&&mount /dev/sdb1 /mnt&&cd /mnt&&dd if=/dev/zero of=11G.img count=1024 bs=11M" 
      if(-not $touchFile){
        write-output "Error: Error while dd"
        $retVal=$Failed
      } 
      else{
        $retVal=$Passed
      }    
    }
}
if ($OS -eq "RedHat6")
{
    $guest_script = "fdisk.sh"
    $sts =  RunRemoteScript $guest_script
    if( -not $sts[-1] ){
        write-output "Error: Error while running $guest_script"
        $retVal=$Aborted
    }
    else{
      #creat file
      $touchFile=bin\plink.exe -i ssh\${sshKey} root@${ipv4} "mkfs.ext4 -F /dev/sdb1&&mount /dev/sdb1 /mnt&&cd /mnt&&dd if=/dev/zero of=11G.img count=1024 bs=11M"
      if(-not $touchFile){
        write-output "Error: Error while dd"
        $retVal=$Failed
      } 
      else{
        $retVal=$Passed
      }    
    }
}
DisconnectWithVIServer
return $retVal
