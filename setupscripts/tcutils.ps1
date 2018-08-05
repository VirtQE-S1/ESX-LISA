###############################################################################
##
## ___________ _____________  ___         .____    .___  _________   _____
## \_   _____//   _____/\   \/  /         |    |   |   |/   _____/  /  _  \
##  |    __)_ \_____  \  \     /   ______ |    |   |   |\_____  \  /  /_\  \
##  |        \/        \ /     \  /_____/ |    |___|   |/        \/    |    \
## /_______  /_______  //___/\  \         |_______ \___/_______  /\____|__  /
##         \/        \/       \_/                 \/           \/         \/
##
###############################################################################
##
## ESX-LISA is an automation testing framework based on github.com/LIS/lis-test
## project. In order to support ESX, ESX-LISA uses PowerCLI to automate all
## aspects of vSphere maagement, including network, storage, VM, guest OS and
## more. This framework automates the tasks required to test the
## Redhat Enterprise Linux Server on WMware ESX Server.
##
###############################################################################
##
## Revision:
## v1.0 - xiaofwan - 11/25/2016 - Fork from github.com/LIS/lis-test.
##                                Incorporate VMware PowerCLI with framework
## v1.1 - xiaofwan - 12/28/2016 - Add GetLinuxDsitro method.
## v1.2 - xiaofwan - 1/6/2017 - Add PowerCLI import, connecting VCenter server
##                              disconnecting VCenter server functions.
## v1.3 - hhei     - 1/10/2017 - Add CheckModule function; update GetLinuxDistro.
## v1.4 - xiaofwan - 1/25/2016 - Add four test result state RO variable to mark
##                               test case result.
## v1.5 - xiaofwan - 2/28/2016 - Add WaitForVMSSHReady function.
##
## v1.5.1 - ruqin  - 7/6/2018  - Add GetModuleVersion function
##
## v1.5.2 - ruqin  - 7/27/2018 - Add RevertSnapshotVM function
##
###############################################################################

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

###############################################################################
#
# Import VMware Powershell module
#
###############################################################################
function PowerCLIImport () {
   <#
    .Description
        Import VMware.VimAutomation.Core module if it does not exist.
    #>
    $modules = Get-Module

    $foundVimautomation = $False
    foreach($module in $modules)
    {
        if($module.Name -eq "VMware.VimAutomation.Core")
        {
            "Info: PowerCLI module VMware.VimAutomation.Core already exists."
            $foundVimautomation = $True
            break
        }
    }

    if (-not $foundVimautomation)
    {
        Import-Module VMware.VimAutomation.Core
    }
}

###############################################################################
#
# Connect to VI Server
#
###############################################################################
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

    #
    # Verify the VIServer related environment variable existed.
    #
    if (-not $visIpAddr)
    {
        "Error : vCenter IP address is not configured, it is required."
        exit
    }

    if (-not $visUsername)
    {
        "Error : vCenter login username is not configured, it is required."
        exit
    }

    if (-not $visPassword)
    {
        "Error : vCenter login password is not configured, it is required."
        exit
    }

    if (-not $visProtocol)
    {
        "Error : vCenter connection method is not configured, it is required."
        exit
    }

    #
    # Check the PowerCLI package installed
    #
    Get-PowerCLIVersion | out-null
    if (-not $?)
    {
        "Error : Please install VMWare PowerCLI package."
        exit
    }

    if (-not $global:DefaultVIServer)
    {
        "Info : Connecting with VIServer $visIpAddr."
        Connect-VIServer -Server $visIpAddr `
                         -Protocol $visProtocol `
                         -User $visUsername `
                         -Password $visPassword `
                         -Force | Out-Null
        if (-not $?)
        {
            "Error : Cannot connect with vCenter with $visIpAddr " +
            "address, $visProtocol protocol, username $visUsername, " +
            "and password $visPassword."
            exit
        }
        "Debug : vCenter connected with " +
        "session id $($global:DefaultVIServer.SessionId)"
    }
    else
    {
        "Info : vCenter connected already! " +
        "Session id: $($global:DefaultVIServer.SessionId)"
    }
}
###############################################################################
#
# Disconnect with VI Server
#
###############################################################################
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
            "Info : Disconnect with VIServer $($viserver.name)."
            Disconnect-VIServer -Server $viserver -Force -Confirm:$False
        }
    }
    else
    {
        "Info : There is not session to VI Server exist."
    }
}

