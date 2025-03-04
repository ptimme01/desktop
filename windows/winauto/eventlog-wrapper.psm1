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
    Write-EventLog -LogName $LogName -Source $sLogSourceource -EventID $LogEventID -EntryType $LogEntryType -Message $LogMessage
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