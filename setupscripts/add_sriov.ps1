###############################################################################
##
## Description:
## Add sriov nic 
##
###############################################################################
##
## Revision:
## V1.0.0 - ruqin - 8/8/2018 - Build the script
##
###############################################################################
<#
.Synopsis
    Add sriov nic

.Description
    Add sriov nic in setup phrase

.Parameter vmName
    Name of the test VM

.Parameter hvServer
    Name of the Hyper-V server hosting the VM.

.Parameter testParams
    Semicolon separated list of test parameters
#>

param([String] $vmName, [String] $hvServer, [String] $testParams)
#
# Checking the input arguments
#
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

#
# Display the test parameters so they are captured in the log file
#
"TestParams : '${testParams}'"

#
# Parse the test parameters
#
$rootDir = $null
$sriovNum = $null

$params = $testParams.Split(";")
foreach ($p in $params) {
    $fields = $p.Split("=")
    switch ($fields[0].Trim()) {
        "rootDir" { $rootDir = $fields[1].Trim() }
        "sriovNum" { $sriovNum = $fields[1].Trim() }
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
if ($null -eq $sriovNum) {
    $sriovNum = 1
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
if (-not $vmObj) {
    Write-Error -Message "CheckModules: Unable to create VM object for VM $vmName" -Category ObjectNotFound -ErrorAction SilentlyContinue
    DisconnectWithVIServer
    return $Aborted
}


# Lock all memory
try {
    $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
    $spec.memoryReservationLockedToMax = $true
    (Get-VM $vmObj).ExtensionData.ReconfigVM_Task($spec)
}
catch {
    # Printout Error message
    $ErrorMessage = $_ | Out-String
    LogPrint "ERROR: Lock all memory error"
    LogPrint $ErrorMessage
    return $Aborted
}

try {
    # Get Switch Info
    $DVS = Get-VDSwitch -VMHost $vmObj.VMHost
    
    # This is hard code DPortGroup Name (6.0 6.5 6.7) This may change
    $PG = $DVS | Get-VDPortgroup -Name "DPortGroup"

    # Add new nic into config file
    $Spec = New-Object VMware.Vim.VirtualMachineConfigSpec
    $Dev = New-Object Vmware.Vim.VirtualDeviceConfigSpec
    $Dev.Operation = "add" 
    $Dev.Device = New-Object VMware.Vim.VirtualSriovEthernetCard
    $Spec.DeviceChange += $dev
    $Spec.DeviceChange.Device.Backing = New-Object VMware.Vim.VirtualEthernetCardDistributedVirtualPortBackingInfo
    $Spec.DeviceChange.Device.Backing.Port = New-Object VMware.Vim.DistributedVirtualSwitchPortConnection
    
    # This is currently unknown function
    $Spec.DeviceChange.Device.Backing.Port.PortgroupKey = $PG.Key
    $Spec.DeviceChange.Device.Backing.Port.SwitchUuid = $DVS.Key

    # Apply new config
    $View = Get-View -ViewType VirtualMachine -Filter @{"Name" = "$vmName"} -Property Name, Runtime.Powerstate
    $View.ReconfigVM($Spec)
}
catch {
    # Printout Error message
    $ErrorMessage = $_ | Out-String
    LogPrint "ERROR: SRIOV config error"
    LogPrint $ErrorMessage
    return $Aborted
}


# Get Sriov PCI Device (like 00000:007:00.0)
try {
    $vmHost = Get-VMHost -Name $hvServer  
    # This may fail, you can try to delete -V2 param
    $esxcli = Get-EsxCli -VMHost $vmHost -V2
    $pciDevice = $esxcli.network.sriovnic.list.Invoke() | Select-Object -ExpandProperty "PCIDevice"
}
catch {
    # Printout Error message
    $ErrorMessage = $_ | Out-String
    LogPrint "ERROR: Get PCI Device error"
    LogPrint $ErrorMessage
    return $Aborted
}
if ($null -eq $pciDevice) {
    LogPrint "ERROR: Cannot get PCI Device" 
    return $Aborted
}
LogPrint "INFO: PCI Device is $pciDevice"


# Refresh vmView
$vmView = Get-vm $vmObj | Get-View

# Change config pfId and Id to required PCI Device
$vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
$pfID = New-Object VMware.Vim.optionvalue
$passID = New-Object VMware.Vim.optionvalue 
# Find correct pci key  this will like "pciPassthru15"
$pfID.Key = ($vmView.Config.ExtraConfig | Where-Object { $_.Key -like "pciPassthru*.pfid"})[-1] | Select-Object -ExpandProperty "key"
$pfID.Value = $pciDevice

$passID.Key = ($vmView.Config.ExtraConfig | Where-Object { $_.Key -like "pciPassthru*.id"})[-1] | Select-Object -ExpandProperty "key"
$passID.Value = $pciDevice

if ($passID.Key -notlike "pciPassthru*.id" -or $pfID.Key -notlike "pciPassthru*.pfid") {
    LogPrint "ERROR: Config key failed: passID $passID.Key, pfID $pfID.Key" 
    return $Failed
}

# Add extra into config
$vmConfigSpec.ExtraConfig += $pfID
$vmConfigSpec.ExtraConfig += $passID

# Applay new config
$vmView.ReconfigVM($vmConfigSpec)    


# Refresh vm
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj) {
    Write-Error -Message "CheckModules: Unable to create VM object for VM $vmName" -Category ObjectNotFound -ErrorAction SilentlyContinue
    DisconnectWithVIServer
    return $Aborted
}

# Set Network to VM Network "VM Network" is hard code
$nics = Get-NetworkAdapter -VM $vmObj
$nicMacAddress = ($vmView.Config.ExtraConfig | Where-Object { $_.Key -like "pciPassthru*.generatedMACAddress"})[-1].Value
foreach ($nic in $nics) {
    if ($nic.MacAddress -eq $nicMacAddress) {
        Set-NetworkAdapter -NetworkAdapter $nic -NetworkName "VM Network" -Confirm:$false
    } 
}



# Refresh vm
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj) {
    Write-Error -Message "CheckModules: Unable to create VM object for VM $vmName" -Category ObjectNotFound -ErrorAction SilentlyContinue
    DisconnectWithVIServer
    return $Aborted
}


# Refresh vmView
$vmView = Get-vm $vmObj | Get-View

# Check vmx value
$valueID = ($vmView.Config.ExtraConfig | Where-Object { $_.Key -like "pciPassthru*.id"})[-1] | Select-Object -ExpandProperty "Value"
$valuepfID = ($vmView.Config.ExtraConfig | Where-Object { $_.Key -like "pciPassthru*.pfid"})[-1] | Select-Object -ExpandProperty "Value"
LogPrint $valuepfID.Trim('0')
LogPrint $valueID.Trim('0')
Logprint $pciDevice.Trim('0')

if ( ($pciDevice.Split(":")[1].Trim("0") -ne $valueID.Split(":")[1].Trim("0")) -or ($pciDevice.Split(":")[1].Trim("0") -ne $valuepfID.Split(":")[1].Trim("0")) ) {
    LogPrint "Error: Add extra config failed"    
    return $Failed
}

$retVal = $Passed
return $retVal
