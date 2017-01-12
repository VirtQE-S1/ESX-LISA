###############################################################################
##  
## Description:
##   What does this script?
##   What's the result the case expected?
##
###############################################################################
##
## Revision:
## v1.0 - xiaofwan - 11/25/2016 - Draft a template for Powershell script.
## v1.1 - xiaofwan - 12/29/2016 - Add rootDir, sshKey, and ipv4 params support.
## v1.2 - xiaofwan - 1/6/2017 - Move PowerCLIImport, ConnectToVIServer, and
##                              DisconnectWithVIServer functions to tcutils.ps1
## v1.3 - xiaofwan - 1/9/2017 - Fix variable error bug.
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
# Put your test script here
# NOTES:
# 1. Please check testParams first according to your case requirement
# 2. Please close VI Server connection at the end of your test but
#    before return cmdlet by useing function - DisconnectWithVIServer
#
###############################################################################

# An example
$vmOut = Get-VMHost -Name $hvServer | Get-VM -Name $vmName
"$vmOut"

"Info : Debug script completed"
DisconnectWithVIServer
return $True
