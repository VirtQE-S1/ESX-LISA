########################################################################################
##
## ___________ _____________  ___         .____    .___  _________   _____
## \_   _____//   _____/\   \/  /         |    |   |   |/   _____/  /  _  \
##  |    __)_ \_____  \  \     /   ______ |    |   |   |\_____  \  /  /_\  \
##  |        \/        \ /     \  /_____/ |    |___|   |/        \/    |    \
## /_______  /_______  //___/\  \         |_______ \___/_______  /\____|__  /
##         \/        \/       \_/                 \/           \/         \/
##
########################################################################################
##
## ESX-LISA is an automation testing framework based on github.com/LIS/lis-test
## project. In order to support ESX, ESX-LISA uses PowerCLI to automate all
## aspects of vSphere maagement, including network, storage, VM, guest OS and
## more. This framework automates the tasks required to test the
## Redhat Enterprise Linux Server on WMware ESX Server.
##
########################################################################################
##
## Revision:
##  v1.0.0 - xiaofwan - 11/25/2016 - Fork from github.com/LIS/lis-test
##  v1.1.0 - xiaofwan - 12/28/2016 - Add GetLinuxDsitro method.
##  v1.2.0 - xiaofwan - 01/06/2017 - Add PowerCLIImport; DisconnectWithVIServer
##  v1.3.0 - hhei     - 01/10/2017 - Add CheckModule function
##  v1.4.0 - xiaofwan - 01/25/2016 - Add four test result states
##  v1.5.0 - xiaofwan - 02/28/2016 - Add WaitForVMSSHReady
##  v1.6.0 - ruqin    - 07/06/2018  - Add GetModuleVersion
##  v1.7.0 - ruqin    - 07/27/2018 - Add RevertSnapshotVM
##  v1.8.0 - boyang    - 10/15/2019 - Add SkipTestInHost
##  v1.9.0 - ldu      - 01/02/2020 - add RemoveVM function
########################################################################################


<#
.Synopsis
    Utility functions for test case scripts.

.Description
    Test Case Utility functions.  This is a collection of function
    commonly used by PowerShell test case scripts and setup scripts.
#>


#
# test result codes
#
New-Variable Passed              -value "Passed"              -option ReadOnly
New-Variable Skipped             -value "Skipped"             -option ReadOnly
New-Variable Aborted             -value "Aborted"             -option ReadOnly
New-Variable Failed              -value "Failed"              -option ReadOnly


########################################################################################
# PowerCLIImport
########################################################################################
function PowerCLIImport () {
   <#
    .Description
        Import VMware.VimAutomation.Core module if it does not exist.
    #>
    $modules = Get-Module

    $foundVimautomation = $false
    foreach($module in $modules)
    {
        if($module.Name -eq "VMware.VimAutomation.Core")
        {
            "INFO: PowerCLI module VMware.VimAutomation.Core already exists."
            $foundVimautomation = $true
            break
        }
    }

    if (-not $foundVimautomation)
    {
        Import-Module VMware.VimAutomation.Core
    }
}


########################################################################################
# ConnectToVIServer
########################################################################################
function ConnectToVIServer ([string] $visIpAddr,
                            [string] $visUsername,
                            [string] $visPassword,
                            [string] $visProtocol)
{
    <#
    .Description
        Connect with VSphere VI Server if connnect does not exist.
    .Parameter visIpAddr
        REQUIRED
        VI Server IP address
        Type : [String]
    .Parameter visUsername
        REQUIRED
        VI Server login username
        Type : [String]
    .Parameter visPassword
        REQUIRED
        VI Server login password
        Type : [String]
    .Parameter visProtocol
        REQUIRED
        VI Server login method, such as HTTP or HTTPS.
        Type : [String]
    .Example
        ConnectToVIServer <visIpAddr> <visUsername> <visPassword> <visProtocol>
    #>
    
    # Verify the VIServer related environment variable existed.
    if (-not $visIpAddr)
    {
        "ERROR : vCenter IP address is not configured, it is required."
        exit
    }

    if (-not $visUsername)
    {
        "ERROR : vCenter login username is not configured, it is required."
        exit
    }

    if (-not $visPassword)
    {
        "ERROR : vCenter login password is not configured, it is required."
        exit
    }

    if (-not $visProtocol)
    {
        "ERROR : vCenter connection method is not configured, it is required."
        exit
    }

    # Check the PowerCLI package installed
    Get-PowerCLIVersion | out-null
    if (-not $?)
    {
        "ERROR : Please install VMWare PowerCLI package."
        exit
    }

    if (-not $global:DefaultVIServer)
    {
        "INFO : Connecting with VIServer $visIpAddr."
        Connect-VIServer -Server $visIpAddr `
                         -Protocol $visProtocol `
                         -User $visUsername `
                         -Password $visPassword `
                         -Force | Out-Null
        if (-not $?)
        {
            "ERROR : Cannot connect with vCenter with $visIpAddr " +
            "address, $visProtocol protocol, username $visUsername, " +
            "and password $visPassword."
            exit
        }
        "DEBUG: vCenter connected with " +
        "session id $($global:DefaultVIServer.SessionId)"
    }
    else
    {
        "INFO : vCenter connected already! " +
        "Session id: $($global:DefaultVIServer.SessionId)"
    }
}


########################################################################################
# DisconnectWithVIServer
########################################################################################
function DisconnectWithVIServer ()
{
    <#
    .Description
        Disconnect with VSphere VI Server to close TCP session.
    .Example
        DisconnectWithVIServer
    #>

    # Disconnect with vCenter if there's a connection.
    if ($global:DefaultVIServer)
    {
        foreach ($viserver in $global:DefaultVIServer)
        {
            "INFO : Disconnect with VIServer $($viserver.name)."
            Disconnect-VIServer -Server $viserver -Force -Confirm:$false
            "INFO : Disconnect with VIServer $($viserver.name) done."
        }
    }
    else
    {
        "INFO : There is not session to VI Server exist."
    }
}


########################################################################################
# GetLinuxDsitro()
########################################################################################
function GetLinuxDistro([String] $ipv4, [String] $sshKey)
{
    <#
    .Synopsis
        Get Linux Distro INFO from a Linux VM.
    .Description
        Use SSH to het Linux Distro INFO from a Linux VM.
    .Parameter ipv4
        IPv4 address of the Linux VM.
    .Parameter sshKey
        Name of the SSH private key to use. This script assumes the key is located
        in the directory with a relative path of: .\ssh
    .Example
        GetLinuxDistro "192.168.1.101" "rhel5_id_rsa.ppk"
    #>

    if (-not $ipv4)
    {
        Write-ERROR -Message "IPv4 address is null" -Category InvalidData -ERRORAction SilentlyContinue
        return $null
    }

    if (-not $sshKey)
    {
        Write-ERROR -Message "SSHKey is null" -Category InvalidData -ERRORAction SilentlyContinue
        return $null
    }

    $distro = bin\plink -batch -i ssh\${sshKey} root@${ipv4} "grep -Ehs 'Ubuntu|SUSE|Fedora|Debian|CentOS|Red Hat Enterprise Linux (Server |)release [0-9]{1,2}.[0-9]{1,2}|Oracle' /etc/{issue,*release,*version}"
	Write-Host -F red "Debug: distro: $distro"
    if (-not $distro)
    {
        Write-ERROR -Message "Return value is null" -Category InvalidData -ERRORAction SilentlyContinue
        return $null
    }

    $linuxDistro = "undefined"

    switch -wildcard ($distro)
    {
        "*Ubuntu*"  {  $linuxDistro = "Ubuntu"
                       break
                    }
        "*CentOS*"  {  $linuxDistro = "CentOS"
                       break
                    }
        "*Fedora*"  {  $linuxDistro = "Fedora"
                       break
                    }
        "*SUSE*"    {  $linuxDistro = "SUSE"
                       break
                    }
        "*Debian*"  {  $LinuxDistro = "Debian"
                       break
                    }
        "*Red Hat Enterprise Linux Server release 7.*" {  $linuxDistro = "RedHat7"
                       break
                    }
        "*Red Hat Enterprise Linux Server release 6.*" {  $linuxDistro = "RedHat6"
                       break
                    }
        "*Red Hat Enterprise Linux release 8.*" {  $linuxDistro = "RedHat8"
                       break
                    }					
        "*Red Hat Enterprise Linux release 9.*" {  $linuxDistro = "RedHat9"
                       break
                    }					
        "*Oracle*" {  $linuxDistro = "Oracle"
                       break
                    }
        default     {  $linuxDistro = "Unknown"
                       break
                    }
    }

    return ${linuxDistro}
}


########################################################################################
# GetFileFromVM()
########################################################################################
function GetFileFromVM([String] $ipv4, [String] $sshKey, [string] $remoteFile, [string] $localFile)
{
    <#
    .Synopsis
        Copy a file from a Linux VM.
    .Description
        Use SSH to copy a file from a Linux VM.
    .Parameter ipv4
        IPv4 address of the Linux VM.
    .Parameter sshKey
        Name of the SSH key to use. This script assumes the key is located
        in the directory with a relative path of: .\ssh
    .Parameter remoteFile
        Name of the file on the Linux VM.
    .Parameter localFile
        Name to give the file when it is copied to the localhost.
    .Example
        GetFileFromVM "192.168.1.101" "rhel5_id_rsa.ppk" "state.txt" "remote_state.txt"
    #>

    $retVal = $false

    if (-not $ipv4)
    {
        Write-ERROR -Message "IPv4 address is null" -Category InvalidData -ERRORAction SilentlyContinue
        return $false
    }

    if (-not $sshKey)
    {
        Write-ERROR -Message "SSHKey is null" -Category InvalidData -ERRORAction SilentlyContinue
        return $false
    }

    if (-not $remoteFile)
    {
        Write-ERROR -Message "remoteFile is null" -Category InvalidData -ERRORAction SilentlyContinue
        return $false
    }

    if (-not $localFile)
    {
        Write-ERROR -Message "localFile is null" -Category InvalidData -ERRORAction SilentlyContinue
        return $false
    }

    $process = Start-Process bin\pscp -ArgumentList "-batch -i ssh\${sshKey} root@${ipv4}:${remoteFile} ${localFile}" -PassThru -NoNewWindow -Wait -redirectStandardOutput lisaOut.tmp -redirectStandardERROR lisaErr.tmp
    if ($process.ExitCode -eq 0)
    {
        $retVal = $true
    }
    else
    {
        Write-ERROR -Message "Unable to get file '${remoteFile}' from ${ipv4}" -Category ConnectionERROR -ERRORAction SilentlyContinue
        return $false
    }

    Remove-Item lisaOut.tmp -ERRORAction "SilentlyContinue"
    Remove-Item lisaErr.tmp -ERRORAction "SilentlyContinue"

    return $retVal
}


