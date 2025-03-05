<#
.SYNOPSIS
    WinAuto is a framework to automate running commands that need to be run as SYSTEM on Windows.  

.DESCRIPTION
    Creates a Windows Scheduled Task that runs daily and can be triggered by an event log entry.
    Must be run as an administrator.
    The Scheduled Task is run as SYSTEM and has the highest privileges.
    Has ability to run computer specific commands.
    Does not try to catch up if it misses a run time.
    Can be run from cli or imported/sourced into another script.

.PARAMETER Action
    Note: if imported/sourced into another script, the Action parameter is not required.
    Install - Installs the WinAuto service.
    Uninstall - Uninstalls the WinAuto service.
    Update - Updates the WinAuto service primary script.
    Trigger - Triggers the WinAuto service.
    Run - Runs the WinAuto service.

.INPUTS
    None

.OUTPUTS
    None

.EXAMPLE
    PS> winauto.ps1 -Action Install

.LINK
    None

.NOTES
    Author: Paul Timmerman
    Version: 1.0
    Date: 2025-03-05
#>

param(
    [ValidateSet("Install", "Uninstall", "Update", "Trigger", "Run")]
    [string]$Action
)

# Error Handling
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

# Defined variables
$WinAutoDir = "C:\winauto"
$LogName = "Application"
$LogSource = "winauto"
$GithubUrl = "https://raw.githubusercontent.com/ptimme01/desktop/refs/heads/main/windows/winauto/"
$ScheduledTaskName = "Run-WinAuto"
$DailyRunTime = "3am"

# Derived variables

Function Test-Admin {

    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
 
    return $isAdmin
}

Function New-EventLogSource {
    param (
        [Parameter(Mandatory = $true)]
        [string]$logName,
        [Parameter(Mandatory = $true)]
        [string]$source
    )
    if (!(Test-Admin)) {
        Throw "This script must be run as an administrator."
    }
    
    if (-not [System.Diagnostics.EventLog]::SourceExists($source)) {
        New-EventLog -LogName $logName -Source $source
    }
}

Function New-EventLogEntry {
    param (
        [Parameter(Mandatory = $true)]
        [string]$LogName,
        [Parameter(Mandatory = $true)]
        [string]$LogSource,
        [Parameter(Mandatory = $true)]
        [int]$LogEventID,
        [Parameter(Mandatory = $true)]
        [string]$LogEntryType,
        [Parameter(Mandatory = $true)]
        [string]$LogMessage
    )

    # Check if the entry type is valid
    if (-not (Test-ValidLogEntryType -EntryType $LogEntryType)) {
        throw "Invalid entry type: $LogEntryType"
    }
    # Write the event to the log
    Write-EventLog -LogName $LogName -Source $LogSource -EventID $LogEventID -EntryType $LogEntryType -Message $LogMessage
}

Function Test-ValidLogEntryType {
    param (
        [Parameter(Mandatory = $true)]
        [string]$EntryType
    )

    # Define valid event log entry types
    $validTypes = @("Information", "Warning", "Error", "SuccessAudit", "FailureAudit")

    # Check if the input matches one of the valid types
    return $validTypes -contains $EntryType
}

