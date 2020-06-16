########################################################################################
## ___________ _____________  ___         .____    .___  _________   _____   
## \_   _____//   _____/\   \/  /         |    |   |   |/   _____/  /  _  \  
##  |    __)_ \_____  \  \     /   ______ |    |   |   |\_____  \  /  /_\  \ 
##  |        \/        \ /     \  /_____/ |    |___|   |/        \/    |    \
## /_______  /_______  //___/\  \         |_______ \___/_______  /\____|__  /
##         \/        \/       \_/                 \/           \/         \/ 
########################################################################################
## ESX-LISA is an automation testing framework based on github.com/LIS/lis-test 
## project. In order to support ESX, ESX-LISA uses PowerCLI to automate all 
## aspects of vSphere maagement, including network, storage, VM, guest OS and 
## more. This framework automates the tasks required to test the 
## Redhat Enterprise Linux Server on WMware ESX Server.
########################################################################################
## Revision:
##  v1.0.0 - xiaofwan - 11/25/2016 - Fork from github.com/LIS/lis-test.
##                                Incorporate VMware PowerCLI with framework
##  v1.1.0 - xiaofwan - 11/28/2016 - Merge SendEmail and SummaryToString update
##                                Merge bug fix from LISA
##  v1.2.0 - xiaofwan - 01/22/2017 - Fix a typo issue
##  v1.3.0 - xiaofwan - 01/23/2017 - Insert suite name into result dir name, such as
##                               cases-open_vm_tools-20170120-141152
##  v1.4.0 - xiaofwan - 01/26/2017 - Remove TC_COVERED param due to useless any more
##  v1.5 .0- xiaofwan - 02/03/2017 - $True will be $true and $False will be $false.
##  v2.0.0 - xiaofwan - 02/04/2017 - Add running time and JUnit XML result support.
##  v2.0.1 - xiaofwan - 02/04/2017 - Remove Test-Admin function.
##  v2.1.0 - boyang - 01/08/2020 - Revision 2.1.0 release.
########################################################################################


<#
.Synopsis
    Perform tests on a VM as defined in a .xml file