#######################################################################
#
# GetIPv4ViaPowerCLI()
#
# Description:
#    Look at the IP addresses on each NIC the VM has. For each
#    address, see if it in IPv4 address and then see if it is
#    reachable via a ping.
#
#######################################################################
function GetIPv4ViaPowerCLI([String] $vmName, [String] $hvServer)
{
    <#
    .Synopsis
        Use the PowerCLI cmdlets to retrieve a VMs IPv4 address.
    .Description
        Look at the IP addresses on each NIC the VM has.  For each
        address, see if it in IPv4 address and then see if it is
        reachable via a ping.
    .Parameter vmName
        Name of the VM to retrieve the IP address from.
    .Parameter hvServer
        ESXi host IP address
    .Example
        GetIpv4ViaPowerCLI $testVMName $hvServer
    #>

    $vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
    if (-not $vmObj)
    {
        Write-ERROR -Message "GetIPv4ViaPowerCLI: Unable to create VM object for VM $vmName" -Category ObjectNotFound -ERRORAction SilentlyContinue
        return $null
    }

    $vmguestOut = Get-VMGuest -VM $vmObj
    if (-not $vmguestOut)
    {
        Write-ERROR -Message "GetIPv4ViaPowerCLI: Unable to create VM object for VM $vmName" -Category ObjectNotFound -ERRORAction SilentlyContinue
        return $null
    }
    $ipAddresses = $vmguestOut.IPAddress
    if (-not $ipAddresses)
    {
        Write-ERROR -Message "GetIPv4ViaPowerCLI: No network adapters found on VM $vmName" -Category ObjectNotFound -ERRORAction SilentlyContinue
        return $null
    }
    foreach ($address in $ipAddresses)
    {
        # Ignore address if it is not an IPv4 address
        $addr = [IPAddress] $address
        if ($addr.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork)
        {
            Continue
        }

        # Ignore address if it a loopback address
        if ($address.StartsWith("127."))
        {
            Continue
        }

        # See if it is an address we can access
        $ping = New-Object System.Net.NetworkINFOrmation.Ping
        $sts = $ping.Send($address)
        if ($sts -and $sts.Status -eq [System.Net.NetworkINFOrmation.IPStatus]::Success)
        {
            return $address
        }
    }

    Write-ERROR -Message "GetIPv4ViaPowerCLI: No IPv4 address found on any NICs for VM ${vmName}" -Category ObjectNotFound -ERRORAction SilentlyContinue
    return $null
}



########################################################################################
# GetIPv4()
########################################################################################
function GetIPv4([String] $vmName, [String] $hvServer)
{
    <#
    .Synopsis
        Retrieve the VMs IPv4 address
    .Description
        Try the various methods to extract an IPv4 address from a VM.
    .Parameter vmName
        Name of the VM to retrieve the IP address from.
    .Parameter hvServer
       IP address of host the VM located
    .Example
        GetIPv4 $testVMName $hvServer
    #>

    $errMsg = $null
    $addr = GetIPv4ViaPowerCLI $vmName $hvServer
    if (-not $addr)
    {
        $errMsg += ("`n" + $ERROR[0].Exception.Message)
        Write-ERROR -Message ("GetIPv4: Unable to determine IP address for VM ${vmName}`n" + $errmsg) -Category ReadERROR -ERRORAction SilentlyContinue
        return $null
    }

    return $addr
}


#######################################################################
#
# GenerateIpv4()
#
#######################################################################
function GenerateIpv4($tempipv4, $oldipv4)
{
    <#
    .Synopsis
        Generates an unused IP address based on an old IP address.
    .Description
        Generates an unused IP address based on an old IP address.
    .Parameter tempipv4
        The ipv4 address on which the new ipv4 will be based and generated in the same subnet
    .Example
        GenerateIpv4 $testIPv4Address $oldipv4
    #>
    [int]$check = $null
    if ($null -eq $oldipv4){
        [int]$octet = 102
    }
    else {
        $oldIpPart = $oldipv4.Split(".")
        [int]$octet  = $oldIpPart[3]
    }

    $ipPart = $tempipv4.Split(".")
    $newAddress = ($ipPart[0]+"."+$ipPart[1]+"."+$ipPart[2])

    while ($check -ne 1 -and $octet -lt 255){
        $octet = 1 + $octet
        if (!(Test-Connection "$newAddress.$octet" -Count 1 -Quiet))
        {
            $splitip = $newAddress + "." + $octet
            $check = 1
        }
    }

    return $splitip.ToString()
}


#####################################################################
#
# SendCommandToVM()
#
#####################################################################
function SendCommandToVM([String] $ipv4, [String] $sshKey, [string] $command)
{
    <#
    .Synopsis
        Send a command to a Linux VM using SSH.
    .Description
        Send a command to a Linux VM using SSH.
    .Parameter ipv4
        IPv4 address of the VM to send the command to.
    .Parameter sshKey
        Name of the SSH key file to use.  Note this function assumes the
        ssh key a directory with a relative path of .\Ssh
    .Parameter command
        Command string to run on the Linux VM.
    .Example
        SendCommandToVM "192.168.1.101" "lisa_id_rsa.ppk" "echo 'It worked' > ~/test.txt"
    #>

    $retVal = $false

    if (-not $ipv4)
    {
        Write-ERROR -Message "ipv4 is null" -Category InvalidData -ERRORAction SilentlyContinue
        return $false
    }

    if (-not $sshKey)
    {
        Write-ERROR -Message "sshKey is null" -Category InvalidData -ERRORAction SilentlyContinue
        return $false
    }

    if (-not $command)
    {
        Write-ERROR -Message "command is null" -Category InvalidData -ERRORAction SilentlyContinue
        return $false
    }

    # get around plink questions
    Write-Output y | bin\plink.exe -batch -i ssh\${sshKey} root@${ipv4} 'exit 0'


    # Wait a second
    Start-Sleep 1
    $process = Start-Process bin\plink -ArgumentList "-batch -i ssh\${sshKey} root@${ipv4} ${command}" -PassThru -NoNewWindow -Wait -redirectStandardOutput lisaOut.tmp -redirectStandardERROR lisaErr.tmp


    # Wait a second
    Start-Sleep 1
    if ($process.ExitCode -eq 0)
    {
        $retVal = $true
    }
    else
    {
         Write-ERROR -Message "Unable to send command to ${ipv4}. Command = '${command}'" -Category SyntaxERROR -ERRORAction SilentlyContinue
    }

    Remove-Item lisaOut.tmp -ERRORAction "SilentlyContinue"
    Remove-Item lisaErr.tmp -ERRORAction "SilentlyContinue"

    return $retVal
}


#####################################################################
#
# SendFileToVM()
#
#####################################################################
function SendFileToVM([String] $ipv4, [String] $sshkey, [string] $localFile, [string] $remoteFile, [Switch] $ChangeEOL)
{
    <#
    .Synopsis
        Use SSH to copy a file to a Linux VM.
    .Description
        Use SSH to copy a file to a Linux VM.
    .Parameter ipv4
        IPv4 address of the VM the file is to be copied to.
    .Parameter sshKey
        Name of the SSH key file to use.  Note this function assumes the
        ssh key a directory with a relative path of .\Ssh
    .Parameter localFile
        Path to the file on the local system.
    .Parameter remoteFile
        Name to call the file on the remote system.
    .Example
        SendFileToVM "192.168.1.101" "lisa_id_rsa.ppk" "C:\test\test.dat" "test.dat"
    #>

    if (-not $ipv4)
    {
        Write-ERROR -Message "ipv4 is null" -Category InvalidData -ERRORAction SilentlyContinue
        return $false
    }

    if (-not $sshKey)
    {
        Write-ERROR -Message "sshkey is null" -Category InvalidData -ERRORAction SilentlyContinue
        return $false
    }

    if (-not $localFile)
    {
        Write-ERROR -Message "localFile is null" -Category InvalidData -ERRORAction SilentlyContinue
        return $false
    }

    if (-not $remoteFile)
    {
        Write-ERROR -Message "remoteFile is null" -Category InvalidData -ERRORAction SilentlyContinue
        return $false
    }

    $recurse = ""
    if (test-path -path $localFile -PathType Container )
    {
        $recurse = "-r"
    }

    # get around plink questions
    Write-Output y | bin\plink.exe -batch -i ssh\${sshKey} root@${ipv4} "exit 0"

    $process = Start-Process bin\pscp -ArgumentList "-batch -i ssh\${sshKey} ${localFile} root@${ipv4}:${remoteFile}" -PassThru -NoNewWindow -Wait -redirectStandardOutput lisaOut.tmp -redirectStandardERROR lisaErr.tmp
    if ($process.ExitCode -eq 0)
    {
        $retVal = $true
    }
    else
    {
        Write-ERROR -Message "Unable to send file '${localFile}' to ${ipv4}" -Category ConnectionERROR -ERRORAction SilentlyContinue
    }

    Remove-Item lisaOut.tmp -ERRORAction "SilentlyContinue"
    Remove-Item lisaErr.tmp -ERRORAction "SilentlyContinue"

    if ($ChangeEOL)
    {
        .bin\plink -batch -i ssh\${sshKey} root@${ipv4} "dos2unix $remoteFile"
    }

    return $retVal
}


