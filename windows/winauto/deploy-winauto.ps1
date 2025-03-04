# Defined variables
$WinAutoDir = "C:\winauto"
$LogName = "Application"
$LogSource = "winauto"

# Derived variables

Function Test-Admin {
    <#
                .SYNOPSIS
                    Short function to determine whether the logged-on user is an administrator.

                .EXAMPLE
                    Do you honestly need one?  There are no parameters!

                .OUTPUTS
                    $true if user is admin.
                    $false if user is not an admin.
            #>
    [CmdletBinding()]
    param()

    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
 
    return $isAdmin
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
    $Trigger = New-ScheduledTaskTrigger -AtStartup #Creates a inital template don't worry about -AtStartup
    $Trigger = $Trigger | Select-Object *  # Convert to a modifiable object

    # Modify to use Event Trigger
    $Trigger.Enabled = $true
    $Trigger.Subscription = @"
<QueryList>
    <Query Id="0" Path="`$LogName">
        <Select Path="`$LogName">*[System[Provider[@Name='`$LogSource'] and EventID=500]]
        </Select>
    </Query>
</QueryList>
"@

}
# Main
if (-not (Test-Admin)) {
    Throw "This script must be run as an administrator."
}

if (!(Test-Path -Path $WinAutoDir)) {
    New-Item -Path $WinAutoDir -ItemType Directory -Force
}
### permissions on the directory
## Download winauto from GitHub
$WinAutoFiles = @("eventlog-wrapper.psm1", "invoke-winauto.ps1", "invoke-winauto-update-trigger.ps1")
foreach ($WinAutoFile in $WinAutoFiles) {
    $RawUrl = "https://raw.githubusercontent.com/ptimme01/desktop/refs/heads/main/$WinAutoFile"
    $OutputPath = "$WinAutoDir\$WinAutoFile"
    Get-WebFile -RawUrl $RawUrl -OutputPath $OutputPath
}

## Create the scheduled task
$Action = New-ScheduledTaskAction -Execute "powershell.exe -ExecutionPolicy Bypass -File $WinAutoDir\invoke-winauto.ps1"
$Triggers = @(
(New-ScheduledTaskTrigger -Weekly -At 3:00AM),
(New-LogEventTrigger -LogName $LogName -LogSource $LogSource -EventID 500)
)
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName "Invoke-WinAuto" -Action $Action -Trigger $Triggers -Settings $Settings -Principal $Principal
