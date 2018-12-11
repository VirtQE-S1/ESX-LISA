###############################################################################
##
## Description:
##  Test with ibv_rc_pingpong, perf and rping between 2 Guests on the same Hosts
##
## Revision:
##  v1.0.0 - ldu - 12/04/2018 - Build the script
##
###############################################################################


<#
.Synopsis
    Test with ibv_rc_pingpong, perf and rping between 2 Guests on the different Hosts

.Description


.Parameter vmName
    Name of the test VM.

.Parameter testParams
    Semicolon separated list of test parameters.
#>


param([String] $vmName, [String] $hvServer, [String] $testParams)


#
# Checking the input arguments
#
if (-not $vmName) {
    "Error: VM name cannot be null!"
    exit 100
}

if (-not $hvServer) {
    "Error: hvServer cannot be null!"
    exit 100
}

if (-not $testParams) {
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
$dstHost6_7 = $null
$dstHost6_5 = $null
$dstDatastore = $null

$params = $testParams.Split(";")
foreach ($p in $params) {
    $fields = $p.Split("=")
    switch ($fields[0].Trim()) {
        "sshKey" { $sshKey = $fields[1].Trim() }
        "rootDir" { $rootDir = $fields[1].Trim() }
        "ipv4" { $ipv4 = $fields[1].Trim() }
        "dstHost6.7" { $dstHost6_7 = $fields[1].Trim()}
        "dstHost6.5" { $dstHost6_5 = $fields[1].Trim()}
        "dstDatastore" { $dstDatastore = $fields[1].Trim() }
        "tool" { $tool = $fields[1].Trim() }
        default {}
    }
}


#
# Check all parameters are valid
#
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


if ($null -eq $sshKey) {
    "FAIL: Test parameter sshKey was not specified"
    return $False
}


if ($null -eq $ipv4) {
    "FAIL: Test parameter ipv4 was not specified"
    return $False
}


if ($null -eq $dstDatastore) {
    "FAIL: Test parameter dstDatastore was not specified"
    return $False 
}


if (-not $dstHost6_7 -or -not $dstHost6_5) {
    "INFO: dstHost 6.7 is $dstHost6_7"
    "INFO: dstHost 6.5 is $dstHost6_5"
    "Warn : dstHost was not specified"
    return $false
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
# ############################################################################### 


$retVal = $Failed
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj) {
    LogPrint "ERROR: Unable to Get-VM with $vmName"
    DisconnectWithVIServer
    return $Aborted
}


# Specify dst host
$dstHost = FindDstHost -hvServer $hvServer -Host6_5 $dstHost6_5 -Host6_7 $dstHost6_7
if ($null -eq $dstHost) {
    LogPrint "ERROR: Cannot find required Host"    
    DisconnectWithVIServer
    return $Aborted
}
LogPrint "INFO: Destination Host is $dstHost"


# Get the Guest version
$DISTRO = GetLinuxDistro ${ipv4} ${sshKey}
LogPrint "DEBUG: DISTRO: $DISTRO"
if (-not $DISTRO) {
    LogPrint "ERROR: Guest OS version is NULL"
    DisconnectWithVIServer
    return $Aborted
}
LogPrint "INFO: Guest OS version is $DISTRO"


# Different Guest DISTRO
if ($DISTRO -ne "RedHat7" -and $DISTRO -ne "RedHat8" -and $DISTRO -ne "RedHat6") {
    LogPrint "ERROR: Guest OS ($DISTRO) isn't supported, MUST UPDATE in Framework / XML / Script"
    DisconnectWithVIServer
    return $Skipped
}

# Start another VM
$GuestBName = $vmObj.Name.Split('-')
# Get another VM by change Name
$GuestBName[-1] = "B"
$GuestBName = $GuestBName -join "-"
$GuestB = Get-VMHost -Name $hvServer | Get-VM -Name $GuestBName


# Add RDMA NIC for Guest B
$status = AddPVrdmaNIC $GuestBName $hvServer
if ( -not $status[-1]) {
    LogPrint "ERROR: RDMA NIC adds failed" 
    DisconnectWithVIServer
    return $Aborted
}


# Start GuestB
Start-VM -VM $GuestB -Confirm:$false -RunAsync:$true -ErrorAction SilentlyContinue
if (-not $?) {
    LogPrint "ERROR : Cannot start VM"
    DisconnectWithVIServer
    return $Aborted
}


# Wait for GuestB SSH ready
if ( -not (WaitForVMSSHReady $GuestBName $hvServer $sshKey 300)) {
    LogPrint "ERROR : Cannot start SSH"
    DisconnectWithVIServer
    return $Aborted
}
LogPrint "INFO: Ready SSH"


# Get another VM IP addr
$ipv4Addr_B = GetIPv4 -vmName $GuestBName -hvServer $hvServer
$GuestB = Get-VMHost -Name $hvServer | Get-VM -Name $GuestBName


# Find out new add RDMA nic for Guest B
$nics += @($(FindAllNewAddNIC $ipv4Addr_B $sshKey))
if ($null -eq $nics) {
    LogPrint "ERROR: Cannot find new add RDMA NIC" 
    DisconnectWithVIServer
    return $Failed
}
else {
    $rdmaNIC = $nics[-1]
}
LogPrint "INFO: New NIC is $rdmaNIC"


# Config RDMA NIC IP addr for Guest B
$IPAddr_guest_B = "172.31.1." + (Get-Random -Maximum 254 -Minimum 125)
if ( -not (ConfigIPforNewDevice $ipv4Addr_B $sshKey $rdmaNIC ($IPAddr_guest_B + "/24"))) {
    LogPrint "ERROR : Guest B Config IP Failed"
    DisconnectWithVIServer
    return $Failed
}
LogPrint "INFO: Guest B RDMA NIC IP add is $IPAddr_guest_B"


# Find out new add RDMA nic for Guest A
$nics += @($(FindAllNewAddNIC $ipv4 $sshKey))
if ($null -eq $nics) {
    LogPrint "ERROR: Cannot find new add rdma NIC" 
    DisconnectWithVIServer
    return $Failed
}
else {
    $rdmaNIC = $nics[-1]
}
LogPrint "INFO: New NIC is $rdmaNIC"


# Config RDMA NIC IP addr for Guest A
$IPAddr_guest_A = "172.31.1." + (Get-Random -Maximum 124 -Minimum 2)
if ( -not (ConfigIPforNewDevice $ipv4 $sshKey $rdmaNIC ($IPAddr_guest_A + "/24"))) {
    LogPrint "ERROR : Guest A Config IP Failed"
    DisconnectWithVIServer
    return $Failed
}
LogPrint "INFO: Guest A RDMA NIC IP add is $IPAddr_guest_A"


# Check can we ping GuestA from GuestB via RDMA NIC
$Command = "ping $IPAddr_guest_A -c 10 -W 15  | grep ttl > /dev/null"
$status = SendCommandToVM $ipv4Addr_B $sshkey $command
if (-not $status) {
    LogPrint "ERROR : Ping test Failed"
    $retVal = $Failed
}
else {
       LogPrint "Pass : Ping test passed"
}


#For RHEL8 and RHEL7 install different package.
if ($DISTRO -eq "RedHat8") {
    $command1 = "yum install -y opensm rdma libibverbs librdmacm librdmacm-utils ibacm libibverbs-utils infiniband-diags perftest qperf libcxgb4 libmlx4 libmlx5 rdma-core"
}
else {
    $command1 = "yum install -y opensm rdma libibverbs librdmacm librdmacm-utils ibacm libibverbs-utils infiniband-diags ibutils perftest qperf infinipath-psm libcxgb3 libcxgb4 libehca libipathverbs libmthca libmlx4 libmlx5 libnes libocrdma dapl dapl-devel dapl-utils dapl dapl-devel dapl-utils"
}

#install dependency package on guest B.
$status = SendCommandToVM $ipv4Addr_B $sshkey $command1
if (-not $status) {
    LogPrint "ERROR : install package Failed"
    return $Aborted
}
#load ib related modules
$command2 = "modprobe ib_umad"
$status = SendCommandToVM $ipv4Addr_B $sshkey $command2
if (-not $status) {
    LogPrint "ERROR : load modules Failed"

    return $Aborted
}

#install dependency package on guest A.
$status = SendCommandToVM $ipv4 $sshkey $command1
if (-not $status) {
    LogPrint "ERROR : install package Failed"
    
    return $Aborted
}

#load ib related modules
$status = SendCommandToVM $ipv4 $sshkey $command2
if (-not $status) {
    LogPrint "ERROR : load modules Failed"
    
    return $Aborted
}

#check the test tools used for test.
LogPrint "test is $tool"
write-host -F Red "Test tool is $tool"
if ( $tool -eq "perf" )
{
  #array for perftest command
  $perf_guestB = @("ib_send_lat -x 0 -a","ib_send_bw -x 0 -a","ib_read_lat -x 0 -a","ib_read_bw -x 0 -a","ib_write_lat -x 0 -a","ib_write_bw -x 0 -a" )
  $perf_guestA = @("ib_send_lat -x 0 -a $IPAddr_guest_B","ib_send_bw -x 0 -a $IPAddr_guest_B","ib_read_lat -x 0 -a $IPAddr_guest_B","ib_read_bw -x 0 -a $IPAddr_guest_B","ib_write_lat -x 0 -a $IPAddr_guest_B","ib_write_bw -x 0 -a $IPAddr_guest_B" )

  foreach($i in $perf_guestB)
  {
      $Process = Start-Process bin\plink -ArgumentList "-i ssh\${sshKey} root@${ipv4Addr_B} ${i}" -PassThru -WindowStyle Hidden
      write-host -F Red "the process1 id is $($Process.id) and $i"
      $index = $perf_guestB.IndexOf($i)
      $commandA = $perf_guestA[$index]
      $status = SendCommandToVM $ipv4 $sshkey $commandA
      if (-not $status) {
          LogPrint "ERROR : $commandA test Failed"
          return $Failed
      } else {
          $retVal = $Passed
          LogPrint "pass : $commandA test passed"
      }
  }
}
else
{
  if ( $tool -eq "ibvrc" )
    {
        $commandA = "ibv_rc_pingpong -s 1 -g 1 $IPAddr_guest_B"
        $commandB = "ibv_rc_pingpong -s 1 -g 1"
    }
  else
  {
      $commandA = "rping -c -a $IPAddr_guest_B -v -C 1"
      $commandB = "rping -s -v -V -C 1 -a $IPAddr_guest_B"
  }

  #Run test on guest B first,because guest B is test as server.
  $Process1 = Start-Process bin\plink -ArgumentList "-i ssh\${sshKey} root@${ipv4Addr_B} ${commandB}" -PassThru -WindowStyle Hidden
  write-host -F Red "$($Process1.id)"

  #Then run test on guest A, guest A as client.
  $a = "touch /root/aa"
  $status = SendCommandToVM $ipv4 $sshkey $a
  $status = SendCommandToVM $ipv4 $sshkey $commandA
  if (-not $status) {
      LogPrint "ERROR :  test $commandA test Failed"
      DisconnectWithVIServer
      $retVal = $Failed
  } else {
      $retVal = $Passed
      LogPrint "pass :  test $commandA test passed"
  }
  
}


DisconnectWithVIServer
return $retVal
