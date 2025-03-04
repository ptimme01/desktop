# Error Handling
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

# Defined variables

# Derived variables

Function Get-PowershellInstalledModule {
    param (
        [string]$ModuleName
    )
  
    if (Get-InstalledModule | Where-Object { $_.Name -eq $ModuleName }) {
        return $false
    }
    else {
        return $true
    }
}

Function Install-PowershellModule {
    param (
        [string]$ModuleName
    )
    if (-not (Get-PowershellInstalledModule -ModuleName $ModuleName)) {
        Install-Module -Scope AllUsers $ModuleName -Confirm:$False -Force
    }
}

Function Get-WingetInstalledApp {
    param(
        [string]$Id
    )
  
    if (Get-WinGetPackage | where-object { $_.id -eq $Id }) {
        return $true
    }
    else {
        return $false
    }
}

Function Install-WingetApp {
    param(
        [string]$Id,
        [string]$CustomArgs
    )
    $DefaultArgs = "--accept-source-agreements --accept-package-agreements"
    $CustomArgs = -join @($DefaultArgs, $CustomArgs)
 
    if (-not (Get-WingetInstalledApp -Id $Id)) {
        Install-WinGetPackage -Id $Id -Mode "Silent" -Scope "System" -Custom $CustomArgs
    }
    
}
# Note: if winget arguments have both single and double quotes, use a here string
# $CustomArgs = @"
#  --override '/VERYSILENT /SP- /MERGETASKS="!runcode,!desktopicon,addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath"'
# "@

Install-PowershellModule -ModuleName "Microsoft.WinGet.Client"

Install-WingetApp -Id Git.Git

Install-WingetApp -Id 7zip.7zip

Install-WingetApp -Id Postman.Postman

Install-WingetApp -Id Microsoft.DotNet.SDK.7

$PowershellCustomArgs = @"
--source winget
"@
Install-WingetApp -Id Microsoft.PowerShell -CustomArgs $PowershellCustomArgs