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
## v1.1 - xiaofwan - 11/28/2016 - Merge SendEmail and SummaryToString update
##                                Merge bug fix from LISA
## v1.2 - xiaofwan - 1/25/2017 - Insert suite name into result dir name,
##                               such as cases-open_vm_tools-20170120-141152
## v1.3 - xiaofwan - 1/25/2017 - $vm.testCaseResults only contains "Passed", 
##                               "Failed", "Skipped", "Aborted", and "none".
## v1.4 - xiaofwan - 2/3/2017 - $True will be $true and $False will be $false.
## v1.5 - xiaofwan - 2/4/2017 - Test result can be exported as JUnix XML file.
##                              Correct some comment issues.
## v1.6 - xiaofwan - 2/4/2017 - Remove Test-Admin function.
## v1.7 - xiaofwan - 2/6/2017 - The <skipped/> section should be removed when
##                              case failed or aborted.
## v1.8 - xiaofwan - 2/21/2017 - Two new functions to set XML result the kernel
##                               firmware and ESX version.
## v1.9 - xiaofwan - 2/21/2017 - Iteration related code has been removed.
## v2.0 - xiaofwan - 2/21/2017 - Add test case running date and time in XML.
## v2.1 - xiaofwan - 2/21/2017 - Move case running time calculation into 
##                               SetRunningTime function.
## v2.2 - xiaofwan - 3/17/2017 - Change case result timer from TotalMinutes to
##                               TotalSeconds to satisfy Jenkins and Polarion
## v2.3 - xiaofwan - 7/18/2017 - Add a property in case result to save
##                               TC_COVERED info into result XML.
##
###############################################################################

<#
.Synopsis
    Helper functions for the Lisa automation.

.Description
    The functions in this file are helper functions for the
    the lisa.ps1 and stateEngine.ps1 automation scripts.

.Link
    None.
#>

###############################################################################
#
# PowerCLIImport
#
###############################################################################
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
            "Info: PowerCLI module VMware.VimAutomation.Core already exists."
            $foundVimautomation = $true
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
# ConnectToVIServer
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

#####################################################################
#
# GetJUnitXML 
#
#####################################################################
function GetJUnitXML()
{
    <#
    .Synopsis
        Generate a JUnit XML object from template file.

    .Description
        Load JUnit XML result template file, and generate an XML object.

    .ReturnValue
        An xml object of JUnit result.
        Output type: [XML]
    .Example
        GetJUnitXML
    #>
    LogMsg 6 ("Info :    GetJUnitXML()")

    $template = @'
<testsuite name="" timestamp="">
<properties>
    <property name="esx.version" value="" />
    <property name="kernel.version" value="" />
    <property name="firmware.version" value="" />
</properties>
<testcase id="" name="" time="">
    <skipped/>
    <failure type=""></failure>
    <properties>
        <property name="TC_COVERED" value="" />
    </properties>
</testcase>
</testsuite>
'@

    $guid = [System.Guid]::NewGuid().ToString("N")
    $templatePath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), $guid + ".txt");

    $template | Out-File $templatePath -encoding UTF8
    # load template into XML object
    $junit_xml = New-Object xml
    $junit_xml.Load($templatePath)

    Remove-Item $templatePath

    return $junit_xml
}

#####################################################################
#
# SetESXVersion
#
#####################################################################
function SetESXVersion([String] $ver)
{
    <#
    .Synopsis
        Add ESX version into XML result.

    .Description
        Find the ESX version property and set ESX version into result XML object.

    .Parameter ver
        The version of ESX host.
        Type : [String]

    .Example
        SetESXVersion "6.0 build 4192238"
    #>
    LogMsg 6 ("Info :    SetESXVersion($($ver))")

    foreach ($property in $testResult.testsuite.properties.property)
    {
        if ($property.name -eq "esx.version")
        {
            $property.value = $ver
            return
        }
    }
}

#####################################################################
#
# SetOSInfo
#
#####################################################################
function SetOSInfo([String] $kernelVer, [String] $firmwareVer)
{
    <#
    .Synopsis
        Add Kernel and firmware version into XML result.

    .Description
        Find the Kernel and firmware version properties and set Kernel
        and firmware version into result XML object.

    .Parameter kernelVer
        The version of guest kernel.
        Type : [String]

    .Parameter firmwareVer
        The version of guest firmware info.
        Type : [String]

    .Example
        SetOSInfo "2.6.32-694.el6.x86_64" "BIOS"
    #>
    LogMsg 6 ("Info :    SetOSInfo($($kernelVer), $($firmwareVer))")

    foreach ($property in $testResult.testsuite.properties.property)
    {
        if ($property.name -eq "kernel.version" -and $property.value -eq "")
        {
            $property.value = $kernelVer
        }
        
        if ($property.name -eq "firmware.version" -and $property.value -eq "")
        {
            $property.value = $firmwareVer
        }
    }
}

#####################################################################
#
# SetResultSuite
#
#####################################################################
function SetResultSuite([String] $testSuite)
{
    <#
    .Synopsis
        Configure test suite in result XML object.

    .Description
        Find the test suite, and configure test suite into result XML object.

    .Parameter testSuite
        The name of the test suite to run
        Type : [String]

    .Example
        SetResultSuite "acceptance"
    #>
    LogMsg 6 ("Info :    SetResultSuite($($testSuite))")

    $testResult.testsuite.name = $testSuite
}