.Description
    This powershell script automates the tasks required to test
    the Redhat Enterprise Linux Server on WMware Server.
    This script is the entry script into the automation.  The basics
    behavior of the automation is:
        Start a VM
        Push files to a VM
        Start a script executing on a VM
        Collect files from a VM
        Shutdown a VM

    Other required powershell scripts includes:
        stateEngine.ps1
            Provides the functions that drive the VMs through
            various states that result in a test case being
            run on a VM.

         utilFunctions.ps1
             Provides utility functions used by the automation.

         OSAbstractions.ps1
             Functions that return a OS specific command line.  This
             was added when Integrated services were added to
             FreeBSD.

    A test run is driven by an XML file.  A sample command might look
    like the following:

        .\lisa.ps1 run xml\debug_demo.xml -dbgLevel 5

    The XML file has a number of key sections as follows:
        Global
            The global section defines settings used to specify where
            the log files are to be written, who to send email to,
            which email server to use, etc.

        TestSuites
            This section defines a test suite and lists all the test
            cases the test suite will run.

        TestCases
            This section defines every test case that a test suite
            might call.  Test case definitions include the following:
                Name of the test case
                The test script to run on the VM
                The file to push to the VM
                Test case timeout value (in seconds)
                What to do on error (stop testing or move on to next test case)
                Test parameters
                    Test parameters are placed in a file named constants.sh
                    and then copied to the VM.  The test case script can
                    source constants.sh to gain accesws to the test parameters.

        VMs
            The VMs section lists the VMs that will run tests.  There will be a
            VM definition for each VM that will run a test.  Each VM can run
            a separate test suite.

    A very simple XML file would look something like the following:

    <?xml version="1.0" encoding="utf-8"?>
    <config>
        <global>
            <logfileRootDir>TestResults</logfileRootDir>
            <defaultSnapshot>ICABase</defaultSnapshot>
            <email>
                <recipients>
                    <to>myboss@mycompany.com</to>
                    <to>myself@mycompany.com</to>
                </recipients>
                <sender>myself@mycompany.com</sender>
                <subject>ESX demo Test</subject>
                <smtpServer>mysmtphost.mycompany.com</smtpServer>
            </email>
        </global>

        <testSuites>
            <suite>
                <suiteName>debug_demo_suite</suiteName>
                <suiteTests>
                    <suiteTest>debug_demo_case</suiteTest>
                </suiteTests>
            </suite>
        </testSuites>

        <testCases>
            <test>
                <testName>debug_demo_case</testName>
                <testID>ESX-DEMO-001</testID>
                <testScript>testscripts\debug_demo.ps1</testScript>
                <RevertDefaultSnapshot>True</RevertDefaultSnapshot>
                <timeout>120</timeout>
                <onError>Continue</onError>
                <noReboot>False</noReboot>
            </test>
        </testCases>

        <VMs>
            <vm>
                <hvServer>ESXI_HOST_IPADDRESS</hvServer>
                <vmName>VM_NAME</vmName>
                <os>Linux</os>
                <ipv4></ipv4>
                <sshKey>demo_id_rsa.ppk</sshKey>
                <suite>debug_demo_suite</suite>
            </vm>
        </VMs>

    </config>


    The automation scripts make some assumptions about the VMs
    used to run the tests.  This requires test VMs be provisioned
    prior to running tests.
    
    SSH keys are used to pass commands to Linux VMs, so the public
    ssh Key must to copied to the VM before the test is started.

    The dos2unix must be installed.  It is used to ensure the file
    has the correct end of line character.

    The automation scripts currently use Putty as the SSH client.
    You will need to copy the Putty executables to the lisa/bin
    directory.  You will also need to convert the private key into
    a Putty Private Key (.ppk).

.Parameter cmdVerb
    The command you wish to perform.  Supported values include
        run
        help
.Parameter cmdNoun
    The object the command verb is to operate on. Normally this
    is the .xml file that defines the test suites, test cases and
    VMs on which to perform tests.
.Parameter VMs
    A subset of VMs to run the tests on.  The list of VMs is defined
    in the .xml file.  The VMs parameter contains a subset of these
    VMs.  Tests will only be run on the subset of VMs rather than
    all VMs defined in the .xml file.
.Parameter vmName
    Name of a user supplied VM to run tests on. The test run will
    use this VM to perform tests rather than the VMs listed in the
    xml file.
.Parameter hvServer
    The ESX server hosting the VM specified in the vmName argument.
.Parameter ipv4
    The IPv4 address of the VM specified in the vmName argument.
.Parameter sshKey
    The SSH key to use with the VM specified in the vmMane argument.
.Parameter suite
    The test suite to use when running tests on the VM specified 
    in the vmName argument.
.Parameter testParams
    VM specific test parameters to be used with the VM specified 
    in the vmName argument.
.Parameter email
    email address to send test results to.  This will be used rather than 
    the email list in the .xml file.
.Parameter examples
    When requesting help, if the examples switch is specified, examples of 
    usage will be displayed.
.Parameter dbgLevel
    The debug level to use when running tests.  Values are 0 - 10.  The higher
    the value, the more verbose the logging of message.  Levels above 5 are 
    quite chatty and are not recommended.
.Parameter NoShutDown
    With this parameter lisa will exit and not shutdown virtual machine
    after first case finished. This parameter helps debug test cases.
.Example
    .\lisa.ps1 run xml\debug_demo.xml
.Example
    .\lisa.ps1 run xml\debug_demo.xml -dbgLevel 5
.Link
    None.
#>