#######################################################################
#
# StopVMViaSSH()
#
#######################################################################
function StopVMViaSSH ([String] $vmName, [String] $server="localhost", [int] $timeout, [string] $sshkey)
{
    <#
    .Synopsis
        Use SSH to send an 'init 0' command to a Linux VM.
    .Description
        Use SSH to send an 'init 0' command to a Linux VM.
    .Parameter vmName
        Name of the Linux VM.
    .Parameter server
        Name of the server hosting the VM.
    .Parameter timeout
        Timeout in seconds to wait for the VM to enter Off state
    .Parameter sshKey
        Name of the SSH key file to use.  Note this function assumes the
        ssh key a directory with a relative path of .\Ssh
    .Example
        StopVmViaSSH "testVM" "localhost" "300" "lisa_id_rsa.ppk"
    #>

    if (-not $vmName)
    {
        Write-ERROR -Message "StopVMViaSSH: VM name is null" -Category ObjectNotFound -ERRORAction SilentlyContinue
        return $false
    }

    if (-not $sshKey)
    {
        Write-ERROR -Message "StopVMViaSSH: SSHKey is null" -Category ObjectNotFound -ERRORAction SilentlyContinue
        return $false
    }

    if (-not $timeout)
    {
        Write-ERROR -Message "StopVMViaSSH: timeout is null" -Category ObjectNotFound -ERRORAction SilentlyContinue
        return $false
    }

    $vmipv4 = GetIPv4 $vmName $server
    if (-not $vmipv4)
    {
        Write-ERROR -Message "StopVMViaSSH: Unable to determine VM IPv4 address" -Category ObjectNotFound -ERRORAction SilentlyContinue
        return $false
    }

    #
    # Tell the VM to stop
    #
    Write-Output y | bin\plink -batch -i ssh\${sshKey} root@${vmipv4} exit
    .\bin\plink.exe -batch -i ssh\${sshKey} root@${vmipv4} "init 0"
    if (-not $?)
    {
        Write-ERROR -Message "StopVMViaSSH: Unable to send command via SSH" -Category ObjectNotFound -ERRORAction SilentlyContinue
        return $false
    }

    #
    # Wait for the VM to go to the Off state or timeout
    #
    $tmo = $timeout
    while ($tmo -gt 0)
    {
        Start-Sleep -s 5
        $tmo -= 5

        $vm = Get-VMHost -Name $server | Get-VM -Name $vmName
        if (-not $vm)
        {
            return $false
        }

        if ($vm.PowerState -eq "PoweredOff")
        {
            return $true
        }
    }

    Write-ERROR -Message "StopVMViaSSH: VM did not stop within timeout period" -Category OperationTimeout -ERRORAction SilentlyContinue
    return $false
}


#####################################################################
#
# TestPort
#
#####################################################################
function TestPort ([String] $ipv4addr, [Int] $portNumber=22, [Int] $timeout=5)
{
    <#
    .Synopsis
        Test if a remote host is listening on a specific port.
    .Description
        Test if a remote host is listening on a spceific TCP port.
        Wait only timeout seconds.
    .Parameter ipv4addr
        IPv4 address of the system to check.
    .Parameter portNumber
        Port number to try.  Default is the SSH port.
    .Parameter timeout
        Timeout in seconds.  Default is 5 seconds.
    .Example
        TestPort "192.168.1.101" 22 10
    #>

    $retVal = $false
    $to = $timeout * 1000

    #
    # Try an async connect to the specified machine/port
    #
    $tcpclient = new-Object system.Net.Sockets.TcpClient
    $iar = $tcpclient.BeginConnect($ipv4addr,$portNumber,$null,$null)

    #
    # Wait for the connect to complete. Also set a timeout
    # so we don't wait all day
    #
    $connected = $iar.AsyncWaitHandle.WaitOne($to,$false)

    # Check to see if the connection is done
    if($connected)
    {
        #
        # Close our connection
        #
        try
        {
            $sts = $tcpclient.EndConnect($iar)
            $retVal = $true
        }
        catch
        {
            # Nothing we need to do...
            $msg = $_.Exception.Message
        }
    }
    $tcpclient.Close()

    return $retVal
}


#######################################################################
#
# WaiForVMToStartSSH()
#
#######################################################################
function WaitForVMToStartSSH([String] $ipv4addr, [int] $timeout)
{
    <#
    .Synopsis
        Wait for a Linux VM to start SSH
    .Description
        Wait for a Linux VM to start SSH.  This is done
        by testing if the target machine is lisetning on
        port 22.
    .Parameter ipv4addr
        IPv4 address of the system to test.
    .Parameter timeout
        Timeout in second to wait
    .Example
        WaitForVMToStartSSH "192.168.1.101" 300
    #>

    $retVal = $false

    $waitTimeOut = $timeout
    while($waitTimeOut -gt 0)
    {
        $sts = TestPort -ipv4addr $ipv4addr -timeout 5
        if ($sts)
        {
            return $true
        }

        $waitTimeOut -= 15  # Note - Test Port will sleep for 5 seconds
        Start-Sleep -s 10
    }

    if (-not $retVal)
    {
        Write-ERROR -Message "WaitForVMToStartSSH: VM ${vmName} did not start SSH within timeout period ($timeout)" -Category OperationTimeout -ERRORAction SilentlyContinue
    }

    return $retVal
}


#######################################################################
#
# WaitForVMSSHReady()
#
#######################################################################
function WaitForVMSSHReady([String] $vmName, [String] $hvServer, [String] $sshKey, [int] $timeout)
{
    <#
    .Synopsis
        Wait for a Linux VM to have IP address assigned and start SSH
    .Description
        Wait for a Linux VM to have IP address assigned and start SSH.
        This is done by testing if the target machine is lisetning on
        port 22.
    .Parameter vmName
        Name of the VM to retrieve the IP address from.
    .Parameter hvServer
       IP address of host the VM located
    .Parameter sshKey
        Name of the SSH key file to use.  Note this function assumes the
        ssh key a directory with a relative path of .\ssh
    .Parameter timeout
        Timeout in second to wait
    .Example
        WaitForVMSSHReady VM_NAME HOST_IP 300
    #>

    $retVal = $false

    $waitTimeOut = $timeout
    while($waitTimeOut -gt 0)
    {
        $vmipv4 = GetIPv4 $vmName $hvServer
        if ($vmipv4)
        {
            $result = Write-Output y | bin\plink -batch -i ssh\${sshKey} root@${vmipv4} "echo 911"
            if ($result -eq 911)
            {
                $retVal = $true
                break
            }
        }
        $waitTimeOut -= 2  # Note - Test Port will sleep for 5 seconds
        Start-Sleep -s 2
    }

    if (-not $retVal)
    {
        Write-ERROR -Message "WaitForVMSSHReady: VM ${vmName} did not start SSH within timeout period ($timeout)" -Category OperationTimeout -ERRORAction SilentlyContinue
    }

    return $retVal
}


#######################################################################
#
# WaitForVMToStop()
#
#######################################################################
function  WaitForVMToStop ([string] $vmName ,[string]  $hvServer, [int] $timeout)
{
    <#
    .Synopsis
        Wait for a VM to enter the Off state.
    .Description
        Wait for a VM to enter the Off state
    .Parameter vmName
        Name of the VM that is stopping.
    .Parameter hvSesrver
        Name of the server hosting the VM.
    .Parameter timeout
        Timeout in seconds to wait.
    .Example
        WaitForVMToStop "testVM" "localhost" 300
    a#>
    $tmo = $timeout
    while ($tmo -gt 0)
    {
        Start-Sleep -s 1
        $tmo -= 5

         $vm = Get-VMHost -Name $server | Get-VM -Name $vmName
        if (-not $vm)
        {
            return $false
        }

        if ($vm.PowerState -eq "PoweredOff")
        {
            return $true
        }
    }

    Write-ERROR -Message "StopVM: VM did not stop within timeout period" -Category OperationTimeout -ERRORAction SilentlyContinue
    return $false
}


#######################################################################
#
# AddIDEHardDisk()
#
#######################################################################
function  AddIDEHardDisk ([string] $vmName , [string]  $hvServer, [int] $capacityGB) {
    <#
    .Synopsis
        Add a new IDE hard disk.
    .Description
        Add a new IDE hard disk.
    .Parameter vmName
        Name of the VM that need to add disk.
    .Parameter hvSesrver
        Name of the server hosting the VM.
    .Parameter capacityGB
        The Capacity of Disk.
    .Example
        AddIDEHardDisk "testVM" "localhost" 10
    a#>

    $vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
    if (-not $vmObj) {
        Write-ERROR -Message "AddIDEHardDisk: Unable to Get-VM with $vmName" -Category OperationTimeout -ERRORAction SilentlyContinue
        return $false
    }
    $hdSize = $capacityGB * 1GB

    $vm = $vmObj
    $spec = New-Object VMware.Vim.VirtualMachineConfigSpec

    # Check if there is an IDE controller present
    $ideCtrl = $vm.ExtensionData.Config.Hardware.Device | Where-Object {$_.GetType().Name -eq "VirtualIDEController"} | Select-Object -First 1 
    if (!$ideCtrl) {
        $ctrl = New-Object VMware.Vim.VirtualDeviceConfigSpec
        $ctrl.Operation = "add"
        $ctrl.Device = New-Object VMware.Vim.VirtualIDEController
        $ideKey = -1
        $ctrl.Device.ControllerKey = $ideKey
        $spec.deviceChange += $ctrl
    }
    else {
        $ideKey = $ideCtrl.Key
    }

    try {
        # Get next harddisk number
        $hdNUM = Get-Random -Minimum 10000 -Maximum 99999

        # Get datastore
        $dsName = $vm.ExtensionData.Config.Files.VmPathName.Split(']')[0].TrimStart('[')

        # Add IDE hard disk
        $dev = New-Object VMware.Vim.VirtualDeviceConfigSpec
        $dev.FileOperation = "Create"
        $dev.Operation = "Add"
        $dev.Device = New-Object VMware.Vim.VirtualDisk
        $dev.Device.backing = New-Object VMware.Vim.VirtualDiskFlatVer2BackingINFO
        $dev.Device.backing.Datastore = ($vm.VMHost|Get-Datastore -Name $dsName).Extensiondata.MoRef
        $dev.Device.backing.DiskMode = "persistent"
        $dev.Device.Backing.FileName = "[" + $dsName + "] " + $vmName + "/" + $vmName + "_" + $hdNUM + ".vmdk"

        # Write-Host -F Red "$dev.Device.Backing.FileName"
        # Write-Host "$dev.Device.Backing.FileName"

        $dev.Device.backing.ThinProvisioned = $true
        $dev.Device.CapacityInKb = $hdSize / 1KB
        $dev.Device.ControllerKey = $ideKey
        $dev.Device.UnitNumber = -1
        $spec.deviceChange += $dev

        $vm.ExtensionData.ReconfigVM($spec)
        LogPrint "DONE: IDE Disk Add successful"
        return $true
    }
    catch {
        # Printout ERROR message
        $ERRORMessage = $_ | Out-String
        LogPrint $ERRORMessage
        return $false
    }
}