#####################################################################
#
# SetTimeStamp
#
#####################################################################
function SetTimeStamp([String] $testTimeStamp)
{
    <#
    .Synopsis
        Add test date time in result XML object.

    .Description
        Find the test suite, and configure test date time into result XML object.

    .Parameter testTimeStamp
        The start time of test run
        Type : [String]

    .Example
        SetTimeStamp "02/21/2017 13:14:25"
    #>
    LogMsg 6 ("Info :    SetTimeStamp($($testTimeStamp))")

    $testResult.testsuite.timestamp = $testTimeStamp
}

#####################################################################
#
# SetTestResult
#
#####################################################################
function SetTestResult([String] $testName, [Object] $testID, [String] $completionCode)
{
    <#
    .Synopsis
        Add test case result into result XML object except running time.

    .Description
        Clone a test case group as template, add test result into that group.

    .Parameter testName
        The name of the test
        Type : [String]

    .Parameter testID
        The ID of the test
        Type : [Object]

    .Parameter completionCode
        The test result, such as Passed, Failed, Skipped, and Aborted
        Type : [String]

    .Example
        SetTestResult $testName $testID $completionCode
    #>
    LogMsg 6 ("Info :    SetTestResult($($testName))")

    $newTestCaseTemplate = (@($testResult.testsuite.testcase)[0]).Clone()
    $newTestCase = $newTestCaseTemplate.clone()
    $newTestCase.name = $testName
    $newTestCase.id = $testID.test
    switch ($completionCode)
    {
        "Passed" {
            $newTestCase.RemoveChild($newTestCase.ChildNodes[0]) | Out-Null
            $newTestCase.RemoveChild($newTestCase.ChildNodes[0]) | Out-Null
        }
        "Skipped" {
            $newTestCase.RemoveChild($newTestCase.ChildNodes[1]) | Out-Null
        }
        "Failed" {
            $newTestCase.RemoveChild($newTestCase.ChildNodes[0]) | Out-Null
            $newTestCase.failure.type = "Failed"
            $newTestCase.failure.InnerText = "Test $testName Failed."
        }
        "Aborted" {
            $newTestCase.RemoveChild($newTestCase.ChildNodes[0]) | Out-Null
            $newTestCase.failure.type = "Aborted"
            $newTestCase.failure.InnerText = "Test $testName Aborted."
        }
    }
    foreach ($property in $newTestCase.properties.property)
    {
        if ($property.name -eq "TC_COVERED")
        {
            $property.value = $testID.tc
            break
        }
    }
    $testResult.testsuite.AppendChild($newTestCase) > $null
}

#####################################################################
#
# SetRunningTime
#
#####################################################################
function SetRunningTime([String] $testName, [System.Xml.XmlElement] $vm)
{
    <#
    .Synopsis
        Set running time in result XML object.

    .Description
        Find the test case, and configure test running time into result XML object.

    .Parameter testName
        The test name
        Type : [String]
    
   .Parameter vm
        An XML element representing the VM
        Type : [System.Xml.XmlElement]

    .Example
        SetRunningTime $testName $vm
    #>
    LogMsg 6 ("Info :    SetRunningTime($testName)")

    $caseEndTime = [DateTime]::Now
    $deltaTime = $caseEndTime - [DateTime]::Parse($vm.caseStartTime)
    LogMsg 0 "Info : $($vm.vmName) currentTest lasts $($deltaTime.hours) Hours, $($deltaTime.minutes) Minutes, $($deltaTime.seconds) seconds."
    
    $runningTime = "{0:N0}" -f $deltaTime.TotalSeconds

    foreach ($testCase in $testResult.testsuite.testcase)
    {
        if ($testCase.name -eq $testName)
        {
            $testCase.time = $runningTime
        }
    }
}