Function Get-WebFile {
    param (
        [Parameter(Mandatory = $true)]
        [string]$RawUrl, 
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    try {
        Write-Host "Downloading file from GitHub..." -ForegroundColor Cyan
        
        # Download file
        Invoke-WebRequest -Uri $RawUrl -OutFile $OutputPath

        Write-Host "File downloaded successfully to: $OutputPath" -ForegroundColor Green
    }
    catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Function New-LogEventTrigger {
    param (
        [Parameter(Mandatory = $true)]
        [string]$LogName, 
        [Parameter(Mandatory = $true)]
        [string]$LogSource,
        [Parameter(Mandatory = $true)]
        [int]$EventID


    )

    # create TaskEventTrigger, use your own value in Subscription
    $CIMTriggerClass = Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace Root/Microsoft/Windows/TaskScheduler:MSFT_TaskEventTrigger
    $Trigger = New-CimInstance -CimClass $CIMTriggerClass -ClientOnly
    $Trigger.Enabled = $True 
    $Trigger.Subscription = @"
<QueryList>
    <Query Id="0" Path="$LogName">
        <Select Path="$LogName">*[System[Provider[@Name="$LogSource"] and EventID=$EventID]]
        </Select>
    </Query>
</QueryList>
"@
    return $Trigger

}

Function Install-WinAuto {

    ## Create winauto base directory
    if (!(Test-Path -Path $WinAutoDir)) {
        New-Item -Path $WinAutoDir -ItemType Directory -Force
        icacls $WinAutoDir /inheritance:d
        icacls $WinAutoDir /remove "Authenticated Users"
    }

    ## Download winauto files from GitHub
    $WinAutoFiles = @("winauto.ps1", "winauto-stage1.ps1")
    foreach ($WinAutoFile in $WinAutoFiles) {
        if (!(Test-Path -Path "$WinAutoDir\$WinAutoFile")) {
            $RawUrl = "$GithubUrl/$WinAutoFile"
            $OutputPath = "$WinAutoDir\$WinAutoFile"
            Get-WebFile -RawUrl $RawUrl -OutputPath $OutputPath
        }
    }

    ## Create scheduled task
    if (!(Get-ScheduledTask -TaskName $ScheduledTaskName -ErrorAction SilentlyContinue)) {
        $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File $WinAutoDir\invoke-winauto.ps1"
        $Triggers = @(
            (New-ScheduledTaskTrigger -Daily -At $DailyRunTime),
            (New-LogEventTrigger -LogName $LogName -LogSource $LogSource -EventID 500)
        )
        $Settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 6)
        $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        Register-ScheduledTask -TaskName ScheduledTaskName -Action $Action -Trigger $Triggers -Settings $Settings -Principal $Principal 
    }

    New-EventLogEntry -LogName $LogName -LogSource $LogSource -LogEventID 105 -LogEntryType (Get-LogIdMetadata(105)).LogEntryType -LogMessage (Get-LogIdMetadata(105)).LogMessage

}

Function Invoke-WinAuto-Update-Trigger {
    New-EventLogEntry -LogName $LogName -LogSource $LogSource -LogEventID 500 -LogEntryType "Information" -LogMessage "WinAuto update trigger"
}

Function Invoke-WinAuto {
    ## Download and compare winauto.ps1 files (if different tell the stage-1 script to swap them at the end)
   
    $RawUrl = "$GithubUrl/winauto.ps1"
    $OutputPath = "$WinAutoDir\winauto.ps1.new"
    Get-WebFile -RawUrl $RawUrl -OutputPath $OutputPath
    
    if (!(Get-AreTwoFilesSame -File1 "$WinAutoDir\winauto.ps1" -File2 "$WinAutoDir\winauto.ps1.new")) {
        shouldUpdate = $true
    }
    else {
        Remove-Item -Path "$WinAutoDir\winauto.ps1.new" -Force
    }



    ## Download stage-1 script (remove first to get any updates)
    if (test-path -Path "$WinAutoDir\winauto-stage1.ps1") { Remove-Item -Path "$WinAutoDir\winauto-stage1.ps1" }
    if (!(Test-Path -Path "$WinAutoDir\winauto-stage1.ps1")) {
        $RawUrl = "$GithubUrl/$WinAutoFile"
        $OutputPath = "$WinAutoDir\$WinAutoFile"
        Get-WebFile -RawUrl $RawUrl -OutputPath $OutputPath
    }

    ## Download computer specific script (remove first to get any updates)
    if (test-path -Path "$WinAutoDir\$env:COMPUTERNAME.ps1") { Remove-Item -Path "$WinAutoDir\$env:COMPUTERNAME.ps1" }
    try {
        if (!(Test-Path -Path "$WinAutoDir\$env:COMPUTERNAME.ps1")) {
            $RawUrl = "$GithubUrl/$WinAutoFile"
            $OutputPath = "$WinAutoDir\$WinAutoFile"
            Get-WebFile -RawUrl $RawUrl -OutputPath $OutputPath
        }
    }
    catch {
        New-EventLogEntry -LogName $LogName -LogSource $LogSource -LogEventID 120 -LogEntryType (Get-LogIdMetadata(120)).LogEntryType -LogMessage (Get-LogIdMetadata(120)).LogMessage
    
    
    
    
    
    }
    New-EventLogEntry -LogName $LogName -LogSource $LogSource -LogEventID 110 -LogEntryType (Get-LogIdMetadata(110)).LogEntryType -LogMessage (Get-LogIdMetadata(110)).LogMessage

}
Function Uninstall-WinAuto {

    ## Delete winauto base directory
    if (Test-Path -Path $WinAutoDir) {
        Remove-Item -Path $WinAutoDir -Force -Recurse
    }

    ## Delete scheduled task
    if (Get-ScheduledTask -TaskName $ScheduledTaskName -ErrorAction SilentlyContinue) {

    }
    New-EventLogEntry -LogName $LogName -LogSource $LogSource -LogEventID 106 -LogEntryType (Get-LogIdMetadata(106)).LogEntryType -LogMessage (Get-LogIdMetadata(106)).LogMessage

}

Function Get-LogIdMetadata {
    param(
        [Parameter(Mandatory = $true)]
        [int]$LogEventID
    )
    # TODO: validate LogEventID
    $LogIdTable = @{
        100 = @{ LogEntryType = "Information"; LogMessage = "General Informational message" }
        105 = @{ LogEntryType = "Information"; LogMessage = "WinAuto install complete" }
        106 = @{ LogEntryType = "Information"; LogMessage = "WinAuto uninstall complete" }
        110 = @{ LogEntryType = "Information"; LogMessage = "WinAuto run complete" }
        120 = @{ LogEntryType = "Information"; LogMessage = "No computer specific script found" }
        200 = @{ LogEntryType = "Warning"; LogMessage = "General Warning message" }
        300 = @{ LogEntryType = "Error"; LogMessage = "General Error message" }
        305 = @{ LogEntryType = "Error"; LogMessage = "WinAuto tried to run not as admin" }

    }
    return $LogIdTable[$LogEventID]
}

Function Get-AreTwoFilesSame {
    param (
        [Parameter(Mandatory = $true)]
        [string]$File1,
        [Parameter(Mandatory = $true)]
        [string]$File2
    )

    $hash1 = Get-FileHash -Path $File1
    $hash2 = Get-FileHash -Path $File2

    return $hash1.Hash -eq $hash2.Hash
}

# Debug
# if (-not (Test-Admin)) {
New-EventLogEntry -LogName $LogName -LogSource $LogSource -LogEventID 305 -LogEntryType (Get-LogIdMetadata(305)).LogEntryType -LogMessage (Get-LogIdMetadata(305)).LogMessage

#     Throw "This script must be run as an administrator."
# }

Function Main {
#$Action = "Run" # Debug
    switch ($Action) {
        "Install" { Install-WinAuto }
        "Uninstall" { Uninstall-WinAuto }
        "Update" { Update-WinAuto }
        "Trigger" { Invoke-WinAuto-Update-Trigger }
        "Run" { Invoke-WinAuto }
        default { write-host "Parameter Required: Run Get-Help" }
    }
    
}

if ($null -eq $MyInvocation.PSCommandPath) {
    Main

}