param([string] $cmdVerb,
      [string] $cmdNoun,
      [string] $VMs,
      [string] $vmName,
      [string] $hvServer,
      [string] $ipv4,
      [string] $sshKey,
      [string] $suite,
      [string] $testParams,
      [switch] $email,
      [switch] $examples,
      [string] $CLIlogDir,
      [string] $os,
      [switch] $help,
      [int]    $dbgLevel=0,
      [switch] $NoShutDown
     )


# Global variables
$lisaVersion = "2.1.0"
$logfileRootDir = ".\TestResults"
$logFile = "ica.log"

$testDir = $null
$xmlConfig = $null

$testStartTime = [DateTime]::Now


########################################################################################
# LogMsg()
########################################################################################
function LogMsg([int]$level, [string]$msg)
{
    <#
    .Synopsis
        Write a message to the log file and the console.
    .Description
        Add a time stamp and write the message to the test log.  In
        addition, write the message to the console.  Color code the
        text based on the level of the message.
    .Parameter level
        Debug level of the message
    .Parameter msg
        The message to be logged
    .Example
        LogMsg 3 "This is a test"
    #>

    if ($level -le $dbgLevel)
    {
        $now = [Datetime]::Now.ToString("MM/dd/yyyy HH:mm:ss : ")
        ($now + $msg) | out-file -encoding ASCII -append -filePath $logfile
        
        $color = "White"
        if ( $msg.StartsWith("Error"))
        {
            $color = "Red"
        }
        elseif ($msg.StartsWith("Warn"))
        {
            $color = "Yellow"
        }
        else
        {
            $color = "Gray"
        }
        
        Write-Host -F $color "$msg"
    }
}


########################################################################################
# Usage()
########################################################################################
function Usage()
{
    <#
    .Synopsis
        Display a help message.
    .Description
        Display a help message.  Optionally, display examples
        of usage if the -Examples switch is also specified.
    .Example
        Usage
    #>

    Write-Host -F Cyan "`nLISA version $lisaVersion`r`n"
    write-host "Usage: lisa cmdVerb cmdNoun [options]`r`n"
    write-host "    cmdVerb  cmdNoun      options     Description"
    write-host "    -------  -----------  ----------  -------------------------------------"
    write-host "    help                              : Display this usage message"
    write-host "    run      xmlFilename              : Run tests on VMs defined in the xmlFilename"
    write-host "                          -eMail      : Send an e-mail after tests complete"
    write-host "                          -VMs        : Comma separated list of VM names to run tests"
    write-host "                          -vmName     : Name of a user supplied VM"
    write-host "                          -hvServer   : Name (or IP) of ESX server hosting user supplied VM"
    write-host "                          -ipv4       : IP address of a user supplied VM"
    write-host "                          -sshKey     : The SSH key of a user supplied VM"
    write-host "                          -suite      : Name of test suite to run on user supplied VM"
    write-host "                          -testParams : Quoted string of semicolon separated parameters"
    write-host "                                         -testParams `"a=1;b='x y';c=3`""
    write-host
    write-host "  Common options"
    write-host "         -dbgLevel   : Specifies the level of debug messages"
    write-host "`n"
    
    if ($examples)
    {
        Write-host "`r`nExamples"
        write-host "    Run tests on all VMs defined in the specified xml file"
        write-host "        .\lisa run xml\mySmokeTests.xml`r`n"
        write-host "    Run tests on a specific subset of VMs defined in the xml file"
        write-host "        .\lisa run xml\mySmokeTests.xml -VMs rhel61, sles11sp1`r`n"
        write-host "    Run tests on a single VM not listed in the .xml file"
        write-host "        .\lisa run xml\mySmokeTests.xml -vmName Fedora13 -hvServer win8Srv -ipv4 10.10.22.34 -suite Smoke -sshKey rhel_id_rsa.ppk`r`n"
        write-host
    }
}