#####################################################################
#
# SaveResultToXML
#
#####################################################################
function SaveResultToXML([String] $testDir)
{
    <#
    .Synopsis
        Save test result to XML file in result folder..

    .Description
        Export result XML object into an XML file.

    .Parameter testDir
        The folder storing test log.
        Type : [String]

    .Example
        SaveResultToXML $testDir
    #>
    LogMsg 6 ("Info :    SaveResultToXML to ($($testDir))")

    $resultXMLFileName = "Report-" + $testResult.testsuite.name + ".xml"

    # remove users with undefined name (remove template)
    $testResult.testsuite.testcase | Where-Object { $_.Name -eq "" } | ForEach-Object  { [void]$testResult.testsuite.RemoveChild($_) }
    # save xml to file
    $resultXMLFile = Join-Path -path $testDir -childPath $resultXMLFileName
    $resultXMLFile = (Get-Item -Path ".\" -Verbose).FullName + "\" + $resultXMLFile
    $testResult.Save($resultXMLFile)
}

#####################################################################
#
# HasItBeenTooLong
#
#####################################################################
function HasItBeenTooLong([String] $timestamp, [Int] $timeout)
{
    <#
    .Synopsis
        Check to see if a timeout has occured.

    .Description
        Convert the timestamp from a string to a [DateTime] type,
        add in the timeout value and see if it is less than the
        current date/time.

    .Parameter timestamp
        A string representing the timestamp
        Type : [String]

    .Parameter timeout
        An integer timeout period in seconds.
        Type : [Int]

    .ReturnValue
        Return $true if current time is greater than timestamp + timeout,
               $false otherwise.
        Output type : [Boolean]

    .Example
        HasItBeenTooLong $myTimeStamp $myTimeOut
    #>

    $retVal = $false

    if (-not $timeStamp)
    {
        # Bad data - force a timeout
        return $true
    }

    if (-not $timeout)
    {
        # Bad data - force a timeout
        return $true
    }

    if ($timeout -le 0)
    {
        # Bad data - force a timeout
        return $true
    }

    $now = [DateTime]::Now
    $ts = [DateTime]::Parse($timestamp)
    $tooLong = [DateTime]::Compare($ts.AddSeconds($timeout), $now)

    if ($tooLong -eq -1)
    {
        LogMsg 9 "INFO : The current task is started at $timestamp"
        LogMsg 9 "INFO : Timeout is set to $timeout seconds"
        $retVal = $true
    }

    return $retVal
}

#####################################################################
#
# GetNextTest
#
#####################################################################
function GetNextTest([System.Xml.XmlElement] $vm, [xml] $xmlData)
{
    <#
    .Synopsis
        Get the name of the next test the VM is to run

    .Description
        Examine the $vm.suite field and then walk through the test suite
        to return the string name of the next test the VM is to perform.
        If all tests have been performed, return the string "done".

    .Parameter vm
        An XML element representing the VM
        Type : [System.Xml.XmlElement]

    .ReturnValue
        A string of the name of the next test.
        Output type : [Boolean]

    .Example
        GetNextTest $myVM
    #>
    LogMsg 9 "Info :    GetNextText($($vm.vmName))"
    LogMsg 9 "Debug:      vm.currentTest = $($vm.currentTest)"
    LogMsg 9 "Debug:      vm.suite = $($vm.suite)"

    $done = "done"      # Assume no more tests to run

    if (-not $vm)
    {
        LogMsg 0 "Error: GetNextTest() received a null VM parameter"
        return $done
    }

    if (-not $xmlData)
    {
        LogMsg 0 "Error: GetNextTest() received a null xmlData parameter"
        return $done
    }

    if ($vm.currentTest -eq $done)
    {
        return $done
    }

    if (-not $xmlData.config.testSuites.suite)
    {
        LogMsg 0 "Error: no test suites defined in .xml file"
        return $done
    }

    $tests = $null
    $nextTest = $done

    foreach ($suite in $xmlData.config.testSuites.suite)
    {
        if ($suite.suiteName -eq $vm.suite)
        {
            if ($suite.suiteTests)
            {
                $tests = $suite.suiteTests
            }
            else
            {
                LogMsg 0 "Error: Test suite $($suite.suiteName) does not have any tests"
                return $done
            }
            break
        }
    }

    #
    # We found the tests for the VMs test suite. Next find the next test to run.
    #
    if ($tests)
    {
        $prev = "unknown"
        $currentTest = $vm.currentTest
        foreach ($t in $tests.suiteTest)
        {
            if ($currentTest -eq "none")
            {
                $nextTest = [string] $t
                break
            }

            if ($currentTest -eq $prev)
            {
                $nextTest = [string] $t
                break
            }
            $prev = $t
        }
    }

    return $nextTest
}

#####################################################################
#
# GetTestData
#
#####################################################################
function GetTestData([String] $testName, [xml] $xmlData)
{
    <#
    .Synopsis
        Retrieve the xml object for the specified test

    .Description
        Find the test named $testName, and return the xml element
        for that test, on $null if the test is not found.

    .Parameter testName
        The name of the test to return
        Type : [String]

    .ReturnValue
        An xml element of the specific test
        Output type: [System.Xml.XmlElement]
    .Example
        GetTestData "MyTest"
    #>
    LogMsg 6 ("Info :    GetTestData($($testName))")

    $testData = $null

    foreach ($test in $xmlData.config.testCases.test)
    {
        if ($test.testName -eq $testName)
        {
            $testData = $test
            break
        }
    }

    return $testData
}

#####################################################################
#
# GetTestID
#
#####################################################################
function GetTestID([String] $testName, [xml] $xmlData)
{
    <#
    .Synopsis
        Retrieve the xml object for the test ID of specified test

    .Description
        Find the test named $testName, and return the testID field value, 
        on $null if the test is not found.

    .Parameter testName
        The name of the test to return
        Type : [String]

    .ReturnValue
        An ID object with test and tc properties.
        Type: [Object]

    .Example
        GetTestData "MyTest"
    #>
    LogMsg 6 ("Info :    GetTestID($($testName))")

    $idObj = "" | Select-Object -Property test,tc

    foreach ($test in $xmlData.config.testCases.test)
    {
        if ($test.testName -eq $testName)
        {
            $idObj.test = $test.testID
            foreach ($param in $test.testParams.param)
            {
                if ($param.contains("TC_COVERED="))
                {
                    $idObj.tc = $param.split("=")[1]
                    break
                }
            }
            break
        }
    }

    return $idObj
}

#####################################################################
#
# GetTestTimeout
#
#####################################################################
function GetTestTimeout([System.Xml.XmlElement] $vm, [XML] $xmlData)
{
    <#
    .Synopsis
        Retrieve timeout value for the VM's current test

    .Description
        Return the timeout value defined in the .xml file for
        the current test, or $null if no timeout is specified.

    .Parameter vm
        The xml element of the virtual machine
        Type : [System.Xml.XmlElement]

    .ReturnValue
        A string representing the timeout value in seconds,
        or $null if not timeout is found.
        Output type: [String]
    .Example
        GetTestTimeout $myVM
    #>

    $timeout = $null
    $testData = GetTestData $vm.currentTest $xmlData

    if ($testData.timeout)
    {
        $timeout = [string] $testData.timeout
    }

    return $timeout
}

#####################################################################
#
# AbortCurrentTest
#
#####################################################################
function AbortCurrentTest([System.Xml.XmlElement] $vm, [string] $msg)
{
    <#
    .Synopsis
        Mark the current test as aborted.

    .Description
        Displayed msg if provided, set the VM's testCaseResults to
        "False", and set the VM's state to completed, update the
        VM's timestamp

    .Parameter vm
        The xml element of the virtual machine
        Type : [System.Xml.XmlElement]

    .Parameter msg
        A string to be included in the ICA log.
        Type : [String]

    .ReturnValue
        none

    .Example
        AbortCurrentTest $myVM "This is just a test"
    #>

    #$TestAborted = "TestAborted"

    if ($null -ne $msg)
    {
        logMsg 0 "Error: $($vm.vmName) $msg"
    }

    $vm.testCaseResults = $Aborted
    $vm.state = $CollectLogFiles

    logMsg 2 "Info : $($vm.vmName) transitioned to state $($vm.state)"
    $vm.stateTimestamp = [DateTime]::Now.ToString()
}

#####################################################################
#
# SummaryToString
#
#####################################################################
function SummaryToString([XML] $xmlConfig, [DateTime] $startTime, [string] $xmlFilename, [string] $logDir)
{
    <#
    .Synopsis
        Append the summary text from each VM into a single string.

    .Description
        Append the summary text from each VM one long string. The
        string includes line breaks so it can be display on a
        console or included in an e-mail message.

    .Parameter xmlConfig
        The parsed xml from the $xmlFilename file.
        Type : [System.Xml]

    .Parameter startTime
        The date/time the ICA test run was started
        Type : [DateTime]

    .Parameter xmlFilename
        The name of the xml file for the current test run.
        Type : [String]

    .Parameter logDir
        The path of the folder containing the log files
        Type : [String]

    .ReturnValue
        A string containing all the summary message from all
        VMs in the current test run.

    .Example
        SummaryToString $testConfig $myStartTime $myXmlTestFile
    #>

    $str = "<br />Test Results Summary<br />"
    $str += "ESX-LISA test run on " + $startTime
    $str += "<br />XML file: $xmlFilename<br /><br />"

    #
    # Add information about the host running ICA to the e-mail summary
    #
    $str += "<pre>"
    foreach($vm in $xmlConfig.config.VMs.vm)
    {
        $str += $vm.emailSummary + "<br />"
    }

    $fname = [System.IO.Path]::GetFilenameWithoutExtension($xmlFilename)

    #
    # Check to see if the provided log path is absolute
    #
    if ([System.IO.Path]::IsPathRooted($logDir)) 
    {
        $logPath = $logDir
    }
    else
    {
        $logPath = (Get-Item -Path ".\" -Verbose).FullName + "\" + $logDir    
    }

    if (-not $suite)
    {
        $suite = $xmlConfig.config.VMs.vm.suite
    }

    $str += "Logs can be found at " + $logPath + "\" + $fname + "-" + $suite + "-" + $startTime.ToString("yyyyMMdd-HHmmss") + "<br /><br />"
    $str += "</pre><br />"
    return $str
}

#####################################################################
#
# SendEmail
#
#####################################################################
function SendEmail([XML] $xmlConfig, [DateTime] $startTime, [string] $xmlFilename, [string] $logDir)
{
    <#
    .Synopsis
        Send an e-mail message with test summary information.

    .Description
        Collect the test summary information from each VM.  Send an
        eMail message with this summary information to emailList defined
        in the xml config file.

    .Parameter xmlConfig
        The parsed XML from the test xml file
        Type : [System.Xml]

    .Parameter logDir
        The path of the folder containing the log files
        Type : [String]

    .ReturnValue
        none

    .Example
        SendEmail $myConfig
    #>

    $to = @()
    foreach($r in $xmlConfig.config.global.email.recipients.to)
    {
        $to = $to + $r
    }

    $from = $xmlConfig.config.global.email.Sender
    $subject = $xmlConfig.config.global.email.Subject + " " + $startTime
    $smtpServer = $xmlConfig.config.global.email.smtpServer
    $fname = [System.IO.Path]::GetFilenameWithoutExtension($xmlFilename)

    $body = SummaryToString $xmlConfig $startTime $fname
    $body = $body.Replace("Aborted", '<em style="background:Aqua; color:Red">Aborted</em>')
    $body = $body.Replace("Failed", '<em style="background:Yellow; color:Red">Failed</em>')

    #
    # Check to see if the provided log path is absolute
    #
    if ([System.IO.Path]::IsPathRooted($logDir)) 
    {
        $logPath = $logDir
    }
    else
    {
        $logPath = (Get-Item -Path ".\" -Verbose).FullName + "\" + $logDir    
    }

    $str += "Logs can be found at " + $logPath + "\" + $fname + "-" + $startTime.ToString("yyyyMMdd-HHmmss") + "<br /><br />"

    Send-mailMessage -to $to -from $from -subject $subject -body $body -BodyAsHtml -smtpserver $smtpServer
}

#####################################################################
#
# ShutDownVM
#
#####################################################################
function ShutDownVM([System.Xml.XmlElement] $vm)
{
    <#
    .Synopsis
        Stop the VM

    .Description
        Try to send a halt command to the VM.  If this fails,
        use the VMWARE library Stop-VM call to try and stop
        the VM.  If the VM is already stopped, do nothing.

    .Parameter vm
        An xml node representing the VM.
        Type : [System.Xml.XmlElement]

    .ReturnValue
        none

    .Example
        ShutDownVM $myVM
    #>

    $v = Get-VMHost -Name $vm.hvServer | Get-VM -Name $vm.vmName
    if (-not $v)
    {
        LogMsg 0 "Error : SystemDown cannot find the VM $($vm.vmName)"
        $vm.emailSummary += "VM $($vm.vmName) cannot be found - no tests run on VM<br />"
        UpdateState $vm $Disabled
        return
    }
    else
    {
        if ($v.PowerState -ne "PoweredOff")
        {
            if (-not (SendCommandToVM $vm "init 0") )
            {
                LogMsg 0 "Warn : $($vm.vmName) could not send shutdown command to the VM. Using ESXi to stop the VM."
                Stop-VM -VM $v -Confirm:$false | out-null
            }
        }
    }
}

#####################################################################
#
# RunPSScript
#
#####################################################################
function RunPSScript([System.Xml.XmlElement] $vm, [string] $scriptName, [XML] $xmlData, [string] $mode, [string] $logFilename)
{
    <#
    .Synopsis
        Run a separate PowerShell script.

    .Description
        Run the specified PowerShell script.

    .Parameter vmName
        Name of the VM
        Type : [String]

    .Parameter scriptName
        Name of the PowerShell script to be run
        Type : [String]

    .Parameter logFilename
        The name of the file to write output to.
        Type : [String]

    .ReturnValue
        True or false to indicate if the script ran successfully or not.
        Output type: [Boolean]

    .Example
        RunPSScript "fed13" "hvServer1" ".\AddNic.ps1" $testData ".\myLog.log"
    #>

    $retVal = $false

    $scriptMode = "unknown"

    #
    # Check the input arguments
    #
    if (-not $vm)
    {
        logMsg 0 "Error: RunPSScript() was passed a numm VM"
        return $false
    }

    if (-not $scriptName)
    {
        logMsg 0 ("Error: RunPSScript($vmName, $hvServer, null) was passed a null scriptName")
        return $false
    }

    if (-not $xmlData)
    {
        logMsg 0 ("Error: RunPSScript($vmName, $hvServer, $scriptName, testData, null) was passed null test data")
        return $false
    }

    if ($mode)
    {
        $scriptMode = $mode
    }

    if (-not (test-path -path $scriptName))
    {
        logMsg 0 ("Error: RunPSScript() script file '$scriptName' does not exist.")
        return $false
    }

    $vmName = $vm.vmName
    $hvServer = $vm.hvServer
    $testData = GetTestData $vm.currentTest $xmlData
    logMsg 6 ("Info : RunPSScript($vmName, $hvServer, $scriptName)")

    if (-not $testData)
    {
        LogMsg 0 "$($vm.vmName) Unable to collect test data for test $($vm.currentTest)"
        return $false
    }

    #
    # Create an string of test params, separated by semicolons - ie. "a=1;b=x;c=5;"
    #
    $params = CreateTestParamString $vm $xmlData
    $params += "scriptMode=${scriptMode};"
    $params += "sshKey=$($vm.sshKey);"

    #
    # Invoke the setup/cleanup script
    #
    $cmd = "$scriptName -vmName $vmName -hvServer $hvServer"

    #
    # Only add the testParams if something was specified, and it appears reasonable
    # Min param length is 3 -ie.  "a=1"
    #
    if ($params.Length -gt 2 -and $params.Contains("="))
    {
        $cmd += " -testParams `"$params`""
    }

    LogMsg 6 ("Info : Invoke-Expression $cmd")
    $sts = Invoke-Expression $cmd

    $numItems = $sts.length
    LogMsg 6 "Debug: $vmName - Invoke-Expression returned array with $($sts.length) elements"

    if ($sts[-1] -eq "True")
    {
        $retVal = $true
    }

    #
    # Write script output into log file
    #
    foreach($i in $sts)
    {
        logMsg 3 ("Info :    $vmName - $i")
    }

    return $retVal
}

#####################################################################
#
# TestPort
#
#####################################################################
function TestPort ([String] $serverName, [Int] $port=22, [Int] $to=3)
{
    <#
    .Synopsis
        Check to see if a specific TCP port is open on a server.
    .Description
        Try to create a TCP connection to a specific port (22 by default)
        on the specified server. If the connect is successful return
        true, false otherwise.
    .Parameter Host
        The name of the host to test
    .Parameter Port
        The port number to test. Default is 22 if not specified.
    .Parameter Timeout
        Timeout value in seconds
    .Example
        Test-Port $serverName
    .Example
        Test-Port $serverName -port 22 -timeout 5
    #>

    $retVal = $false
    $timeout = $to * 1000

    #
    # Try an async connect to the specified machine/port
    #
    $tcpclient = new-Object system.Net.Sockets.TcpClient
    $iar = $tcpclient.BeginConnect($serverName,$port,$null,$null)

    #
    # Wait for the connect to complete. Also set a timeout
    # so we don't wait all day
    #
    $connected = $iar.AsyncWaitHandle.WaitOne($timeout,$false)

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

        #if($sts)
        #{
        #    $retVal = $true
        #}
    }
    $tcpclient.Close()

    return $retVal
}

#####################################################################
#
# UpdateState
#
#####################################################################
function UpdateState([System.Xml.XmlElement] $vm, [string] $newState)
{
    <#
    .Synopsis
        Update the VM's state in the XML object representing the VM.
    .Description
        Update the VMs state in the XML object, log a message,
        and update the timestamp of the last state transition.
    .Parameter vm
        The XML object representing the VM who's state needs updating.
    .Parameter newState
        The VMs new state.
    .ReturnValue
        None
    #>

    $oldState = $vm.state
    $vm.state = $newState
    LogMsg 2 "Info : $($vm.vmName) transitioned from ${oldState} to $($vm.state)"
    $vm.stateTimestamp = [DateTime]::Now.ToString()
}

#####################################################################
#
# GetFileFromVM()
#
#####################################################################
function GetFileFromVM([System.Xml.XmlElement] $vm, [string] $remoteFile, [string] $localFile)
{
    <#
    .Synopsis
        Copy a file from a remote system, the VM, to a local copy.
    .Description
        Use SSH to copy a file from a remote system, to a local file,
        possibly renaming the file in the process.
    .Parameter vm
        The XML object representing the VM to copy from.
    .Parameter remoteFile
        The name, including path, of the file on the remote system.
    .Parameter localFile
        The name, including path, the file is to be copied to.
    .ReturnValue
        True if the file was successfully copied, false otherwise.
    #>

    $retVal = $false

    $vmName = $vm.vmName
    $hostname = $vm.ipv4
    $sshKey = $vm.sshKey

    #bin\pscp -q -i ssh\${sshKey} root@${hostname}:${remoteFile} $localFile
    #if ($?)

    $process = Start-Process bin\pscp -ArgumentList "-i ssh\${sshKey} root@${hostname}:${remoteFile} ${localFile}" -PassThru -NoNewWindow -Wait -redirectStandardOutput lisaOut.tmp -redirectStandardError lisaErr.tmp
    if ($process.ExitCode -eq 0)
    {
        $retVal = $true
    }
    else
    {
        LogMsg 1 "ERROR: GetFileFromVM failed. Error message from pscp: "
        $error = Get-Content .\lisaErr.tmp
        LogMsg 1 $error
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
function SendFileToVM([System.Xml.XmlElement] $vm, [string] $localFile, [string] $remoteFile)
{
    <#
    .Synopsis
        Copy a file To a remote system, the VM, to a local copy.
    .Description
        Use SSH to copy a file to a remote system.
    .Parameter vm
        The XML object representing the VM to copy from.
    .Parameter localFile
        The name of the file is to be copied to the remote system.
    .Parameter remoteFile
        The name, including path, of the file on the remote system.
    .ReturnValue
        True if the file was successfully copied, false otherwise.
   #>

    $retVal = $false

    $vmName = $vm.vmName
    $hostname = $vm.ipv4
    $sshKey = $vm.sshKey

    $recurse = ""
    if (test-path -path $localFile -PathType Container )
    {
        $recurse = "-r"
    }

    #bin\pscp -q $recurse -i ssh\${sshKey} $localFile root@${hostname}:${remoteFile}
    #if ($?)

    $process = Start-Process bin\pscp -ArgumentList "-i ssh\${sshKey} ${localFile} root@${hostname}:${remoteFile}" -PassThru -NoNewWindow -Wait -redirectStandardOutput lisaOut.tmp -redirectStandardError lisaErr.tmp
    if ($process.ExitCode -eq 0)
    {
        $retVal = $true
    }
    else
    {
        LogMsg 1 "ERROR: SendFileToVM failed. Error message from pscp: "
        $error = Get-Content .\lisaErr.tmp
        LogMsg 1 $error
    }

    del lisaOut.tmp -ErrorAction "SilentlyContinue"
    del lisaErr.tmp -ErrorAction "SilentlyContinue"

    return $retVal
}

#####################################################################
#
# SendCommandToVM()
#
#####################################################################
function SendCommandToVM([System.Xml.XmlElement] $vm, [string] $command)
{
    <#
    .Synopsis
        Run a command on a remote system.
    .Description
        Use SSH to run a command on a remote system.
    .Parameter vm
        The XML object representing the VM to copy from.
    .Parameter command
        The command to be run on the remote system.
    .ReturnValue
        True if the file was successfully copied, false otherwise.
    #>

    $retVal = $false

    $vmName = $vm.vmName
    $hostname = $vm.ipv4
    $sshKey = $vm.sshKey

    $process = Start-Process bin\plink -ArgumentList "-i ssh\${sshKey} root@${hostname} ${command}" -PassThru -NoNewWindow -redirectStandardOutput lisaOut.tmp -redirectStandardError lisaErr.tmp
    $commandTimeout = 30
    while(!$process.hasExited)
    {
        LogMsg 8 "Waiting 1 second to check the process status for Command = '$command'."
        sleep 1
        $commandTimeout -= 1
        if ($commandTimeout -le 0)
        {
            LogMsg 3 "Killing process for Command = '$command'."
            $process.Kill()
            LogMsg 0 "Error: Send command to VM $vmName timed out for Command = '$command'"
        }
    }

    if ($commandTimeout -gt 0)
    {
        $retVal = $true
        LogMsg 2 "Success: $vmName successfully sent command to VM. Command = '$command'"
    }

    del lisaOut.tmp -ErrorAction "SilentlyContinue"
    del lisaErr.tmp -ErrorAction "SilentlyContinue"

    return $retVal
}

#######################################################################
#
# CreateTestParamString()
#
#######################################################################
function CreateTestParamString([System.Xml.XmlElement] $vm, [XML] $xmlData)
{
    <#
    .Synopsis
        Create a string with all the test parameters.
    .Description
        Create a string and appent each test parameter.  Each
        test parameter is separated by a semicolon.
    .Parameter $vm
        The XML element for the VM under test.
    .Parameter $xmlData
        The XML Document of the test data.
    .Example
        CreateTestParamString $testVM $xmlTestData
    #>

    $tp = ""
    $testData = GetTestData $($vm.currentTest) $xmlData

    if ($xmlData.config.global.testParams -or $testdata.testParams -or $vm.testParams)
    {
        #
        # First, add any global testParams
        #
        if ($xmlData.config.global.testParams)
        {
            LogMsg 9 "Info : $($vm.vmName) Adding glogal test params"
            foreach ($param in $xmlData.config.global.testParams.param)
            {
                $tp += $param + ";"
            }
        }

        #
        # Next, add any test specific testParams
        #
        if ($testdata.testParams)
        {
            LogMsg 9 "Info : $($vm.vmName) Adding testparmas for test $($testData.testName)"
            foreach ($param in $testdata.testParams.param)
            {
                $tp += $param + ";"
            }
        }

        #
        # Now, add VM specific testParams
        #
        if ($vm.testParams)
        {
            LogMsg 9 "Info : $($vm.vmName) Adding VM specific params"
            foreach ($param in $vm.testParams.param)
            {
                $tp += $param + ";"
            }
        }
    }

    #
    # Include the test log directory path
    #
    $tp += "rootDir=$PWD;"

    #
    # Include the test log directory path
    #
    $tp += "TestLogDir=${testDir};"

    #
    # Include the test name too , to redirect remote scripts log to it .
    #
    $testname   = $vm.currentTest
    $tp += "TestName=${testname};"

    return $tp
}

#######################################################################
#
# UpdateCurrentTest()
#
#######################################################################
function UpdateCurrentTest([System.Xml.XmlElement] $vm, [XML] $xmlData)
{
    <#
    .Synopsis
        Update the vm.currentTest attribute.
    .Description
        Determine the name of the next test case in the test suite,
        then update the VMs currentTest attribute with the new
        test name.
    .Parameter $vm
        The XML element for the VM under test.
    .Parameter $xmlData
        The XML Document of the test data.
    .Example
        UpdateCurrentTest $testVM $xmlTestData
    #>

    if (-not $vm)
    {
        LogMsg 0 "Error: UpdateCurrentTest() received a null VM object"
        return
    }

    if (-not $xmlData)
    {
        LogMsg 0 "Error: UpdateCurrentTest() received a null xmlData object"
        return
    }

    #actually this is the previous test. here we need to pick up next new test if existing
    #if previous test has been marked as "done" - for example, test failed and its XML defined to Abort test onError
    $previousTest = $vm.currentTest
    if ($previousTest -eq "done")
    {
        return
    }

    $previousTestData = GetTestData $previousTest $xmlData
    #$nextTest = $currentTest

    #if previous test failed and the XML setting is set to Abort on "onError"
    # then try to quite Lisa
    if ( (($vm.testCaseResults -eq $Aborted) -or ($vm.testCaseResults -eq $Failed)) -and $previousTestData.onError -eq "Abort")
    {
        $vm.currentTest = "done"
        return
    }

    $nextTest = GetNextTest $vm $xmlData
    $vm.currentTest = [string] $nextTest
    $testData = GetTestData $vm.currentTest $xmlData

    # Reset test results if we've moved on to the next test case
    if ($vm.currentTest -ne "done")
    {
        $vm.testCaseResults = "none"
        $vm.individualResults += "0"
    }
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
    .Parameter xmlData
        XML configuration settings.
    .Example
        GetIPv4 $testVMName $xmlData
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
# VerifyTestResourcesExist()
#
#######################################################################
function VerifyTestResourcesExist([System.Xml.XmlElement] $vm, [System.Xml.XmlElement] $testData)
{
    $retVal = $true

    $vmName = $vm.vmName
    $testName = $testData.testName

    #
    # Verify the VM resource <sshKey>
    #
    if ($vm.sshKey)
    {
        $sshKey = ".\ssh\$($vm.sshKey)"
        if (-not (Test-Path -Path "${sshKey}"))
        {
            LogMsg 0 "Error: ${vmName} - the VM sshkey '${sshKey}' does not exist"
            $retVal = $false
        }
    }

    #
    # Verify the VM resource <preStartConfig>
    #
    if ($vm.preStartConfig)
    {
        if ($vm.preStartConfig.file)
        {
            foreach ($preStartScript in $vm.preStartConfig.file)
            {
                if (-not (Test-Path -Path "${preStartScript}"))
                {
                    LogMsg 0 "Error: $($vm.vmName) - the VM preStartConfig script '${preStartScript}' does not exist"
                    $retVal = $false
                }
            }
        }
        else
        {
            if (-not (Test-Path -Path "$($vm.preStartConfig)"))
            {
                LogMsg 0 "Error: $($vm.vmName) - the VM preStartConfig script '${preStartScript}' does not exist"
                $retVal = $false
            }
        }
    }

    #
    # Verify the test resource <setupScript>
    #
    if ($testData.setupScript)
    {
        if ($testData.setupScript.file)
        {
            foreach ($script in $testData.setupScript.file)
            {
                if (-not (Test-Path -Path "${script}"))
                {
                    LogMsg 0 "Error: ${vmName} - the setup script '${script}' for test '${testName}' does not exist"
                    $retVal = $false
                }
            }
        }
        else
        {
            if (-not (Test-Path -Path "$($testData.setupScript)"))
            {
                LogMsg 0 "Error: ${vmName} - the setup script '$($testData.setupScript)' for test '${testName}' does not exist"
                $retVal = $false
            }
        }
    }

    #
    # Verify the test resource <preTest>
    #
    if ($testData.preTest)
    {
        if ($testData.preTest.file)
        {
            foreach ($script in $testData.preTest.file)
            {
                if (-not (Test-Path -Path "${script}"))
                {
                    LogMsg 0 "Error: ${vmName} - the PreTest script '${script}' for test '${testName}' does not exist"
                    $retVal = $false
                }
            }
        }
        else
        {
            if (-not (Test-Path -Path "$($testData.preTest)"))
            {
                LogMsg 0 "Error: ${vmName} - the PreTest script '$($testData.preTest)' for test '${testName}' does not exist"
                $retVal = $false
            }
        }
    }

    #
    # Verify the test resource <postTest>
    #
    if ($testData.postTest)
    {
        if ($testData.postTest.file)
        {
            foreach ($script in $testData.postTest.file)
            {
                if (-not (Test-Path -Path "${script}"))
                {
                    LogMsg 0 "Error: ${vmName} - the PostTest script '${script}' for test '${testName}' does not exist"
                    $retVal = $false
                }
            }
        }
        else
        {
            if (-not (Test-Path -Path "$($testData.postTest)"))
            {
                LogMsg 0 "Error: ${vmName} - the PostTest script '$($testData.postTest)' for test '${testName}' does not exist"
                $retVal = $false
            }
        }
    }

    #
    # Verify the test resource <cleanupScript>
    #
    if ($testData.cleanupScript)
    {
        if ($testData.cleanupScript.file)
        {
            foreach ($script in $testData.cleanupScript.file)
            {
                if (-not (Test-Path -Path "${script}"))
                {
                    LogMsg 0 "Error: ${vmName} - the cleanup script '${script}' for test '${testName}' does not exist"
                    $retVal = $false
                }
            }
        }
        else
        {
            if (-not (Test-Path -Path "$($testData.cleanupScript)"))
            {
                LogMsg 0 "Error: ${vmName} - the cleanup script '$($testData.cleanupScript)' for test '${testName}' does not exist"
                $retVal = $false
            }
        }
    }

    #
    # Verify the test resource <files>
    #
    if ($testData.files)
    {
        $files = ($testData.files).split(",")
        foreach ($f in $files)
        {
            $testFile = $f.trim()
            if (-not (Test-Path -Path "${testFile}"))
            {
                LogMsg 0 "Error: ${vmName} - the test file '${testFile}' for test '${testName}' does not exist"
                $retVal = $false
            }
        }
    }

    #
    # Verify the test resource <testScript> when it is a .ps1
    #
    if (($testData.testScript).EndsWith(".ps1"))
    {
        $testFile = $testData.TestScript
        if (-not (Test-Path -Path "${testFile}"))
        {
            LogMsg 0 "Error: ${vmName} - the test script '${testFile}' for test '${testName}' does not exist"
            $retVal = $false
        }
    }

    return $retVal
}