#######################################################################
#
# Clean all hard disk, only left system disk.
#
#######################################################################

function  CleanUpDisk ([string] $vmName , [string]  $hvServer, [string] $sysDisk) {
    <#
    .Synopsis
        Clean all hard disk, only left system disk.
    .Description
        Clean all hard disk, only left system disk.
    .Parameter vmName
        Name of the VM that need to add disk.
    .Parameter hvSesrver
        Name of the server hosting the VM.
    .Parameter sysDisk
        The name of system disk
    .Example
        CleanUpDisk "testVM" "localhost" "Hard disk 1"
    a#>

    # Check input arguments
    #
    if ($null -eq $vmName -or $vmName.Length -eq 0) {
        "ERROR: VM name is null"
        return $false
    }
    $vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
    while ($true) {
        # How many disks in VM
        $diskList = Get-HardDisk -VM $vmObj
        $diskLength = $diskList.Length

        # If disks counts great than 1, will delete them
        if ($diskList.Length -gt 1) {
            foreach ($disk in $diskList) {
                $diskName = $disk.Name
                if ($diskName -ne $sysDisk) {
                    Get-HardDisk -VM $vmObj -Name $($diskName) | Remove-HardDisk -Confirm:$false -DeletePermanently:$true -ERRORAction SilentlyContinue
                    # Get new counts of disks
                    $diskNewLength = (Get-HardDisk -VM $vmObj).Length
                    if (($diskLength - $diskNewLength) -eq 1) {
                        Write-Output "DONE: remove $diskName"
                        Write-Host -F Red "DONE: remove $diskName"
                        break
                    }
                }
            }
        }
        else {
            Write-Output "DONE: Only system disk is left"
            Write-Host -F Red "DONE: Only system disk is left"
            break
        }
    }

    $diskLastList = Get-HardDisk -VM $vmObj
    if ($diskLastList.Length -eq 1) {
        Write-Output "PASS: Clean disk new added successfully"
        return $true
    }
    else {
        Write-Output "FAIL: Clean disk new added unsuccessfully"
        return $false
    }
    return $false
}


########################################################################################
# Runs a remote script on the VM and returns the log.
########################################################################################
function RunRemoteScript($remoteScript)
{
    $retValue 	   = $false
    $stateFile     = "state.txt"
    $TestCompleted = "TestCompleted"
    $TestAborted   = "TestAborted"
    $TestFailed    = "TestFailed"
    $TestRunning   = "TestRunning"
    $timeout       = 6000

    "./${remoteScript} > ${remoteScript}.log" | out-file -encoding ASCII -filepath runtest.sh

    .\bin\pscp -batch -i ssh\${sshKey} .\runtest.sh root@${ipv4}:
    if (-not $?)
    {
       LogPrint "ERROR: Unable to copy runtest.sh to the VM"
       return $false
    }
     .\bin\pscp -batch -i ssh\${sshKey} .\remote-scripts\${remoteScript} root@${ipv4}:
    if (-not $?)
    {
        LogPrint "ERROR: Unable to copy ${remoteScript} to the VM"
       return $false
    }

    .\bin\plink.exe -batch -i ssh\${sshKey} root@${ipv4} "dos2unix ${remoteScript} 2> /dev/null"
    if (-not $?)
    {
        LogPrint "ERROR: Unable to run dos2unix on ${remoteScript}"
        return $false
    }

    .\bin\plink.exe -batch -i ssh\${sshKey} root@${ipv4} "dos2unix runtest.sh  2> /dev/null"
    if (-not $?)
    {
        LogPrint "ERROR: Unable to run dos2unix on runtest.sh"
        return $false
    }

    .\bin\plink.exe -batch -i ssh\${sshKey} root@${ipv4} "chmod +x ${remoteScript}   2> /dev/null"
    if (-not $?)
    {
        LogPrint "ERROR: Unable to chmod +x ${remoteScript}"
        return $false
    }
    .\bin\plink.exe -batch -i ssh\${sshKey} root@${ipv4} "chmod +x runtest.sh  2> /dev/null"
    if (-not $?)
    {
        LogPrint "ERROR: Unable to chmod +x runtest.sh"
        return $false
    }

    # Run the script on the vm
    .\bin\plink.exe -batch -i ssh\${sshKey} root@${ipv4} "./runtest.sh"

    # Return the state file
    while ($timeout -ne 0)
    {
    	.\bin\pscp -q -batch -i ssh\${sshKey} root@${ipv4}:${stateFile} . #| out-null
    	$sts = $?
    	if ($sts)
    	{
    	    if (test-path $stateFile)
    	    {
    	        $contents = Get-Content -Path $stateFile
    	        if ($null -ne $contents)
    	        {
    	        	if ($contents -eq $TestCompleted)
    	            {
    	                LogPrint "INFO : state file contains Testcompleted."
    	                $retValue = $true
    	                break
    	            }

    	            if ($contents -eq $TestAborted)
    	            {
    	                LogPrint "INFO : State file contains TestAborted message."
    	                 break
    	            }
    	            if ($contents -eq $TestFailed)
    	            {
    	                LogPrint "INFO : State file contains TestFailed message."
    	                break
    	            }

    	            $timeout--

    	            if ($timeout -eq 0)
    	            {
    	                LogPrint "ERROR : Timed out on Test Running , Exiting test execution."
    	                break
    	            }
    	        }
    	        else
    	        {
    	            LogPrint "ERROR: state file is empty"
    	            break
    	        }
    	    }
    	    else
    	    {
    	        LogPrint "ERROR: ssh reported success, but state file was not copied"
    	        break
    	    }
    	}
    	else
    	{
    	    LogPrint "ERROR : pscp exit status = $sts"
    	    LogPrint "ERROR : unable to pull state.txt from VM."
    	    break
    	}
    }

    # Get the logs
    $remoteScriptLog = $remoteScript + ".log"

    bin\pscp -q -batch -i ssh\${sshKey} root@${ipv4}:${remoteScriptLog} .
    $sts = $?
    if ($sts)
    {
        if (test-path $remoteScriptLog)
        {
            $contents = Get-Content -Path $remoteScriptLog
            if ($null -ne $contents)
            {
                if ($null -ne ${TestLogDir})
                {
                    Move-Item "${remoteScriptLog}" "${TestLogDir}\${remoteScriptLog}"
                }
                else
                {
                    LogPrint "INFO: $remoteScriptLog is copied in ${rootDir}"
                }
            }
            else
            {
                LogPrint "ERROR: $remoteScriptLog is empty"
            }
        }
        else
        {
            LogPrint "ERROR: ssh reported success, but $remoteScriptLog file was not copied"
        }
    }
	else
	{
    	LogPrint "ERROR: PSCP failed from remote VM."
	}

    # Cleanup
    Remove-Item state.txt -ERRORAction "SilentlyContinue"
    Remove-Item runtest.sh -ERRORAction "SilentlyContinue"
    return $retValue
}


########################################################################################
# Check module version in vm.
########################################################################################
function GetModuleVersion([String] $ipv4, [String] $sshKey, [string] $module)
{
    <#
    .Synopsis
        Use SSH to get module version in a Linux VM.
    .Description
        Use SSH to get module version in a Linux VM, must use CheckModuleVersion make sure requested Module exists.
    .Parameter ipv4
        IPv4 address of the VM the module which needs to get version.
    .Parameter sshKey
        Name of the SSH key file to use.  Note this function assumes the
        ssh key a directory with a relative path of .\ssh
    .Parameter module
        Module name which needs to get version in linux VM.
    .Example
        GetModuleVersion "192.168.1.101" "lisa_id_rsa.ppk" "vmxnet3"
    #>

    if (-not $ipv4)
    {
        Write-ERROR -Message "ipv4 is null" -Category InvalidData -ERRORAction SilentlyContinue
        return $false
    }

    if (-not $sshKey)
    {
        Write-ERROR -Message "sshkey is null" -Category InvalidData -ERRORAction SilentlyContinue
        return $false
    }

    if (-not $module)
    {
        Write-ERROR -Message "module name is null" -Category InvalidData -ERRORAction SilentlyContinue
        return $false
    }
    
    # get around plink questions
    Write-Output y | bin\plink.exe -batch -i ssh\${sshKey} root@${ipv4} "exit 0"

    $module_version = bin\plink.exe -batch -i ssh\${sshKey} root@${ipv4} "modINFO $module | grep -w version: | awk '{print `$2}'"

    return $module_version.Trim()
}


