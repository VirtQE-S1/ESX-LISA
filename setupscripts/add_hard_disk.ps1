###############################################################################
##
## Description:
##   This script will add hard disk to VM
##
###############################################################################
##
## Revision:
## v1.0.0 - xuli - 01/16/2017 - Draft script for add hard disk.
## v1.0.1 - ruqin - 07/11/2018 - Add a IDE hard disk support
## v1.1.0 - boyang - 08/06/2018 - Fix a return value can't be converted by Invoke-Expression
## v1.2.0 - ruqin - 08/13/2018 - Add DiskDatastore parameter
## v1.3.0 - ruqin - 08/16/2018 - Add NVMe support
## v1.4.0 - ruqin - 08/17/2018 - Multiple disks add support
## v1.5.0 - ldu   - 04/02/2019 - support add LSILogicSAS and LSI Logic Parallel scsi disk
## v1.5.0 - ldu   - 07/20/2019 - support add SCSIController with one disk
## v1.6.0 - ldu   - 09/20/2019 - support add RDM disk to guest.
###############################################################################
<#
.Synopsis
    This script will add hard disk to VM.

.Description
    The script will create .vmdk file, and attach to VM directlly.
    The .xml entry to specify this startup script would be:
    <setupScript>SetupScripts\add_hard_disk.ps1</setupScript>

   The scripts will always pass the vmName, hvServer, and a
   string of testParams from the test definition separated by
   semicolons. The testParams for this script identify DiskType, CapacityGB,
   StorageFormat.

   Where
        DiskType - IDE, SCSI or NVMe
        StorageFormat - The format of new hard disk, can be (Thin, Thick, EagerZeroedThick) (IDE doesn't support this parameter)
        DiskDataStore - The datastore for new disk (IDE disk type not support this parameter)
        CapacityGB - Capacity of the new virtual disk in gigabytes
        Count - The number of disk that we need to add during setup scripts

    A typical XML definition for this test case would look similar
    to the following:


        <testparams>
            <param>DiskType=SCSI</param>
            <param>StorageFormat=Thin</param>
            <param>DiskDataStore=DataStore-97</param>
            <param>CapacityGB=3</param>
            <param>Count=1</param>
        </testparams>

OR


        <testparams>
            <param>DiskType=SCSI,IDE,NVMe</param>
            <param>StorageFormat=Thin,Thin,Thin</param>
            <param>DiskDataStore=DataStore-97,DataStore-97,NVMe</param>
            <param>CapacityGB=3,5,6</param>
            <param>Count=3</param>
        </testparams>



.Parameter vmName
    Name of the VM to add disk.

.Parameter hvServer
    Name of the ESXi server hosting the VM.

.Parameter testParams
    Test data for this test case

.Example
    setupScripts\add_hard_disk
#>


param([String] $vmName, [String] $hvServer, [String] $testParams)
# Checking the input arguments
if (-not $vmName) {
    "Error: VM name cannot be null!"
    exit 1
}

if (-not $hvServer) {
    "Error: hvServer cannot be null!"
    exit 1
}

if (-not $testParams) {
    Throw "Error: No test parameters specified"
}


# Get VM Obj
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj) {
    LogPrint "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
    return $Aborted
}


# Display the test parameters so they are captured in the log file
"TestParams : '${testParams}'"


# Parse the test parameters
$rootDir = $null
$diskType = $null
$storageFormat = $null
$capacityGB = $null
$diskDataStore = $null
$Count = $null
$multipleParams = $false
$type = $null

$params = $testParams.Split(";")
foreach ($p in $params) {
    $fields = $p.Split("=")
    switch ($fields[0].Trim()) {
        "rootDir" { $rootDir = $fields[1].Trim() }
        "DiskType" { $diskType = $fields[1].Trim() }
        "StorageFormat" { $storageFormat = $fields[1].Trim() }
        "CapacityGB" { $capacityGB = $fields[1].Trim() }
        "DiskDataStore" { $diskDataStore = $fields[1].Trim() }
        "Count" { $Count = $fields[1].Trim() }
        "Type" { $type = $fields[1].Trim() }
        default {}
    }
}