########################################################################################
# DumpParams
########################################################################################
function    DumpParams()
{
    LogMsg 0 "Info : cmdVerb:    $cmdVerb"
    LogMsg 0 "Info : cmdNoun:    $cmdNoun"
    LogMsg 0 "Info : VMs:        $VMs"
    LogMsg 0 "Info : vmName:     $vmName"
    LogMsg 0 "Info : hvServer:   $hvServer"
    LogMsg 0 "Info : ipv4:       $ipv4"
    LogMsg 0 "Info : sshKey:     $sshKey"
    LogMsg 0 "Info : suite:      $suite"
    LogMsg 0 "Info : testParams: $testParams"
    LogMsg 0 "Info : email:      $email"
    LogMsg 0 "Info : examples:   $examples"
    LogMsg 0 "Info : CLIlogDir:  $CLIlogDir"
    LogMsg 0 "Info : os:         $os"
    LogMsg 0 "Info : dbgLevel:   $dbgLevel"
}


########################################################################################
# AddUserToXmlTree
########################################################################################
function AddUserVmToXmlTree ([string] $vmName, [string] $hvServer, [string] $ipv4, [string] $sshKey, [string] $testSuite, [XML] $xml, [string] $OS )
{
    <#
    .Synopsis
        Add a new <VM> element to the XML data
    .Description
        Add a user specified VM to the XML tree created when the .xml
        file was parsed.  This VM is not listed in the .xml file.
    .Parameter vmName
        Name of the VM to add.
    .Parameter hvServer
        Name of the ESX server hosting the VM.
    .Parameter ipv4
        The IPv4 address of the user specified VM.
    .Parameter sshKey
        SSH key to use when accessing the user supplied VM.
    .Parameter testSuite
        Name of the test suite to run on the user supplied VM.
    .Parameter xml
        The XML document object created when the .xml file was loaded with Get-Content
    .Parameter OS
        Name of the OS used when running the user supplied VM
    .Example
        AddUserVmToXmlTree "myVM" "myServer" "192.168.1.2" "openssh_id_rsa.ppk" "kvp-tests" $xmlData "Linux"
        
    #>
    
    # Insert a new VM definition for the user supuplied VM

    # Create a new XML element
    $newVM = $xml.CreateElement("VM")
    
    # Add the core child elements to the new XML element
    $newName = $xml.CreateElement("vmName")
    $newName.set_InnerText($vmName)
    $newVM.AppendChild($newName)
    
    $newHvServer = $xml.CreateElement("hvServer")
    $newHvServer.set_InnerText($hvServer)
    $newVM.AppendChild($newHvServer)
    
    $newIpv4 = $xml.CreateElement("ipv4")
    if ($ipv4) {
        $newIpv4.set_InnerText($ipv4)
    } else {
        $newIpv4.set_InnerText("")
    }
    $newVM.AppendChild($newIpv4)
    
    $newSshKey = $xml.CreateElement("sshKey")
    $newSshKey.set_InnerText($sshKey)
    $newVM.AppendChild($newSshKey)
    
    $newTestSuite = $xml.CreateElement("suite")
    $newTestSuite.set_InnerText($testSuite)
    $newVM.AppendChild($newTestSuite)
    
    $newOS = $xml.CreateElement("os")
    $newOS.set_InnerText($OS)
    $newVM.AppendChild($newOS)
    
    #
    # Add the vm XML element to the XML data
    #
    $xml.config.VMs.AppendChild($newVM)
   
    #
    # Now remove all the other VMs we don't care about
    #
    PruneVMsFromXmlTree $vmName $xml
}