#######################################################################################
# CheckModule
#######################################################################################
function CheckModule([String] $ipv4, [String] $sshKey, [string] $module)
{
    <#
    .Synopsis
        Use SSH to check module in a Linux VM.
    .Description
        Use SSH to check module in a Linux VM.
    .Parameter ipv4
        IPv4 address of the VM the module is to be checked.
    .Parameter sshKey
        Name of the SSH key file to use.  Note this function assumes the
        ssh key a directory with a relative path of .\Ssh
    .Parameter module
        Module name to be checked in linux VM.
    .Example
        CheckModule "192.168.1.101" "lisa_id_rsa.ppk" "vmxnet3"
    #>

    if (-not $ipv4)
    {
        Write-ERROR -Message "ipv4 is null" -Category InvalidData -ERRORAction SilentlyContinue
        return $false
    }

    if (-not $sshKey)
    {
        Write-ERROR -Message "sshkey is null" -Category InvalidData -ERRORAction SilentlyContinue
        return $false
    }

    if (-not $module)
    {
        Write-ERROR -Message "module name is null" -Category InvalidData -ERRORAction SilentlyContinue
        return $false
    }

    # get around plink questions
    Write-Output y | bin\plink.exe -batch -i ssh\${sshKey} root@${ipv4} "exit 0"

    $vm_module = bin\plink.exe -batch -i ssh\${sshKey} root@${ipv4} "lsmod | grep -w ^$module | awk '{print `$1}'"
    Write-Host -F Red "DEBUG: vm_module: $vm_module."

	# If we can't check $vm_moudle is null or not, $vm_module.Trim() will throw error and skip if.
    if ($null -eq $vm_module)
    {
        Write-Host -F Red "DEBUG: NO $module in VM."
        return $false
    }

    if ($vm_module.Trim() -eq $module.Trim())
    {
        return $true
    }
    else
    {
        return $false
    }
}


#######################################################################################
# ConvertStringToDecimal()
#######################################################################################
function ConvertStringToDecimal([string] $str)
{
    $uint64Size = $null

    #
    # Make sure we received a string to convert
    #
    if (-not $str)
    {
        Write-ERROR -Message "ConvertStringToDecimal() - input string is null" -Category InvalidArgument -ERRORAction SilentlyContinue
        return $null
    }

    if ($str.EndsWith("GB"))
    {
        $num = $str.Replace("GB","")
        $uint64Size = ([Convert]::ToDecimal($num))
    }
    elseif ($str.EndsWith("TB"))
    {
        $num = $str.Replace("TB","")
        $uint64Size = ([Convert]::ToDecimal($num)) * 1024
    }
    else
    {
        Write-ERROR -Message "Invalid newSize parameter: ${str}" -Category InvalidArgument -ERRORAction SilentlyContinue
        return $null
    }

    return $uint64Size
}


#######################################################################################
# LogPrint()
#######################################################################################
function LogPrint([string] $msg) {

    $now = [Datetime]::Now.ToString("MM/dd/yyyy HH:mm:ss : ")

    if ( $msg.StartsWith("ERROR")) {
        $color = "Red"
    }
    elseif ($msg.StartsWith("WARNING")) {
        $color = "Yellow"
    }
    elseif ($msg.StartsWith("DEBUG")) {
        $color = "Yellow"
    }
    else {
        $color = "White"
    }

    Write-Host -F $color ($now + $msg)
    Write-Output ($now + $msg)
}


#######################################################################################
# RevertSnapshotVM()
#######################################################################################
function RevertSnapshotVM([String] $vmName, [String] $hvServer) {
    <#
    .Synopsis
        Make sure the test VM is stopped
    .Description
        Stop the test VM and then reset it to a snapshot.
        This ensures the VM starts the test run in a
        known good state.
    .Parameter vmName
        Name of the VM 
    .Parameter hvSesrver
        Name of the server hosting the VM.
    .Example
        ResetVM $vmName $hvServer
    #>

    if (-not $vmName -or -not $hvServer) {
        LogPrint "ERROR : ResetVM was passed an bad vmName or bad hvServer"
        return $false
    }

    LogPrint "INFO : ResetVM( $($vmName) )"

    $vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
    if (-not $vmObj) {
        LogPrint "ERROR : ResetVM cannot find the VM $($vmName)"
        return $false
    }

    #
    # If the VM is not stopped, try to stop it
    #
    if ($vmObj.PowerState -ne "PoweredOff") {
        LogPrint "INFO : $($vmName) is not in a stopped state - stopping VM"
        $outStopVm = Stop-VM -VM $vmObj -Confirm:$false -Kill
        if ($outStopVm -eq $false -or $outStopVm.PowerState -ne "PoweredOff") {
            LogPrint "ERROR : ResetVM is unable to stop VM $($vmName). VM has been disabled"
            return $false
        }
    }

    #
    # Reset the VM to a snapshot to put the VM in a known state.  The default name is
    # ICABase.  This can be overridden by the global.defaultSnapshot in the global section
    # and then by the vmSnapshotName in the VM definition.
    #
    $snapshotName = "ICABase"

    #
    # Find the snapshot we need and apply the snapshot
    #
    $snapshotFound = $false
    $vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
    $snapsOut = Get-Snapshot -VM $vmObj
    if ($snapsOut) {
        foreach ($s in $snapsOut) {
            if ($s.Name -eq $snapshotName) {
                LogPrint "INFO : $($vmName) is being reset to snapshot $($s.Name)"
                $setsnapOut = Set-VM -VM $vmObj -Snapshot $s -Confirm:$false
                if ($setsnapOut) {
                    $snapshotFound = $true
                    break
                }
                else {
                    LogPrint "ERROR : ResetVM is unable to revert VM $($vmName) to snapshot $($s.Name). VM has been disabled"
                    return $false
                }
            }
        }
    }

    #
    # Make sure the snapshot left the VM in a stopped state.
    #
    if ($snapshotFound) {
        #
        # If a VM is in the Suspended (Saved) state after applying the snapshot,
        # the following will handle this case
        #
        $vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
        if ($vmObj) {
            if ($vmObj.PowerState -eq "Suspended") {
                LogPrint "INFO : $($vmName) - resetting to a stopped state after restoring a snapshot"
                $stopvmOut = Stop-VM -VM $vmObj -Confirm:$false -Kill
                if ($stopvmOut -or $stopvmOut.PowerState -ne "PoweredOff") {
                    LogPrint "ERROR : ResetVM is unable to stop VM $($vmName). VM has been disabled"
                    return $false
                }
            }
        }
        else {
            LogPrint "ERROR : ResetVM cannot find the VM $($vmName)"
            return $false
        }
    }
    else {
        LogPrint "Warn : There's no snapshot with name $snapshotName found in VM $($vmName). Making a new one now."
        $newSnap = New-Snapshot -VM $vmObj -Name $snapshotName
        if ($newSnap) {
            $snapshotFound = $true
            LogPrint "INFO : $($vmName) made a snapshot $snapshotName."
        }
        else {
            LogPrint "ERROR : ResetVM is unable to make snapshot for VM $($vmName)."
            return $false
        }
    }

    return $true
}