if (-not $rootDir) {
    "Warn : no rootdir was specified"
}
else {
    if ( (Test-Path -Path "${rootDir}") ) {
        Set-Location $rootDir
    }
    else {
        "Warn : rootdir '${rootDir}' does not exist"
    }
}


# If not set this para, the default value is 1
if ($null -eq $Count) {
    $Count = 1
}


# Default storageformat is Thin
if ($null -eq $storageFormat) {
    $storageFormat = "Thin" 
}


# Default DiskDatastore is VM's Host
if ($null -eq $diskDataStore) {
    $diskDataStore = $vmObj.ExtensionData.Config.Files.VmPathName.Split(']')[0].TrimStart('[')
}


# Check whether we have multiple opition for params
if ($diskType -like "*,*" -or $capacityGB -like "*,*" -or $diskDataStore -like "*,*") {
    # Split params by comma
    $diskTypeList = $diskType.Split(',')
    $capacityGBList = $capacityGB.Split(',')
    $diskDataStoreList = $diskDataStore.Split(',')
    $storageFormatList = $storageFormat.Split(',')
    # Check the number of params
    if ($diskTypeList.count -ne $Count -or $capacityGBList.count -ne $Count -or $diskDataStoreList.count -ne $Count) {
        LogPrint "ERROR: The number of params is not fit the number fo disk"
        return $Failed
    }
    $multipleParams = $true
}


# Source the tcutils.ps1 file
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

