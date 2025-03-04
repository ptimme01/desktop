Import-Module -Name "$PSScriptRoot\eventlog-wrapper.psm1"
$LogName = "Application"
$LogSource = "winauto"

# Main
New-EventLogEntry -LogName $LogName -LogSource $LogSource -LogEventID 500 -LogEntryType "Information" -LogMessage "WinAuto update trigger invoked."