#######################################################################################
# AddSrIOVNIC()
#######################################################################################
function AddSrIOVNIC { 
    Param(
        [String] $vmName, 
        [String] $hvServer, 
        [bool] $mtuChange,
        [Parameter(Mandatory = $false)] [String] $Network
        )
   <#
    .Synopsis
        Add a SrIOV NIC
    .Description
        Attach a new sriov nic to VM
    .Parameter vmName
        Name of the VM
    .Parameter hvSesrver
        Name of the server hosting the VM.
    .Parameter mtuChange
        Allow or disallow guest change MTU
    .Outputs
        Boolean
    .Example
        AddSrIoVNIC $vmName $hvSever $true
    #>

    $retVal = $false
    $vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
    if (-not $vmObj) {
        Write-ERROR -Message "CheckModules: Unable to create VM object for VM $vmName" -Category ObjectNotFound -ERRORAction SilentlyContinue
        return $false
    } 


    # Lock all memory
    try {
        # Enable reserve all memory option
        $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
        $spec.memoryReservationLockedToMax = $true
        $vmObj.ExtensionData.ReconfigVM_Task($spec)
    }
    catch {
        $ERRORMessage = $_ | Out-String
        LogPrint "ERROR: Lock all memory ERROR, please check it manually"
        LogPrint $ERRORMessage
        return $false
    }


    try {
        # Get Switch INFO
        $DVS = Get-VDSwitch -VMHost $vmObj.VMHost

    
        # This is hard code DPortGroup Name (6.0 6.5 6.7) This may change
        $PG = $DVS | Get-VDPortgroup -Name "DPortGroup"


        # Add new nic into config file
        $Spec = New-Object VMware.Vim.VirtualMachineConfigSpec
        $Dev = New-Object Vmware.Vim.VirtualDeviceConfigSpec
        $Dev.Operation = "add" 
        $Dev.Device = New-Object VMware.Vim.VirtualSriovEthernetCard


        # change config make mtu editable
        if ($mtuChange) {
            LogPrint "INFO: MTU is editable"
            $Dev.Device.AllowGuestOSMtuChange = $true
        }


        $Spec.DeviceChange += $dev
        $Spec.DeviceChange.Device.Backing = New-Object VMware.Vim.VirtualEthernetCardDistributedVirtualPortBackingINFO
        $Spec.DeviceChange.Device.Backing.Port = New-Object VMware.Vim.DistributedVirtualSwitchPortConnection

    
        # This is currently UNKNOWN function
        $Spec.DeviceChange.Device.Backing.Port.PortgroupKey = $PG.Key
        $Spec.DeviceChange.Device.Backing.Port.SwitchUuid = $DVS.Key


        # Apply the new config
        $View = $vmObj | Get-View
        $View.ReconfigVM($Spec)    
    }
    catch {
        $ERRORMessage = $_ | Out-String
        LogPrint "ERROR: SRIOV config ERROR, $ERRORMessage"
        return $false
    }


    # Get Sriov PCI Device (like 00000:007:00.0)
    try {
        $vmHost = Get-VMHost -Name $hvServer  
        # This may fail, try to delete -V2 param Current only support one card
        $esxcli = Get-EsxCli -VMHost $vmHost -V2
        # TODO: add multiple SRIOV support
        # Here may have problem if we have multiple SRIOV adapter
        $pciDevice = $esxcli.network.sriovnic.list.Invoke() | Select-Object -ExpandProperty "PCIDevice" | Select-Object -First 1
    }
    catch {
        $ERRORMessage = $_ | Out-String
        LogPrint "ERROR: Get PCI Device ERROR"
        LogPrint $ERRORMessage
        return $false
    }
    if ($null -eq $pciDevice) {
        LogPrint "ERROR: Cannot get PCI Device" 
        return $false
    }
    LogPrint "INFO: PCI Device is $pciDevice"


    # Modify device address to make sure it fit the format of config file  (For example: 00000:068:00.0)
    $address = $pciDevice.Split(":")
    $address[0] = $address[0].PadLeft(5, '0')
    $hex = $address[1]
    $address[1] = ([String][convert]::toint64($hex, 16)).PadLeft(3, '0')
    $pciDevice = $address -join ":"
    LogPrint "INFO: After format PCI Device is $pciDevice"


    # Refresh the VM
    $vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
    if (-not $vmObj) {
        Write-ERROR -Message "CheckModules: Unable to create VM object for VM $vmName" -Category ObjectNotFound -ERRORAction SilentlyContinue
        return $false
    }
    # Refresh vmView
    $vmView = $vmObj | Get-View
    # Change config pfId and Id to required PCI Device
    $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
    $pfID = New-Object VMware.Vim.optionvalue
    $passID = New-Object VMware.Vim.optionvalue 


    # Find correct pci key. Like "pciPassthru15"
    $pfID.Key = ($vmView.Config.ExtraConfig | Where-Object { $_.Key -like "pciPassthru*.pfid"})[-1] | Select-Object -ExpandProperty "key"
    $pfID.Value = $pciDevice
    $passID.Key = ($vmView.Config.ExtraConfig | Where-Object { $_.Key -like "pciPassthru*.id"})[-1] | Select-Object -ExpandProperty "key"
    $passID.Value = $pciDevice
    if ($passID.Key -notlike "pciPassthru*.id" -or $pfID.Key -notlike "pciPassthru*.pfid") {
        LogPrint "ERROR: Config key failed: passID $passID.Key, pfID $pfID.Key" 
        return $false
    }


    try {
        # Add extra into config
        $vmConfigSpec.ExtraConfig += $pfID
        $vmConfigSpec.ExtraConfig += $passID

        # Applay the new config
        $vmView.ReconfigVM($vmConfigSpec)    
    }
    catch {
        $ERRORMessage = $_ | Out-String
        LogPrint "ERROR: Config SRIOV ERROR"
        LogPrint $ERRORMessage
        return $false
    }


    # Refresh the VM
    $vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
    if (-not $vmObj) {
        Write-ERROR -Message "CheckModules: Unable to create VM object for VM $vmName" -Category ObjectNotFound -ERRORAction SilentlyContinue
        return $false
    }
    # Refresh the view
    $vmView = $vmObj | Get-View


    # Default Network should be "VM Network"
    if (-not $PSBoundParameters.ContainsKey("Network")) {
        $Network = "VM Network"
    }


    # Set the Network of Guest to required Network
    $nics = Get-NetworkAdapter -VM $vmObj
    $nicMacAddress = ($vmView.Config.ExtraConfig | Where-Object { $_.Key -like "pciPassthru*.generatedMACAddress"})[-1].Value
    foreach ($nic in $nics) {
        if ($nic.MacAddress -eq $nicMacAddress) {
            Set-NetworkAdapter -NetworkAdapter $nic -NetworkName $Network -Confirm:$false
            if  (-not $?){
                LogPrint "ERROR: Setup Network to $Network failed"    
                return $false
            }
        } 
    }


    # Refresh the VM
    $vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
    if (-not $vmObj) {
        Write-ERROR -Message "CheckModules: Unable to create VM object for VM $vmName" -Category ObjectNotFound -ERRORAction SilentlyContinue
        return $false
    }


    # Refresh the view
    $vmView = $vmObj | Get-View


    # Check vmx value
    $valueID = ($vmView.Config.ExtraConfig | Where-Object { $_.Key -like "pciPassthru*.id"})[-1] | Select-Object -ExpandProperty "Value"
    $valuepfID = ($vmView.Config.ExtraConfig | Where-Object { $_.Key -like "pciPassthru*.pfid"})[-1] | Select-Object -ExpandProperty "Value"
    if ( ($pciDevice.Split(":")[1].Trim("0") -ne $valueID.Split(":")[1].Trim("0")) -or ($pciDevice.Split(":")[1].Trim("0") -ne $valuepfID.Split(":")[1].Trim("0")) ) {
        LogPrint "ERROR: Add extra config failed"    
        return $false
    }
    else
    {
        LogPrint "INFO: Add the SRIOV successfully"
        $retVal = $true
    }


    return $retVal
}


########################################################################################
# ConfigIPforNewDevice()
########################################################################################
function ConfigIPforNewDevice {
    Param
    (
        [String] $ipv4, 
        [String] $sshkey, 
        [String] $deviceName, 
        [Parameter(Mandatory = $false)] [String] $IP_Prefix,
        [Parameter(Mandatory = $false)] [String] $MTU
    )
    <#
    .Synopsis
        Config IP for new nic
    .Description
        Config IP address for new attached NIC
    .Parameter ipv4
        ipv4 address of target VM
    .Parameter sshkey
        Name of the SSH key file to use.  Note this function assumes the
        ssh key a directory with a relative path of .\Ssh.
    .Parameter deviceName
        Name of new attached NIC
    .Parameter IP_Prefix 
        IP with prefix such as 192.168.0.100/24
    .Parameter MTU 
        The MTU for the NIC (1500 default) 
    .Outputs
        Boolean
    .Example
        ConfigIPforNewDevice $ipv4 $sshkey $deviceName 192.168.0.100/24 192.168.0.1
    #>
    
    $retVal = $false
    if ($null -eq $deviceName) {
        LogPrint "ERROR: No device name in param."
        return $false 
    }

    # Get the Guest version.
    $DISTRO = GetLinuxDistro ${ipv4} ${sshKey}
    LogPrint "DEBUG: DISTRO: $DISTRO"
    if (-not $DISTRO) {
        LogPrint "ERROR: Guest OS version is NULL."
        return $false
    }
    LogPrint "INFO: Guest OS version is $DISTRO."

    # Different Guest DISTRO.
    #if ($DISTRO -ne "RedHat7" -and $DISTRO -ne "RedHat8" -and $DISTRO -ne "RedHat6") {
    #    LogPrint "ERROR: Guest OS ($DISTRO) isn't supported, MUST UPDATE in Framework / XML / Script"
    #    return $false
    #}

    # Setup default MTU value
    if ( -not $PSBoundParameters.ContainsKey("MTU")) {
        LogPrint "INFO: MTU set to default 1500"
        $MTU = 1500 
    }
    
    if ($DISTRO -eq "RedHat6") {
        # Start Specifc device
        SendCommandToVM $ipv4 $sshKey "ifconfig $deviceName up" 
        if ($PSBoundParameters.ContainsKey("IP_Prefix")) {
            $IP = $IP_Prefix.Split("/")[0]
            $Prefix = $IP_Prefix.Split("/")[1]
            # Config IP for Device
            $Network_Script = "DEVICE=$deviceName`\nBOOTPROTO=none`\nONBOOT=yes`\nIPADDR=$IP`\nPREFIX=$Prefix`\nMTU=$MTU"
            # This echo $ will help to create new line in script
            SendCommandToVM $ipv4 $sshKey "echo `$'$Network_Script' > /etc/sysconfig/network-scripts/ifcfg-$deviceName"
        }
        else {
            # Config DHCP for Device
            $Network_Script = "DEVICE=$deviceName`\nBOOTPROTO=dhcp`\nONBOOT=yes`\nMTU=$MTU"
            SendCommandToVM $ipv4 $sshKey "echo `$'$Network_Script' > /etc/sysconfig/network-scripts/ifcfg-$deviceName"
        }

        # Restart Network service
        $status = SendCommandToVM $ipv4 $sshKey "ifdown $deviceName && ifup $deviceName"
        if (-not $status) {
            LogPrint "Error: Cannot activate new nic config."
            return $false
        } else {
            $retVal = $true
        }
    }
    else {
        # Start NetworkManager
        SendCommandToVM $ipv4 $sshKey "systemctl restart NetworkManager" 
        if ($PSBoundParameters.ContainsKey("IP_Prefix")) {
            # Config New Connection with IP
            $status = SendCommandToVM $ipv4 $sshKey "nmcli con add con-name $deviceName ifname $deviceName type Ethernet ip4 $IP_Prefix mtu $MTU" 
        }
        else {
            # Config New Connection with DHCP
            $status = SendCommandToVM $ipv4 $sshKey "nmcli con add con-name $deviceName ifname $deviceName type Ethernet mtu $MTU" 
        }

        # Check results
        if (-not $status) {
            LogPrint "Error: Config new connection failed"
            return $false
        }

        # Restart NetworkManager
        $status = SendCommandToVM $ipv4 $sshKey "systemctl restart NetworkManager" 

        Start-Sleep -Seconds 6

        # Restart Connection
        $Command = "nmcli con down $deviceName && nmcli con up $deviceName" 
        $status = SendCommandToVM $ipv4 $sshKey $Command
        if (-not $status) {
            LogPrint "Error: Cannot activate new nic config."
            return $false
        }

        Start-Sleep -Seconds 6

        # Check current MTU
        $Command = "ip a | grep $deviceName | head -n 1 | awk '{print `$5}'"
        $Current_MTU = Write-Output y | bin\plink.exe -batch -i ssh\${sshKey} root@${ipv4} $Command
        if ($Current_MTU -ne $MTU) {
           LogPrint "ERROR: Set new MTU failed or MTU is not fitting network requirement." 
           return $false
        } else {
            $retVal = $true
        }
    }
    LogPrint "INFO: IP config for new NIC succeeded."

    return $retVal
}