########################################################################################
# PruneVMsFromXmlTree
########################################################################################
function PruneVMsFromXmlTree ([string] $vmName, [XML] $xml)
{
    <#
    .Synopsis
        Remove VMs from the XML tree.
    .Description
        If a user specified the -VMs command line option, a list of VMs
        was specified.  This list of VMs is a subset of the VMs listed
        in the .XML file.  Remove all the VMs from the XML Document that
        are not in the VMs list supplied by the user.
    .Parameter vmName
        One or more vm Names.  These VMs will remain in the XML document
        list of VMs.
    .Parameter xml
        The XML document object created when the .xml file was loaded with Get-Content
    .Example
        PruneVMsFromXmlTree $testVmName $xmlData
    #>

    if ($vmName)
    {
        $vms = $vmName.Split(" ")

        #
        # Now remove some of the VMs from the xml tree
        #
        foreach ($vm in $xml.config.VMs.vm)
        {
            if ($vms -notcontains $($vm.vmName))
            {
                LogMsg 5 "Info : Removing $($vm.vmName) from XML tree"
                $xml.config.VMs.RemoveChild($vm) | out-null
            }
        }

        #
        # Complain if an unknown VM was specified
        #
        foreach ($name in $vms)
        {
            $found = $false
            foreach ($vm in $xml.config.VMs.vm)
            {
                if ($name -eq $($vm.vmName))
                {
                    $found = $true
                }   
            }
        
            if (! $found)
            {
                LogMsg 0 "Warn : Unknown VM, name = $name"
            }
        }
    }
    else
    {
        LogMsg 0 "Warn : PruneVMsFromXMLTree - was passed a null vmName"
    }
}


########################################################################################
# AddTestParamsToVMs
########################################################################################
function AddTestParamsToVMs ($xmlData, $tParams)
{
    <#
    .Synopsis
        Add VM specific test parameters
    .Description
        Add the user supplied test parameters to each VM.
    .Parameter xmlData
        The XML document object created when the .xml file was loaded with Get-Content
    .Parameter tParams
        A semicolon separated string of test parameters.
    .Example
        AddTestParamsToVMs $xmlData "Foo=1;Bar=2"
    #>

    $params = $tParams.Split(";")
    if ($params)
    {
        foreach($vm in $xmlData.config.VMs.vm)
        {
            $tp = $vm.testParams
            
            #
            # Add the vm.testParams element if it does not exist
            #
            if (-not $vm.testParams)
            {
                $newTestParams = $xmlData.CreateElement("testParams")
                $tp = $vm.AppendChild($newTestParams)
            }
            
            #
            # Add a <param> for each parameter from the command line
            #
            foreach($param in $params)
            {
                $newParam = $xmlData.CreateElement("param")
                $newParam.set_InnerText($param.Trim())
                $tp.AppendChild($newParam)
            }
        }
    }
}


########################################################################################
# RunInitShutdownScript()
#
# Description:
#    Run a script and capture all output.  The display the output
#    from the script.  The script is run in a separate context
#    so any functions in the script do not overwrite any function
#    defined by the LiSA scripts.
#
#    The Lisa Init script is called after the .xml file has been
#    loaded, and before anything is done to the test VMs.
########################################################################################
function RunInitShutdownScript([String] $scriptName, [String] $xmlFilename )
{
    <#
    .Synopsis
        Run a PowerShell script in a separate context.
    .Description
        Run a user supplied PowerShell script.  The script can
        be specified in the .xml file as either an init or shutdown
        script
    .Parameter scriptName
        Name of the PowerShell script to run.
    .Parameter xmlFilename
        Name of the .xml file for the test run.
    .Example
        RunInitShutdownScript "C:\lisa\trunk\lisa\setupScripts\CreateVMs.ps1" ".\xml\myTests.xml"
    #>

    # Assume failure
    $retval = $false

    #
    # Make sure everthing that we need exists
    #
    if (-not $scriptName)
    {
        LogMsg 0 "Warn : RunInitShutdownScript() received a null scriptName"
        return $false
    }
    
    if (-not $xmlFilename)
    {
        LogMsg 0 "Warn : RunInitShutdownScript() received a null xmlFilename"
        return $false
    }

    if (-not (test-path $scriptName))
    {
        LogMsg 0 "Warn : ICAInit script does not exist: ${scriptName}"
        return $false
    }

    if (-not (test-path $xmlFilename))
    {
        LogMsg 0 "Warn : XML file for ICAInit script does not exist: ${xmlFilename}"
        return $false
    }

    #
    # Invoke the ICA Init/Shutdown script
    #
    $cmd = "$scriptName -xmlFile $xmlFilename"
    LogMsg 6 ("Info : Invoke-Expression $cmd")

    #
    # Force the return to be an array by using the @() operator
    # This is case someone writes a script that only outputs the
    # true/false status, in which case the return is a single 
    # string rather than an array of strings.
    #
    $sts = @(Invoke-Expression $cmd)
 
    if ($sts[($sts.Length) - 1] -eq "True")
    {
        $retVal = $true
    }

    #
    # Log the output from the ICA Init/Shutdown script
    #
    LogMsg 3 "Info : ICA Init/Shutdown script ${scriptName} output"
    foreach( $line in $sts)
    {
        LogMsg 3 "       $line"
    }

    return $retVal
}