write-host -F red "count is $Count"
$retVal = $Failed
for ($i = 0; $i -lt $Count; $i++) {
    # If we have multiple opition for params
    if ($multipleParams) {
        $diskType = $diskTypeList[$i] 
        $storageFormat = $storageFormatList[$i] 
        $diskDataStore = $diskDataStoreList[$i] 
        $capacityGB = $capacityGBList[$i] 
    }


    # Check storage format params
    if (@("Thin", "Thick", "EagerZeroedThick") -notcontains $storageFormat) {
        LogPrint "Error: Unknown StorageFormat type: $storageFormat"
        return $Aborted
    }


    # Check Disk Type params
    if (@("IDE", "SCSIController", "SCSI", "Parallel", "SAS", "RawPhysical", "NVMe") -notcontains $diskType) {
        LogPrint "Error: Unknown StorageFormat type: $diskType"
        return $Aborted
    }


    # Check Datastore
    $vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
    if (-not $vmObj) {
        LogPrint "ERROR: Unable to Get-VM with $vmName"
        return $Aborted
    }
    $vmDataStore = $vmObj.VMHost | Get-Datastore -Name "*$diskDataStore*"
    $diskDataStore = $vmDataStore.Name
    LogPrint "INFO: Target Datastore is $diskDataStore"
    
    # Add SCSI controller
    if ($diskType -eq "SCSIController") {
        $vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
        if ($null -eq $diskDataStore) {
            $controller = New-HardDisk -CapacityGB $capacityGB -VM $vmObj -StorageFormat $storageFormat | New-ScsiController -Type ParaVirtual -ErrorAction SilentlyContinue
        }
        else {
            LogPrint "Target datastore $diskDataStore"
            $dataStore = Get-Datastore -Name $diskDataStore -VMHost $vmObj.VMHost
            $controller = New-HardDisk -CapacityGB $capacityGB -VM $vmObj -StorageFormat $storageFormat | New-ScsiController -Type ParaVirtual -ErrorAction SilentlyContinue
        }
        if (-not $?) {
            Throw "Error : Cannot add new controller to the VM $vmName"
            return $Failed
        }
        else {
            LogPrint "INFO: Add SCSI controller done."
        }
    }

    # Add SCSI disk
    if ($diskType -eq "SCSI") {
        $vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
        if ($null -eq $diskDataStore) {
            New-HardDisk -CapacityGB $capacityGB -VM $vmObj -StorageFormat $storageFormat -ErrorAction SilentlyContinue
        }
        else {
            LogPrint "Target datastore $diskDataStore"
            $dataStore = Get-Datastore -Name $diskDataStore -VMHost $vmObj.VMHost
            New-HardDisk -CapacityGB $capacityGB -VM $vmObj -Datastore $dataStore -StorageFormat $storageFormat -ErrorAction SilentlyContinue
        }
        if (-not $?) {
            Throw "Error : Cannot add new hard disk to the VM $vmName"
            return $Failed
        }
        else {
            LogPrint "INFO: Add SCSI disk done."
        }
    }

# Add RawPhysical disk
    if ($diskType -eq "RawPhysical") {
        $vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
        # $vmhost = Get-VMHost -Name $hvServer
        $deviceName = (Get-ScsiLun -VMHost $hvserver -CanonicalName "naa.600*")[0].ConsoleDeviceName
        New-HardDisk -VM $vmObj -DiskType RawPhysical -DeviceName $deviceName
        if (-not $?) {
            Throw "Error : Cannot add RawPhysical hard disk to the VM $vmName"
            return $Failed
        }
        else {
            LogPrint "INFO: Add RawPhysical disk done."
        }
    }

#Add LSI Logic SAS scsi disk
    if ($diskType -eq "SAS") {
        $vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
        if ($null -eq $diskDataStore) {
            $vmObj | New-HardDisk -CapacityGB $capacityGB  -StorageFormat $storageFormat | New-ScsiController -Type VirtualLsiLogicSAS
        }
        else {
            LogPrint "Target datastore $diskDataStore"
            $dataStore = Get-Datastore -Name $diskDataStore -VMHost $vmObj.VMHost
            $vmObj | New-HardDisk -CapacityGB $capacityGB -Datastore $dataStore -StorageFormat $storageFormat | New-ScsiController -Type VirtualLsiLogicSAS
        }
        if (-not $?) {
            Throw "Error : Cannot add new hard disk to the VM $vmName"
            return $Failed
        }
        else {
            LogPrint "INFO: Add LSI Logic SAS SCSI disk done."
        }
    }

#Add LSI Logic Parallel scsi disk
    if ($diskType -eq "Parallel") {
        $vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
        if ($null -eq $diskDataStore) {
            $vmObj | New-HardDisk -CapacityGB $capacityGB -StorageFormat $storageFormat | New-ScsiController -Type VirtualLsiLogic -ErrorAction SilentlyContinue
        }
        else {
            LogPrint "Target datastore $diskDataStore"
            $dataStore = Get-Datastore -Name $diskDataStore -VMHost $vmObj.VMHost
            $vmObj | New-HardDisk -CapacityGB $capacityGB -StorageFormat $storageFormat -Datastore $dataStore | New-ScsiController -Type VirtualLsiLogic -ErrorAction SilentlyContinue
        }
        if (-not $?) {
            Throw "Error : Cannot add new  LSI Logic Parallel SCSI hard disk to the VM $vmName"
            return $Failed
        }
        else {
            LogPrint "INFO: Add LSI Logic Parallel SCSI disk done."
        }
    }

    # Add IDE disk
    if ($diskType -eq "IDE") {
        $sts = AddIDEHardDisk -vmName $vmName -hvServer $hvServer -capacityGB $CapacityGB
        if ($sts[-1]) {
            LogPrint "INFO: Add IDE disk done."
        }
        else {
            Throw "Error : Cannot add new hard disk to the VM $vmName"
            return $Failed
        }
    }


    # Add NVMe disk
    if ($diskType -eq "NVMe") {
        $sts = AddNVMeDisk $vmName $hvServer $diskDataStore $capacityGB $storageFormat
        if ($sts[-1]) {
            LogPrint "INFO: Add NVMe disk done. $vmName"
        }
        else {
            Throw "Error : Cannot add new NVMe disk to the VM $vmName"
            return $Failed
        }
    }
}


$retVal = $Passed
return $retVal