########################################################################################
# AddPVrdmaNIC()
########################################################################################
function AddPVrdmaNIC {
    param (
        [String] $vmName,
        [String] $hvServer
    )

    <#
    .Synopsis
        Add pvRDMA nic
    .Description
        Attach a new rdma nic to VM
    .Parameter vmName
        Name of the VM that need to add disk.
    .Parameter hvSesrver
        Name of the server hosting the VM.
    .Outputs
        Boolean
    .Example
        AddPVrdmaNIC $vmName $hvSever
    #>

    $retVal = $false

    $vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
    if (-not $vmObj) {
        Write-ERROR -Message "CheckModules: Unable to create VM object for VM $vmName" -Category ObjectNotFound -ERRORAction SilentlyContinue
        return $false
    } 

    try {
        # Get Switch INFO
        $DVS = Get-VDSwitch -VMHost $vmObj.VMHost
        LogPrint "DEBUG: DVS: ${DVS}."
        if (-not $DVS) {
        Write-ERROR -Message "ERROR: Get VDSwitch failed." -Category ObjectNotFound -ERRORAction SilentlyContinue
        return $false
        }

        # Hard code DPortGroup Name (6.0 6.5 6.7) This may change
        $PG = $DVS | Get-VDPortgroup -Name "DPortGroup"
        LogPrint "DEBUG: PG: ${PG}."        
        if (-not $PG) {
        Write-ERROR -Message "ERROR: Get port group failed." -Category ObjectNotFound -ERRORAction SilentlyContinue
        return $false
        }

        # Add new nic into config file
        $Spec = New-Object VMware.Vim.VirtualMachineConfigSpec
        $Dev = New-Object Vmware.Vim.VirtualDeviceConfigSpec
        $Dev.Operation = "add" 
        $Dev.Device = New-Object VMware.Vim.VirtualVmxnet3Vrdma

        $Spec.DeviceChange += $dev
        $Spec.DeviceChange.Device.Backing = New-Object VMware.Vim.VirtualEthernetCardDistributedVirtualPortBackingINFO
        $Spec.DeviceChange.Device.Backing.Port = New-Object VMware.Vim.DistributedVirtualSwitchPortConnection
    
        # This is currently UNKNOWN function
        $Spec.DeviceChange.Device.Backing.Port.PortgroupKey = $PG.Key
        $Spec.DeviceChange.Device.Backing.Port.SwitchUuid = $DVS.Key

        # Apply the new config
        $View = $vmObj | Get-View
        $View.ReconfigVM($Spec)
    }
    catch {
        $ERRORMessage = $_ | Out-String
        LogPrint "ERROR: RDMA config ERROR, $ERRORMessage"
        return $false
    }

    $retVal = $true
    return $retVal
}


#######################################################################################
# AddNVMeDisk()
#######################################################################################

function AddNVMeDisk {
    param (
        [String] $vmName,
        [String] $hvServer,
        [String] $dataStore,
        [int] $capacityGB,
        [String] $storageFormat
    )

    <#
    .Synopsis
        Add NVMe disk
    .Description
        Attach a new NVMe Disk to VM, Add NVMe controller first and then attach a disk to controller
    .Parameter vmName
        Name of the VM that need to add disk.
    .Parameter hvSesrver
        Name of the server hosting the VM.
    .Parameter capacityGB
        The Capacity of Disk
    .Parameter storageFormat
        The storage of disk (Thin, Thick, EagerZeroedThick)
    .Outputs
        Boolean
    .Example
        AddNVMeDisk $vmName $hvSever $dataSotre 10 $storageFormat
    #>

    $vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
    if (-not $vmObj) {
        Write-ERROR -Message "INFO: Unable to Get-VM with $vmName" -Category OperationTimeout -ERRORAction SilentlyContinue
        return $false
    }

    
    # NVMe is not working on ESXi 6.0
    if ($vmObj.VMHost.Version -le 6.0) {
        LogPrint "ERROR: This script doesn't support ESXi 6.0"
        return $false
    }

    
    # Convert hdsize
    $hdSize = $capacityGB * 1GB
    # Create config
    $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
    # Check if there is an NVMe controller present
    $nvmeCtrl = $vmObj.ExtensionData.Config.Hardware.Device | Where-Object {$_.GetType().Name -eq "VirtualNVMEController"}  | Select-Object -First 1 
    if ( -not $nvmeCtrl) {
        $ctrl = New-Object VMware.Vim.VirtualDeviceConfigSpec
        $ctrl.Operation = "add"
        $ctrl.Device = New-Object VMware.Vim.VirtualNVMEController
        # This key is from vmx file may need to change due to different device
        $nvmeKey = 100
        $ctrl.Device.ControllerKey = $nvmeKey
        $spec.deviceChange += $ctrl
    }
    else {
        $nvmeKey = $nvmeCtrl.Key
    }


    # Add NVMe controller
    try {
        $vmObj.ExtensionData.ReconfigVM($spec)
        LogPrint "DONE: NVMe Controller Add successful"
    }
    catch {
        # Printout ERROR message
        $ERRORMessage = $_ | Out-String
        LogPrint $ERRORMessage
        return $false
    }


    # Refresh Key
    $vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
    if (-not $vmObj) {
        Write-ERROR -Message "INFO: Unable to Get-VM with $vmName" -Category OperationTimeout -ERRORAction SilentlyContinue
        return $false
    }
    $nvmeCtrl = $vmObj.ExtensionData.Config.Hardware.Device | Where-Object {$_.GetType().Name -eq "VirtualNVMEController"}  | Select-Object -First 1 
    $nvmeKey = $nvmeCtrl.Key


    # Create config
    $spec = New-Object VMware.Vim.VirtualMachineConfigSpec


    # Get next harddisk number (I use random here to make sure almost no duplicate harddisk num)
    $hdNUM = Get-Random -Minimum 10000 -Maximum 99999


    # Get datastore
    $dsName = $dataStore


    # Add NVMe hard disk
    $dev = New-Object VMware.Vim.VirtualDeviceConfigSpec
    $dev.FileOperation = "Create"
    $dev.Operation = "Add"
    $dev.Device = New-Object VMware.Vim.VirtualDisk
    $dev.Device.Backing = New-Object VMware.Vim.VirtualDiskFlatVer2BackingINFO
    $dev.Device.Backing.Datastore = ($vmObj.VMHost | Get-Datastore -Name $dsName).Extensiondata.MoRef
    $dev.Device.Backing.FileName = "[" + $dsName + "] " + $vmName + "/" + $vmName + "_" + $hdNUM + ".vmdk"
    $dev.Device.Backing.DiskMode = "persistent"


    # Setup Disk Storage format
    LogPrint "INFO: Storage format is $storageFormat"
    if ($storageFormat -eq "Thin") {
        $dev.Device.Backing.ThinProvisioned = $true   
        $dev.Device.Backing.EagerlyScrub = $false
    }
    elseif ($storageFormat -eq "Thick") {
        $dev.Device.Backing.ThinProvisioned = $false  
        $dev.Device.Backing.EagerlyScrub = $false
    }
    elseif ($storageFormat -eq "EagerZeroedThick") {
        $dev.Device.Backing.ThinProvisioned = $false  
        $dev.Device.Backing.EagerlyScrub = $true
    } else {
        LogPrint "ERROR: storage format not found"
        return $false
    }


    # Setup controller
    $dev.Device.CapacityInKb = $hdSize / 1KB
    $dev.Device.ControllerKey = $nvmeKey
    $dev.Device.UnitNumber = -1
    $spec.deviceChange += $dev


    # Refresh VM
    $vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
    if (-not $vmObj) {
        Write-ERROR -Message "INFO: Unable to Get-VM with $vmName" -Category OperationTimeout -ERRORAction SilentlyContinue
        return $false
    }


    try {
        $vmObj.ExtensionData.ReconfigVM($spec)
        LogPrint "DONE: NVMe Disk Add successful"
        return $true
    }
    catch {
        # Printout ERROR message
        $ERRORMessage = $_ | Out-String
        LogPrint $ERRORMessage
        return $false
    }
}


########################################################################################
# FindAllNewAddNIC()
########################################################################################
function FindAllNewAddNIC {
    Param
    (
        [String] $ipv4, 
        [String] $sshkey
    )
    <#
    .Synopsis
        Get all new add nic devicename
    .Description
        Get all new add nic devicename and this function will return a list which retrive from bash
    .Parameter ipv4
        ipv4 address of target VM
    .Parameter sshkey
        Name of the SSH key file to use.  Note this function assumes the
        ssh key a directory with a relative path of .\Ssh.
    .Outputs 
        A list which contain all other nics
    .Example
        $nics = FindAllNewAddNIC $ipv4 $sshkey
    #>
    
    # Get Old Adapter (SSH is using it) of VM
    $Command = "ip a | grep `$(echo `$SSH_CONNECTION | awk '{print `$3}') | awk '{print `$(NF)}'"
    $Old_Adapter = Write-Output y | bin\plink.exe -batch -i ssh\${sshKey} root@${ipv4} $Command
	Write-Host -F Red "DEBUG: Old_Adapter: ${Old_Adapter}."

    if ($null -eq $Old_Adapter) {
        LogPrint "ERROR : Cannot get Server_Adapter from first adapter."
        return $null
    }

    # Get all other nics
    $retVal = $null
    $Command = "ls /sys/class/net | grep e | grep -v $Old_Adapter"
    $new_nics = Write-Output y | bin\plink.exe -batch -i ssh\${sshKey} root@${ipv4} $Command
	Write-Host -F Red "DEBUG: new_nics: ${new_nics}."
    $retVal = ,$new_nics
    # Powershell  convert array to string if the array only has one element
    if ($null -eq $new_nics) {
        LogPrint "ERROR : Cannot get any NIC other than default NIC from guest."
        return $null
    }else{
        return $retVal
    }
}


#######################################################################################
# DisableMemoryReserve()
# #####################################################################################

function DisableMemoryReserve {
    param (
        [String] $vmName,
        [String] $hvServer
    )
    <#
    .Synopsis
        Disable memory reserve settings
    .Description
        Disable memory reserve settings, mainly for sr-iov cleanup step
    .Parameter vmName
        Name of the VM that need to add disk.
    .Parameter hvSesrver
        Name of the server hosting the VM.
    .Outputs
        Boolean
    .Example
        DisableMemoryReserve $vmName $hvServer
    #> 
    #Get Current VM
    $vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
    if (-not $vmObj) {
        LogPrint "ERROR: Unable to Get-VM with $vmName"
        DisconnectWithVIServer
        return $false
    }


    try {
        # Disable reserve all memory option (snapshot will not totally revert this option)
        $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
        $spec.memoryReservationLockedToMax = $false
        $vmObj.ExtensionData.ReconfigVM($spec)


        # This command make VM refresh their reserve memory option (snapshot will not revert this option)
        Get-VMResourceConfiguration -VM $vmObj | Set-VMResourceConfiguration -MemReservationMB 0
        if ( -not $?) {
            LogPrint "WARN: Reset memory lock failed" 
            return $false
        }
    }
    catch {
        $ERRORMessage = $_ | Out-String
        LogPrint "ERROR: Lock all memory ERROR, please check it manually"
        LogPrint $ERRORMessage
        return $false
    }


    return $true
}