#######################################################################
#
# GetLinuxDsitro()
#
#######################################################################
function GetLinuxDistro([String] $ipv4, [String] $sshKey)
{
    <#
    .Synopsis
        Get Linux Distro info from a Linux VM.
    .Description
        Use SSH to het Linux Distro info from a Linux VM.
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
        Write-Error -Message "IPv4 address is null" -Category InvalidData -ErrorAction SilentlyContinue
        return $null
    }

    if (-not $sshKey)
    {
        Write-Error -Message "SSHKey is null" -Category InvalidData -ErrorAction SilentlyContinue
        return $null
    }

    $distro = bin\plink -i ssh\${sshKey} root@${ipv4} "grep -Ehs 'Ubuntu|SUSE|Fedora|Debian|CentOS|Red Hat Enterprise Linux (Server |)release [0-9]{1,2}.[0-9]{1,2}|Oracle' /etc/{issue,*release,*version}"
	Write-Host -F red "Debug: distro: $distro"
    if (-not $distro)
    {
        Write-Error -Message "Return value is null" -Category InvalidData -ErrorAction SilentlyContinue
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
        "*Oracle*" {  $linuxDistro = "Oracle"
                       break
                    }
        default     {  $linuxDistro = "Unknown"
                       break
                    }
    }

    return ${linuxDistro}
}

#####################################################################
#
# GetFileFromVM()
#
#####################################################################
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

    $retVal = $False

    if (-not $ipv4)
    {
        Write-Error -Message "IPv4 address is null" -Category InvalidData -ErrorAction SilentlyContinue
        return $False
    }

    if (-not $sshKey)
    {
        Write-Error -Message "SSHKey is null" -Category InvalidData -ErrorAction SilentlyContinue
        return $False
    }

    if (-not $remoteFile)
    {
        Write-Error -Message "remoteFile is null" -Category InvalidData -ErrorAction SilentlyContinue
        return $False
    }

    if (-not $localFile)
    {
        Write-Error -Message "localFile is null" -Category InvalidData -ErrorAction SilentlyContinue
        return $False
    }

    $process = Start-Process bin\pscp -ArgumentList "-i ssh\${sshKey} root@${ipv4}:${remoteFile} ${localFile}" -PassThru -NoNewWindow -Wait -redirectStandardOutput lisaOut.tmp -redirectStandardError lisaErr.tmp
    if ($process.ExitCode -eq 0)
    {
        $retVal = $True
    }
    else
    {
        Write-Error -Message "Unable to get file '${remoteFile}' from ${ipv4}" -Category ConnectionError -ErrorAction SilentlyContinue
        return $False
    }

    del lisaOut.tmp -ErrorAction "SilentlyContinue"
    del lisaErr.tmp -ErrorAction "SilentlyContinue"

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
        Write-Error -Message "GetIPv4ViaPowerCLI: Unable to create VM object for VM $vmName" -Category ObjectNotFound -ErrorAction SilentlyContinue
        return $null
    }

    $vmguestOut = Get-VMGuest -VM $vmObj
    if (-not $vmguestOut)
    {
        Write-Error -Message "GetIPv4ViaPowerCLI: Unable to create VM object for VM $vmName" -Category ObjectNotFound -ErrorAction SilentlyContinue
        return $null
    }
    $ipAddresses = $vmguestOut.IPAddress
    if (-not $ipAddresses)
    {
        Write-Error -Message "GetIPv4ViaPowerCLI: No network adapters found on VM $vmName" -Category ObjectNotFound -ErrorAction SilentlyContinue
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
        $ping = New-Object System.Net.NetworkInformation.Ping
        $sts = $ping.Send($address)
        if ($sts -and $sts.Status -eq [System.Net.NetworkInformation.IPStatus]::Success)
        {
            return $address
        }
    }

    Write-Error -Message "GetIPv4ViaPowerCLI: No IPv4 address found on any NICs for VM ${vmName}" -Category ObjectNotFound -ErrorAction SilentlyContinue
    return $null
}

