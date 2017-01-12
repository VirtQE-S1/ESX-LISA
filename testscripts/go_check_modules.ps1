###############################################################################
##
## Fork from github.com/LIS/lis-test, make it work with VMware ESX testing
##
## All rights reserved.
## Licensed under the Apache License, Version 2.0 (the ""License"");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##     http://www.apache.org/licenses/LICENSE-2.0
##
## THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS
## OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
## ANY IMPLIED WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR
## PURPOSE, MERCHANTABLITY OR NON-INFRINGEMENT.
##
## See the Apache Version 2.0 License for specific language governing
## permissions and limitations under the License.
##
###############################################################################
##
## Revision:
## v1.0 - hhei - 1/6/2017 - Check modules in vm.
##
###############################################################################

###############################################################################
##
## Description:
##   Check modules in vm
##   If true, case is passed; false, case is failed
##
###############################################################################
<#
.Synopsis
    Demo script ONLY for test script.

.Description
    A demo for Powershell script as test script.

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
$tcCovered = "undefined"

$params = $testParams.Split(";")
foreach ($p in $params)
{
    $fields = $p.Split("=")
    switch ($fields[0].Trim())
    {
    "sshKey"       { $sshKey = $fields[1].Trim() }
    "rootDir"      { $rootDir = $fields[1].Trim() }
    "ipv4"         { $ipv4 = $fields[1].Trim() }
    "TC_COVERED"   { $tcCovered = $fields[1].Trim() }
    "rhel6_modules" { $rhel6_modules = $fields[1].Trim()}
    "rhel7_modules" { $rhel7_modules = $fields[1].Trim()}
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

$Result = $False
$vmObj = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
if (-not $vmObj)
{
    Write-Error -Message "CheckModules: Unable to create VM object for VM $vmName" -Category ObjectNotFound -ErrorAction SilentlyContinue
}
else
{
    # Get guest version
    $DISTRO = ""
    $modules_array = ""
    $DISTRO = GetLinuxDistro ${ipv4} ${sshKey}
    if ( -not $DISTRO )
    {
        "Error : Guest OS version is NULL"
        $Result = $False
    }
    elseif ( $DISTRO -eq "RedHat6" )
    {
        $modules_array = $rhel6_modules.split(",")
        $Result = $True
    }
    elseif ( $DISTRO -eq "RedHat7" )
    {
        $modules_array = $rhel7_modules.split(",")
        $Result = $True
    }
    else
    {
        "Error : Guest OS version is $DISTRO"
        $Result = $False
    }

    "Info : Guest OS version is $DISTRO"

    if ( $Result -eq $True )
    {
        foreach ( $m in $modules_array )
        {
            $module = $m.Trim()
            $r = CheckModule $ipv4 $sshKey $module
            if ( $r -eq $True )
            {
                "Info : Check module '$module' successfully"
            }
            else
            {
                "Error : Check module '$module' failed"
                $Result = $False
            }
        }
    }
}

"Info : go_check_modules.ps1 script completed"
DisconnectWithVIServer
return $Result
