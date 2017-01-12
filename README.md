    ___________ _____________  ___         .____    .___  _________   _____   
    \_   _____//   _____/\   \/  /         |    |   |   |/   _____/  /  _  \  
     |    __)_ \_____  \  \     /   ______ |    |   |   |\_____  \  /  /_\  \ 
     |        \/        \ /     \  /_____/ |    |___|   |/        \/    |    \
    /_______  /_______  //___/\  \         |_______ \___/_______  /\____|__  /
            \/        \/       \_/                 \/           \/         \/ 

# Overview
ESX-LISA is an automation testing framework based on [github.com/LIS/lis-test](https://github.com/LIS/lis-test) project.
In order to support ESX, ESX-LISA uses PowerCLI to automate all aspects of vSphere management,
including network, storage, VM, guest OS and more. 
This framework automates the tasks required to test the Redhat Enterprise Linux Server on WMware ESX Server.

# Documentation
## The basics behavior of the automation is:
1.  Start a VM
2.  Push files to a VM
3.  Start a script executing on a VM
4.  Collect files from a VM
5.  Shutdown a VM

## Other required powershell scripts includes:
### stateEngine.ps1

Provides the functions that drive the VMs through various states that result in a test case being
run on a VM.

### utilFunctions.ps1
Provides utility functions used by the automation.

### OSAbstractions.ps1
Functions that return a OS specific command line.  This was added when Integrated services were added to FreeBSD.

## Command sample
A test run is driven by an XML file.  A sample command might look like the following:

    .\lisa.ps1 run xml\debug_demo.xml -dbgLevel 5

## Configuration file
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
                <testScript>testscripts\debug_demo.ps1</testScript>
                <testparams>
                    <param>TC_COVERED=ESX-DEMO-001</param>
                </testparams>
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
                <sshKey>id_rsa.ppk</sshKey>
                <suite>debug_demo_suite</suite>
            </vm>
        </VMs>

    </config>

## VM provision
The automation scripts make some assumptions about the VMs
used to run the tests.  This requires test VMs be provisioned
prior to running tests. The following settings need to be provisioned.

1.  Disable Linux firewall.
2.  Add your public key into ~/.ssh/authorized_keys.
3.  The following packages must be installed.
    *  development-tools
    *  at
    *  dos2unix
    *  dosfstools
    *  wget
    *  bc
    *  ntpdate
4.  The yum repo must be configured.

## SSH key
SSH keys are used to pass commands to Linux VMs, so the public
ssh Key must to copied to the VM before the test is started.

## dos2unix
The dos2unix must be installed.  It is used to ensure the file
has the correct end of line character.

## Putty with private key
The automation scripts currently use Putty as the SSH client.
You will need to copy the Putty executables to the ./bin
directory.  You will also need to convert the private key into
a Putty Private Key (.ppk).

## How to configure a case development environment?
1.  Choose a Windows machine which has Powershell installed and have connection with VCenter server
2.  Download and install Git client for Windows, like Git-2.8.1-64bit.exe
3.  Download and install a code editor, such as [Atom](https://atom.io/) or [Visual Studio Code](https://code.visualstudio.com/).
4.  Add four system environment variables from Control Pannel -> System -> Advanced system settings -> Environment Variables... -> System variables -> New...

    | Name            | Description                                                    |
    |-----------------|----------------------------------------------------------------|
    | $ENVVISIPADDR   | vSphere Center Server IP address                               |
    | $ENVVISUSERNAME | vSphere Center Server login username                           |
    | $ENVVISPASSWORD | vSphere Center Server login password                           |
    | $ENVVISPROTOCOL | Connection protocol with vSphere Center Server, such as HTTPS. |

5.  Edit xml\debug_demo.xml, replace ESXI_HOST_IPADDRESS and VM_NAME with your settings.
6.  Run demo case with the following cmdlet:

    .\lisa.ps1 run .\xml\debug_demo.xml -dbgLevel 10