#######################################################################
#
# GetIPv4()
#
#######################################################################
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
        $errMsg += ("`n" + $error[0].Exception.Message)
        Write-Error -Message ("GetIPv4: Unable to determine IP address for VM ${vmName}`n" + $errmsg) -Category ReadError -ErrorAction SilentlyContinue
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
    [int]$i= $null
    [int]$check = $null
    if ($oldipv4 -eq $null){
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

    $retVal = $False

    if (-not $ipv4)
    {
        Write-Error -Message "ipv4 is null" -Category InvalidData -ErrorAction SilentlyContinue
        return $False
    }

    if (-not $sshKey)
    {
        Write-Error -Message "sshKey is null" -Category InvalidData -ErrorAction SilentlyContinue
        return $False
    }

    if (-not $command)
    {
        Write-Error -Message "command is null" -Category InvalidData -ErrorAction SilentlyContinue
        return $False
    }

    # get around plink questions
    echo y | bin\plink.exe -i ssh\${sshKey} root@${ipv4} 'exit 0'
    $process = Start-Process bin\plink -ArgumentList "-i ssh\${sshKey} root@${ipv4} ${command}" -PassThru -NoNewWindow -Wait -redirectStandardOutput lisaOut.tmp -redirectStandardError lisaErr.tmp
    if ($process.ExitCode -eq 0)
    {
        $retVal = $True
    }
    else
    {
         Write-Error -Message "Unable to send command to ${ipv4}. Command = '${command}'" -Category SyntaxError -ErrorAction SilentlyContinue
    }

    del lisaOut.tmp -ErrorAction "SilentlyContinue"
    del lisaErr.tmp -ErrorAction "SilentlyContinue"

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
        Write-Error -Message "ipv4 is null" -Category InvalidData -ErrorAction SilentlyContinue
        return $False
    }

    if (-not $sshKey)
    {
        Write-Error -Message "sshkey is null" -Category InvalidData -ErrorAction SilentlyContinue
        return $False
    }

    if (-not $localFile)
    {
        Write-Error -Message "localFile is null" -Category InvalidData -ErrorAction SilentlyContinue
        return $False
    }

    if (-not $remoteFile)
    {
        Write-Error -Message "remoteFile is null" -Category InvalidData -ErrorAction SilentlyContinue
        return $False
    }

    $recurse = ""
    if (test-path -path $localFile -PathType Container )
    {
        $recurse = "-r"
    }

    # get around plink questions
    echo y | bin\plink.exe -i ssh\${sshKey} root@${ipv4} "exit 0"

    $process = Start-Process bin\pscp -ArgumentList "-i ssh\${sshKey} ${localFile} root@${ipv4}:${remoteFile}" -PassThru -NoNewWindow -Wait -redirectStandardOutput lisaOut.tmp -redirectStandardError lisaErr.tmp
    if ($process.ExitCode -eq 0)
    {
        $retVal = $True
    }
    else
    {
        Write-Error -Message "Unable to send file '${localFile}' to ${ipv4}" -Category ConnectionError -ErrorAction SilentlyContinue
    }

    del lisaOut.tmp -ErrorAction "SilentlyContinue"
    del lisaErr.tmp -ErrorAction "SilentlyContinue"

    if ($ChangeEOL)
    {
        .bin\plink -i ssh\${sshKey} root@${ipv4} "dos2unix $remoteFile"
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
        Write-Error -Message "StopVMViaSSH: VM name is null" -Category ObjectNotFound -ErrorAction SilentlyContinue
        return $False
    }

    if (-not $sshKey)
    {
        Write-Error -Message "StopVMViaSSH: SSHKey is null" -Category ObjectNotFound -ErrorAction SilentlyContinue
        return $False
    }

    if (-not $timeout)
    {
        Write-Error -Message "StopVMViaSSH: timeout is null" -Category ObjectNotFound -ErrorAction SilentlyContinue
        return $False
    }

    $vmipv4 = GetIPv4 $vmName $server
    if (-not $vmipv4)
    {
        Write-Error -Message "StopVMViaSSH: Unable to determine VM IPv4 address" -Category ObjectNotFound -ErrorAction SilentlyContinue
        return $False
    }

    #
    # Tell the VM to stop
    #
    echo y | bin\plink -i ssh\${sshKey} root@${vmipv4} exit
    .\bin\plink.exe -i ssh\${sshKey} root@${vmipv4} "init 0"
    if (-not $?)
    {
        Write-Error -Message "StopVMViaSSH: Unable to send command via SSH" -Category ObjectNotFound -ErrorAction SilentlyContinue
        return $False
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
            return $False
        }

        if ($vm.PowerState -eq "PoweredOff")
        {
            return $True
        }
    }

    Write-Error -Message "StopVMViaSSH: VM did not stop within timeout period" -Category OperationTimeout -ErrorAction SilentlyContinue
    return $False
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

    $retVal = $False
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

    $retVal = $False

    $waitTimeOut = $timeout
    while($waitTimeOut -gt 0)
    {
        $sts = TestPort -ipv4addr $ipv4addr -timeout 5
        if ($sts)
        {
            return $True
        }

        $waitTimeOut -= 15  # Note - Test Port will sleep for 5 seconds
        Start-Sleep -s 10
    }

    if (-not $retVal)
    {
        Write-Error -Message "WaitForVMToStartSSH: VM ${vmName} did not start SSH within timeout period ($timeout)" -Category OperationTimeout -ErrorAction SilentlyContinue
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
            $result = echo y | bin\plink -i ssh\${sshKey} root@${vmipv4} "echo 911"
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
        Write-Error -Message "WaitForVMSSHReady: VM ${vmName} did not start SSH within timeout period ($timeout)" -Category OperationTimeout -ErrorAction SilentlyContinue
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
            return $False
        }

        if ($vm.PowerState -eq "PoweredOff")
        {
            return $True
        }
    }

    Write-Error -Message "StopVM: VM did not stop within timeout period" -Category OperationTimeout -ErrorAction SilentlyContinue
    return $False
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
        Write-Error -Message "AddIDEHardDisk: Unable to Get-VM with $vmName" -Category OperationTimeout -ErrorAction SilentlyContinue
        return $false
    }
    $hdSize = $capacityGB * 1GB

    $vm = $vmObj
    $spec = New-Object VMware.Vim.VirtualMachineConfigSpec

    # Check if there is an IDE COntroller present
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

    # Get next harddisk number
    $hdNUM = Get-Random -Minimum 10000 -Maximum 99999

    # Get datastore
    $dsName = $vm.ExtensionData.Config.Files.VmPathName.Split(']')[0].TrimStart('[')

    # Add IDE hard disk
    $dev = New-Object VMware.Vim.VirtualDeviceConfigSpec
    $dev.FileOperation = "Create"
    $dev.Operation = "Add"
    $dev.Device = New-Object VMware.Vim.VirtualDisk
    $dev.Device.backing = New-Object VMware.Vim.VirtualDiskFlatVer2BackingInfo
    $dev.Device.backing.Datastore = (Get-Datastore -Name $dsName).Extensiondata.MoRef
    $dev.Device.backing.DiskMode = "persistent"
    $dev.Device.Backing.FileName = "[" + $dsName + "] " + $vmName + "/" + $vmName + "_" + $hdNUM + ".vmdk"

    Write-Host -F Red "$dev.Device.Backing.FileName"
    Write-Host "$dev.Device.Backing.FileName"

    $dev.Device.backing.ThinProvisioned = $true
    $dev.Device.CapacityInKb = $hdSize / 1KB
    $dev.Device.ControllerKey = $ideKey
    $dev.Device.UnitNumber = -1
    $spec.deviceChange += $dev

    $vm.ExtensionData.ReconfigVM($spec)

    return $true
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
        "Error: VM name is null"
        return $False
    }
    $vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
    while ($True) {
        # How many disks in VM
        $diskList = Get-HardDisk -VM $vmObj
        $diskLength = $diskList.Length

        # If disks counts great than 1, will delete them
        if ($diskList.Length -gt 1) {
            foreach ($disk in $diskList) {
                $diskName = $disk.Name
                if ($diskName -ne $sysDisk) {
                    Get-HardDisk -VM $vmObj -Name $($diskName) | Remove-HardDisk -Confirm:$False -DeletePermanently:$True -ErrorAction SilentlyContinue
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
        return $True
    }
    else {
        Write-Output "FAIL: Clean disk new added unsuccessfully"
        return $False
    }
    return $False
}



#######################################################################
#
# Runs a remote script on the VM and returns the log.
#
#######################################################################
function RunRemoteScript($remoteScript)
{
    $retValue = $False
    $stateFile     = "state.txt"
    $TestCompleted = "TestCompleted"
    $TestAborted   = "TestAborted"
    $TestFailed   = "TestFailed"
    $TestRunning   = "TestRunning"
    $timeout       = 6000

    "./${remoteScript} > ${remoteScript}.log" | out-file -encoding ASCII -filepath runtest.sh

    .\bin\pscp -i ssh\${sshKey} .\runtest.sh root@${ipv4}:
    if (-not $?)
    {
       Write-Output "ERROR: Unable to copy runtest.sh to the VM"
       return $False
    }
     .\bin\pscp -i ssh\${sshKey} .\remote-scripts\${remoteScript} root@${ipv4}:
    if (-not $?)
    {
       Write-Output "ERROR: Unable to copy ${remoteScript} to the VM"
       return $False
    }

    .\bin\plink.exe -i ssh\${sshKey} root@${ipv4} "dos2unix ${remoteScript} 2> /dev/null"
    if (-not $?)
    {
        Write-Output "ERROR: Unable to run dos2unix on ${remoteScript}"
        return $False
    }

    .\bin\plink.exe -i ssh\${sshKey} root@${ipv4} "dos2unix runtest.sh  2> /dev/null"
    if (-not $?)
    {
        Write-Output "ERROR: Unable to run dos2unix on runtest.sh"
        return $False
    }

    .\bin\plink.exe -i ssh\${sshKey} root@${ipv4} "chmod +x ${remoteScript}   2> /dev/null"
    if (-not $?)
    {
        Write-Output "ERROR: Unable to chmod +x ${remoteScript}"
        return $False
    }
    .\bin\plink.exe -i ssh\${sshKey} root@${ipv4} "chmod +x runtest.sh  2> /dev/null"
    if (-not $?)
    {
        Write-Output "ERROR: Unable to chmod +x runtest.sh " -
        return $False
    }

    # Run the script on the vm
    .\bin\plink.exe -i ssh\${sshKey} root@${ipv4} "./runtest.sh"

    # Return the state file
    while ($timeout -ne 0 )
    {
    .\bin\pscp -q -i ssh\${sshKey} root@${ipv4}:${stateFile} . #| out-null
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
                        Write-Output "Info : state file contains Testcompleted."
                        $retValue = $True
                        break
                    }

                    if ($contents -eq $TestAborted)
                    {
                         Write-Output "Info : State file contains TestAborted message."
                         break
                    }
                    if ($contents -eq $TestFailed)
                    {
                        Write-Output "Info : State file contains TestFailed message."
                        break
                    }
                    $timeout--

                    if ($timeout -eq 0)
                    {
                        Write-Output "Error : Timed out on Test Running , Exiting test execution."
                        break
                    }

            }
            else
            {
                Write-Output "Warn : state file is empty"
                break
            }

        }
        else
        {
             Write-Host "Warn : ssh reported success, but state file was not copied"
             break
        }
    }
    else
    {
         Write-Output "Error : pscp exit status = $sts"
         Write-Output "Error : unable to pull state.txt from VM."
         break
    }
    }

    # Get the logs
    $remoteScriptLog = $remoteScript+".log"

    bin\pscp -q -i ssh\${sshKey} root@${ipv4}:${remoteScriptLog} .
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
                        move "${remoteScriptLog}" "${TestLogDir}\${remoteScriptLog}"
                    }

                    else
                    {
                        Write-Output "INFO: $remoteScriptLog is copied in ${rootDir}"
                    }

            }
            else
            {
                Write-Output "Warn: $remoteScriptLog is empty"
            }
        }
        else
        {
             Write-Output "Warn: ssh reported success, but $remoteScriptLog file was not copied"
        }
    }

    # Cleanup
    del state.txt -ErrorAction "SilentlyContinue"
    del runtest.sh -ErrorAction "SilentlyContinue"

    return $retValue
}