########################################################################################
# NoShutDown()
########################################################################################
function NoShutDownCheck ()
{
    return $NoShutDown
}


########################################################################################
# RunTests
########################################################################################
function RunTests ([String] $xmlFilename )
{
    <#
    .Synopsis
        Start a test run.
    .Description
        Start a test run on the VMs listed in the .xml file.
    .Parameter xmlFilename
        Name of the .xml file for the test run.
    .Example
        RunTests "xml\myTests.xml"
    #>

    # Make sure we have a .xml filename to work with
    if (! $xmlFilename)
    {
        Write-Host -F Red "Error: xml filename missing"
        return $false
    }

    # Make sure the .xml file exists, then load it
    if (! (test-path $xmlFilename))
    {
        Write-Host -F Red "Error: XML config file '$xmlFilename' does not exist."
        return $false
    }

    $xmlConfig = [xml] (Get-Content -Path $xmlFilename)
    if ($null -eq $xmlConfig)
    {
        Write-Host -F Red "Error: Unable to parse the .xml file"
        return $false
    }

    if ( $CLIlogDir)
    {
        #   logfile dir is specified on the command line
        $rootDir = $CLIlogDir
    }
    else
    {
        $rootDir = $logfileRootDir
        if ($xmlConfig.config.global.logfileRootDir)
        {
            $rootDir = $xmlConfig.config.global.logfileRootDir
        }
    }

    # Create the directory for the log files if it does not exist
    if (! (test-path $rootDir))
    {
        $d = mkdir $rootDir -erroraction:silentlycontinue
        if ($d -eq $null)
        {
            Write-Host -F red "Error: root log directory does not exist and cannot be created"
            Write-Host -F red "       root log directory = $rootDir"
            return $false
        }
    }

    if (-not $suite)
    {
        $suite = $xmlConfig.config.VMs.vm.suite
    }
    
    $fname = [System.IO.Path]::GetFilenameWithoutExtension($xmlFilename)
    $testRunDir = $fname + "-" + $suite + "-" + $Script:testStartTime.ToString("yyyyMMdd-HHmmss")
    $testDir = join-path -path $rootDir -childPath $testRunDir
    mkdir $testDir | out-null
    
    $logFile = Join-Path -path $testDir -childPath $logFile
        
    LogMsg 0 "ESX-LISA - version $lisaVersion"
    LogMsg 4 "Info : Created directory: $testDir"
    LogMsg 4 "Info : Logfile =  $logfile"
    LogMsg 4 "Info : Using XML file:  $xmlFilename"

    # See if we need to modify the in memory copy of the .xml file
    if ($vmName)
    {
        #
        # Run tests on a user supplied VM
        #
        if ($hvServer -and $sshKey -and $suite)
        {   
            #
            # Add the user provided VM to the in memory copy of the xml
            # file, then remove all the other VMs from the in memory copy
            #
            LogMsg 0 "Info : Add user supplied VM $vmName from command line"
            if ($dbgLevel -gt 3)    { DumpParams }
            AddUserVmToXmlTree $vmName $hvServer $ipv4 $sshKey $suite $xmlConfig $os
        }
        else
        {
            LogMsg 0 "Error: For user supplied VM, you must specify all of the following options:`n         -vmName -hvServer -sshKey -suite"
            DumpParams
        }
    }
    elseif ($VMs)
    {     
        #
        # Run tests on a subset of VMs defined in the XML file.  Remove the un-used
        # VMs from the in memory copy of the XML data
        #
        PruneVMsFromXmlTree $VMs $xmlConfig
        if (-not $xmlConfig.config.VMs)
        {
            LogMsg 0 "Error: No defined VMs to run tests"
            LogMsg 0 "Error: The following VMs do not exist: $VMs"
            return $false
        }
    }

    # If testParams were specified, add them to the VMs
    if ($testParams)
    {
        AddTestParamsToVMs $xmlConfig $testParams
    }

    #
    # Run any init scripts specified in the global data.  This change supports the original
    # syntax that only allowed a single init script, and a new syntax that allows the user
    # to specify multiple init scripts.
    #
    # Original syntax
    #    <LisaInitScript>.\single.ps1</LisaInitScript>
    #
    # New syntax
    #    <LisaInitScript>
    #        <file>.\setupScripts\CreateVSwitches.ps1</file>
    #        <file>.\setupScripts\CreateVMs.ps1</file>
    #        <file>.\setupScripts\ProvisionVMs.ps1</file>
    #    </LisaInitScript>
    #
    if ($xmlConfig.Config.Global.LisaInitScript)
    {
        if ($xmlConfig.Config.Global.LisaInitScript.file)
        {
            # Support the newer syntax that allows multiple init scripts
            foreach ($file in $xmlConfig.Config.Global.LisaInitScript.file)
            {
                LogMsg 3 "Info : Running Lisa Init script '${file}'"
                $initResults = RunInitShutdownScript ${file} $xmlFilename
            }
        }
        else
        {
            # Support the older syntax that allowed a single init script
            LogMsg 3 "Info : Running Lisa Init script '$($xmlConfig.Config.Global.LisaInitScript)'"
            $initResults = RunInitShutdownScript $xmlConfig.Config.Global.LisaInitScript $xmlFilename
        }
    }

    LogMsg 10 "Info : Calling RunICTests"
    . .\stateEngine.ps1
    RunICTests $xmlConfig

    # email the test results if requested
    if ($eMail)
    {
        SendEmail $xmlConfig $Script:testStartTime $xmlFilename $rootDir
    }

    $summary = SummaryToString $xmlConfig $Script:testStartTime $xmlFilename $rootDir
    
    # The summary message is formatted for HTML body mail messages
    # When writing to the log file, we should emove the HTML tags
    $summary = $summary.Replace("<br />", "`r`n")
    $summary = $summary.Replace("<pre>", "")
    $summary = $summary.Replace("</pre>", "")

    LogMsg 0 "$summary"
    
    $lisaTestResult = $true
    foreach($vm in $xmlConfig.config.VMs.vm)
    {
        if ($vm.individualResults.Contains("0"))
        {
            $lisaTestResult = $false
            break

        }
    }

    return $lisaTestResult
}

########################################################################################
#  Main body of the script
########################################################################################
if ( $help)
{
    Usage
    exit 0
}


$lisaExitCode = 0


switch ($cmdVerb)
{
"run" {
        $sts = RunTests $cmdNoun
        
        # RunTests() (which calls RunICTests() in stateEngine.ps1) may return an array of results. 
        # we need to check the last one which is the final
        if (!$sts[-1])
        {
            $lisaExitCode = 2
        }
    }
"help" {
        Usage
        $lisaExitCode = 0
    }
default    {
        if ($cmdVerb.Length -eq 0)
        {
            Usage
            $lisaExitCode = 0
        }
        else
        {
            LogMsg 0 "Unknown command verb: $cmdVerb"
            Usage
        }
    }
}


Write-Host "Test will exit with error code $lisaExitCode"
exit $lisaExitCode
