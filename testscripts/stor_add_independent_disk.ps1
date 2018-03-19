###############################################################################
##
## Description: 
##  This scripts add a independent disk and take snapshot, after touch a file
##  in the new disk restore snapshot,file should still in the disk  
##  
###############################################################################
## 
## Revision:
## v1.0 - junfwang - 02/01/2018
##
###############################################################################

<#
.Synopsis
    This scripts add a independent disk and take snapshot, after touch a file
    in the new disk restore snapshot,file should still in the disk
.Description
 <test>
     <testName>stor_add_independent_disk</testName>      
     <testID>ESX-STOR-009/testID>
     <testScript>testScripts\stor_add_independent_disk.ps1</testScript>
     <files>remote-scripts/utils.sh,remote-scripts/fdisk.sh </files>
     <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
     <timeout>200</timeout>
     <testparams>
            <param>TC_COVERED=RHEL6-38502,RHEL7-80230</param>
     </testparams>
     <onError>Continue</onError>
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
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj){
    Write-Error -Message "CheckModules: Unable to create VM object for VM $vmName" -Category ObjectNotFound -ErrorAction SilentlyContinue
    DisconnectWithVIServe
    exit
}
#add disk
$addDisk=New-HardDisk -VM $vmObj -CapacityGB 3 -StorageFormat Thin -Persistence IndependentPersistent
#take snapshot before touch file
$takeSnapshot=New-Snapshot -VM $vmObj -Name 'blank disk'-Description "snapshot with memory" -Memory:$false -Quiesce:$true -Confirm:$false
write-host -F Red "$takeSnapshot"
#do partition and formation
$guest_script = "fdisk.sh"
$sts =  RunRemoteScript $guest_script
#touch file
$touchFile=bin\plink.exe -i ssh\${sshKey} root@${ipv4} "mount /dev/sdb1 /mnt&&cd /mnt&&touch testindependent"
#restore snapshot
$restoreSnapshot = Set-VM -VM $vmObj -Snapshot $newSPName -Confirm:$false
#check file in added disk
$mountDisk=bin\plink.exe -i ssh\${sshKey} root@${ipv4} "mount /dev/sdb1 /mnt"
$checkFile=bin\plink.exe -i ssh\${sshKey} root@${ipv4} "find /mnt -name testindependent"
#remove snapshot
$remove = Remove-Snapshot -Snapshot $takeSnapshot  -RemoveChildren -Confirm:$false
if($checkFile -ne $null){
    $retVal=$Passed
}
"Info :.ps1 script completed"
DisconnectWithVIServer
return $retVal
   