#######################################################################
#
# Check module version in vm.
#
#######################################################################

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
        Write-Error -Message "ipv4 is null" -Category InvalidData -ErrorAction SilentlyContinue
        return $False
    }

    if (-not $sshKey)
    {
        Write-Error -Message "sshkey is null" -Category InvalidData -ErrorAction SilentlyContinue
        return $False
    }

    if (-not $module)
    {
        Write-Error -Message "module name is null" -Category InvalidData -ErrorAction SilentlyContinue
        return $False
    }
    
    # get around plink questions
    Write-Output y | bin\plink.exe -i ssh\${sshKey} root@${ipv4} "exit 0"

    $module_version = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "modinfo $module | grep -w version: | awk '{print `$2}'"

    return $module_version.Trim()
}


#######################################################################
#
# Check modules in vm.
#
#######################################################################
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
        Write-Error -Message "ipv4 is null" -Category InvalidData -ErrorAction SilentlyContinue
        return $False
    }

    if (-not $sshKey)
    {
        Write-Error -Message "sshkey is null" -Category InvalidData -ErrorAction SilentlyContinue
        return $False
    }

    if (-not $module)
    {
        Write-Error -Message "module name is null" -Category InvalidData -ErrorAction SilentlyContinue
        return $False
    }
    # get around plink questions
    echo y | bin\plink.exe -i ssh\${sshKey} root@${ipv4} "exit 0"

    $vm_module = bin\plink.exe -i ssh\${sshKey} root@${ipv4} "lsmod | grep -w ^$module | awk '{print `$1}'"
    Write-Host -F Red "DEBUG: tcutils.ps1: vm_module: $vm_module"
    if ( $vm_module.Trim() -eq $module.Trim() )
    {
        return $True
    }
    else
    {
        return $False
    }

}