#######################################################################################
# FindDstHost()
#######################################################################################
function FindDstHost {
    param (
        [String] $hvServer,
        [Parameter(Mandatory = $false)] [String] $Host6_5,
        [Parameter(Mandatory = $false)] [String] $Host6_7,
        [Parameter(Mandatory = $false)] [String] $Host7_0
    )    
    <#
    .Synopsis
        Find Dest Host Address
    .Description
        Find Dest Host Address from input ESXi 7.0,6.7,6.5 address set
    .Parameter vmName
        Name of the VM
    .Parameter hvServer
        Host of VM
    .Parameter Host6_5
        Address set in EXSi 6.5. such as "10.73.196.230,10.73.196.191"
    .Parameter Host6_7
        Address set in EXSi 6.7. such as "10.73.196.95,10.73.196.97"
    .Parameter Host7_0
        Address set in EXSi 7.0. such as "10.73.196.33,10.73.196.39"        
    .Outputs
        IP address string
    .Example
        FindDstHost -vmName $vmName -hvServer $hvServer -Host6_0 $dstHost6_0 -Host6_5 $dstHost6_5 -Host6_7 $dstHost6_7
    #> 

    # Get Host version
    $vm_host = Get-VMHost -Name $hvServer
    $version = $vm_host.Version

    # Help to setup amd 7.0 server
    $vmHost = Get-VMHost -Name $hvServer  
    # This may fail, try to delete -V2 param Current only support one card
    $esxcli = Get-EsxCli -VMHost $vmHost -V2
    # Get cpu info
    $cpuInfo = $esxcli.Hardware.cpu.list.Invoke() | Select-Object -ExpandProperty "Brand" -First 1
    # Reset dstHost6_7 if host is AMD
    if ($cpuInfo -like "*amd*") {
       $Host7_0 = "10.73.196.39,10.73.196.33" 
    }

    # Specify dst host.
    $dstHost = $null
    if ($PSBoundParameters.ContainsKey("Host7_0") -and $null -ne $Host7_0 -and  $version -eq "7.0.0") {
        $ip_addresses = $Host7_0.Split(",")
        if ($hvServer -eq $ip_addresses[0].Trim()) {
            $dsthost = $ip_addresses[1]
        }
        else {
            $dsthost = $ip_addresses[0]
        }
    }
    elseif ($PSBoundParameters.ContainsKey("Host6_7") -and $null -ne $Host6_7 -and $version -eq "6.7.0") {
        $ip_addresses = $Host6_7.Split(",")
        if ($hvServer -eq $ip_addresses[0].Trim()) {
            $dsthost = $ip_addresses[1]
        }
        else {
            $dsthost = $ip_addresses[0]
        }
    }
    elseif ($PSBoundParameters.ContainsKey("Host6_5") -and $null -ne $Host6_5 -and $version -eq "6.5.0") {
        $ip_addresses = $Host6_5.Split(",")
        if ($hvServer -eq $ip_addresses[0].Trim()) {
            $dsthost = $ip_addresses[1]
        }
        else {
            $dsthost = $ip_addresses[0]
        }
    }

    return $dstHost
}


#######################################################################
# CheckCallTrace()
#######################################################################
function CheckCallTrace {
    Param
    (
        [String] $ipv4, 
        [String] $sshkey
    )
    <#
    .Synopsis
        Function to checks if "Call Trace" message appears in the system logs
    .Description
        Function to checks if "Call Trace" message appears in the system logs, if system has Call Trace, function will return false
    .Parameter ipv4
        ipv4 address of target VM
    .Parameter sshkey
        Name of the SSH key file to use.  Note this function assumes the
        ssh key a directory with a relative path of .\Ssh.
    .Outputs 
        True or False
    .Example
        $status = CheckCallTrace $ipv4 $sshkey
    #>
    $Command = 'grep -w "Call Trace" /var/log/syslog /var/log/messages /var/log/dmesg.out'
    
	# Put dmesg content into /var/log/dmesg.out.
    $retVal = Write-Output y | bin\plink.exe -batch -i ssh\${sshKey} root@${ipv4} "dmesg > /var/log/dmesg.out"

	# Execute search command.
    $retVal = Write-Output y | bin\plink.exe -batch -i ssh\${sshKey} root@${ipv4} $Command
    Write-Output "DEBUG: retVal: $retVal"
    if ($null -ne $retVal) {
       return $false
    }else {
        return $true
    }
}


########################################################################################
# resetGuestSRIOV()
########################################################################################
function resetGuestSRIOV {
    param (
        [String] $vmName,
        [String] $hvServer,
        [String] $dstHost,
        $oldDatastore
    )
    <#
    .Synopsis
        Help to reset guest to origin host
    .Description[String] $hvServer
        Help to reset guest to origin host, mainly for migration cases
    .Parameter vmName
        Name of the VM
    .Parameter hvServer
        Host of VM, original host
    .Parameter dstHost
        VM current Host
    .Parameter oldDatastore
        VM old datastooe
    .Example
        resetGuestSRIOV -vmName $vmName -hvServer $hvServer -dstHost $dstHost -oldDatastore $oldDatastore
    #>
    
    LogPrint "WARN: Start to run reset function"
    $vmObj = Get-VMHost -Name $dstHost | Get-VM -Name $vmName
    if (-not $vmObj) {
        LogPrint "ERROR: Unable to Get-VM with $vmName"
        DisconnectWithVIServer
        return $Aborted
    } 


    # Poweroff VM
    $status = Stop-VM $vmObj -Confirm:$False
    if (-not $?) {
        LogPrint "ERROR: Cannot stop VM $vmName, $status"
        DisconnectWithVIServer
        return $Aborted
    }


    # refresh VM
    $vmObj = Get-VMHost -Name $dstHost | Get-VM -Name $vmName


    # Move VM back to host
    $task = Move-VM -VMotionPriority High -VM $vmObj -Destination (Get-VMHost $hvServer) `
        -Datastore $oldDatastore -Confirm:$false -RunAsync:$true -ErrorAction SilentlyContinue
    LogPrint "INFO: Move VM back to old host and old datastore in Reset function"
    $status = Wait-Task -Task $task
    LogPrint "INFO: Migration result is $status"


    Start-Sleep -Seconds 6

    # Refresh status
    $vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
    # Start Guest
    Start-VM -VM $vmObj -Confirm:$false -RunAsync:$true -ErrorAction SilentlyContinue


    # Wait for SSH ready
    if ( -not (WaitForVMSSHReady $vmName $hvServer $sshKey 300)) {
        LogPrint "ERROR : Cannot start SSH"
        DisconnectWithVIServer
        return $Aborted
    }
    LogPrint "INFO: In reset function, VM already started"
}


########################################################################################
# SkipTestInHost()
########################################################################################
function SkipTestInHost([String] $hvServer, [Array] $skip_hosts) 
{
    # Define 3RD-ESXi team automatiuon hardware ENV.
    $automation_hosts = ("6.0.0", "6.5.0", "6.7.0", "6.7.0-amd", "7.0.0-amd")

    $host_obj = Get-VMHost -Name $hvServer
    $host_ver = $host_obj.version
    Write-Host -F Red "DEBUG: host_ver: $host_ver"

    $processer_type =  $host_obj.ProcessorType
    Write-Host -F Red "DEBUG: processer_type: $processer_type"
    if($processer_type.Contains("AMD"))
    {
        $host_ver = $host_ver + "-amd"
        Write-Host -F Red "INFO: AMD Machine: $host_ver"
    }

    # Confirm hosts want to be skipped match automation hardware ENV.
    foreach ($i in $skip_hosts)
    {
        if($automation_hosts -notcontains $i)
        {
            Write-Host -F Red "ERROR: Host want to be skipped is not in automation hosts list ($automation_hosts). Please confirm"
            return $false
        }
    }

    # Skip test if current host match hosts list want to be skipped.
    if($skip_hosts -contains $host_ver)
    {
        Write-Host -F Red "INFO: Host $host_ver belongs to skip list, skip all test"
        return $true
    }
    else
    {
        Write-Host -F Red "INFO: Host $host_ver DOESN'T belongs to hosts list want to be skipped. Keep going below testing."
        return $false
    }
}


########################################################################################
# RemoveVM()
########################################################################################
function RemoveVM {
    param (
        [String] $vmName,
        [String] $hvServer
    )
    <#
    .Synopsis
        Help to remove vm that not used
    .Description
        Help toremove vm that not used, mainly for cloned cases, such as cloud-init and ovt customization guest cases
    .Parameter vmName
        Name of the VM
    .Parameter hvServer
        Host of VM, original host
    .Example
        RemoveVM -vmName $vmName -hvServer $hvServer
    #>
    
    LogPrint "INFO: Check the vm exists."
    $vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
    if (-not $vmObj) {
        LogPrint "ERROR: Unable to Get-VM with $vmName."
        DisconnectWithVIServer
        return $Aborted
    } 

    # Poweroff VM
    $off = Stop-VM $vmObj -Confirm:$False

    Start-Sleep 6

    $vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
	if ($vmObj.PowerState -ne "PoweredOff")
    {
        LogPrint "ERROR: Cannot stop VM $vmName, $status."
        DisconnectWithVIServer
        return $Aborted
    }

    # Remove VM
    $status = Remove-VM -VM $vmObj -DeletePermanently -Confirm:$false | out-null

    $vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
    if (-not $vmObj) {
    	LogPrint "INFO: Remove vm successfully."
        DisconnectWithVIServer
        return $true
    } 
	else{
        LogPrint "ERROR: Remove VM failed as find it again."
        return $false
	}
}