########################################################################
#
# ConvertStringToDecimal()
#
########################################################################
function ConvertStringToDecimal([string] $str)
{
    $uint64Size = $null

    #
    # Make sure we received a string to convert
    #
    if (-not $str)
    {
        Write-Error -Message "ConvertStringToDecimal() - input string is null" -Category InvalidArgument -ErrorAction SilentlyContinue
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
        Write-Error -Message "Invalid newSize parameter: ${str}" -Category InvalidArgument -ErrorAction SilentlyContinue
        return $null
    }

    return $uint64Size
}

########################################################################
#
# LogPrint()
#
########################################################################

function LogPrint([string] $msg) {

    $now = [Datetime]::Now.ToString("MM/dd/yyyy HH:mm:ss : ")
    $color = "white"
    if ( $msg.StartsWith("Error")) {
        $color = "red"
    }
    elseif ($msg.StartsWith("Warn")) {
        $color = "Yellow"
    }
    else {
        $color = "gray"
    }
    Write-Host -f $color ($now + $msg)
    Write-Output ($now + $msg)
}

########################################################################
# 
# Mainly use for two guest test case, help user to revert snapshot of Guest-B
#
# RevertSnapshotVM()
#
########################################################################
function RevertSnapshotVM([String] $vmName, [String] $hvServer) {
    <#
    .Synopsis
        Make sure the test VM is stopped
    .Description
        Stop the test VM and then reset it to a snapshot.
        This ensures the VM starts the test run in a
        known good state.
    .Parameter vmName
        Name of the VM that need to add disk.
    .Parameter hvSesrver
        Name of the server hosting the VM.
    .Example
        ResetVM $vmName $hvServer
    #>

    if (-not $vmName -or -not $hvServer) {
        LogPrint "Error : ResetVM was passed an bad vmName or bad hvServer"
        return $false
    }

    LogPrint "Info : ResetVM( $($vmName) )"

    $vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
    if (-not $vmObj) {
        LogPrint "Error : ResetVM cannot find the VM $($vmName)"
        return $false
    }

    #
    # If the VM is not stopped, try to stop it
    #
    if ($vmObj.PowerState -ne "PoweredOff") {
        LogPrint "Info : $($vmName) is not in a stopped state - stopping VM"
        $outStopVm = Stop-VM -VM $vmObj -Confirm:$false -Kill
        if ($outStopVm -eq $false -or $outStopVm.PowerState -ne "PoweredOff") {
            LogPrint "Error : ResetVM is unable to stop VM $($vmName). VM has been disabled"
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
                LogPrint "Info : $($vmName) is being reset to snapshot $($s.Name)"
                $setsnapOut = Set-VM -VM $vmObj -Snapshot $s -Confirm:$false
                if ($setsnapOut) {
                    $snapshotFound = $true
                    break
                }
                else {
                    LogPrint "Error : ResetVM is unable to revert VM $($vmName) to snapshot $($s.Name). VM has been disabled"
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
                LogPrint "Info : $($vmName) - resetting to a stopped state after restoring a snapshot"
                $stopvmOut = Stop-VM -VM $vmObj -Confirm:$false -Kill
                if ($stopvmOut -or $stopvmOut.PowerState -ne "PoweredOff") {
                    LogPrint "Error : ResetVM is unable to stop VM $($vmName). VM has been disabled"
                    return $false
                }
            }
        }
        else {
            LogPrint "Error : ResetVM cannot find the VM $($vmName)"
            return $false
        }
    }
    else {
        LogPrint "Warn : There's no snapshot with name $snapshotName found in VM $($vmName). Making a new one now."
        $newSnap = New-Snapshot -VM $vmObj -Name $snapshotName
        if ($newSnap) {
            $snapshotFound = $true
            LogPrint "Info : $($vmName) made a snapshot $snapshotName."
        }
        else {
            LogPrint "Error : ResetVM is unable to make snapshot for VM $($vmName)."
            return $false
        }
    }

    return $true
}
