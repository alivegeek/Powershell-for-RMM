#Run as Domain Admin - Update Crednetials in Ninja First and make sure they are set as default for scripting, System doesnt usually work on Domain PCs, probably will on local. --NHolbrook

param(
    [string]$newHostname,
    [string]$teamsWebhookUri
)
# Teams webhook URI (hard-coded)
$teamsWebhookUri = "webhook goes here"

# Function to send a message to Teams
Function Send-TeamsMessage {
    param (
        [string]$message,
        [string]$uri # Webhook URL for Teams
    )

    # Create the body content for the Teams message
    $body = @{
        text = $message
    } | ConvertTo-Json

    # Send the POST request to the webhook URL
    Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/json"
}
# Function to validate the hostname
Function Validate-Hostname {
    param (
        [string]$hostname
    )

    $hostnameRegex = "^(?![0-9]+$)(?!-)[a-zA-Z0-9-]{1,63}(?<!-)$"
    return $hostname -match $hostnameRegex
}

# Get the current hostname
$currentHostname = $env:COMPUTERNAME

# Log file path
$logFilePath = "C:\temp\hostname_change.log"

# Check if the script is running with administrative privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run with administrative privileges."
    exit 1
}

# Validate the new hostname
if (-not (Validate-Hostname -hostname $newHostname)) {
    Write-Error "Invalid hostname provided. The hostname must be a valid DNS label."
    exit 1
}

# Rename the computer
try {
    Rename-Computer -NewName $newHostname -Force
    $renameStatus = "Hostname changed successfully from $currentHostname to $newHostname"
} catch {
    $renameStatus = "Failed to change hostname from $currentHostname to $newHostname. Error: $($_.Exception.Message)"
}

# Log the hostname change
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$logEntry = "$timestamp - $renameStatus"
$logEntry | Out-File -FilePath $logFilePath -Append

# Send a Teams message with the hostname change status
Send-TeamsMessage -message $renameStatus -uri $teamsWebhookUri

# Schedule a reboot at 2 AM
$rebootTime = (Get-Date).Date.AddDays(1).AddHours(2)
$rebootMessage = "Scheduling a reboot at $rebootTime to finalize the hostname change."
Write-Output $rebootMessage
Send-TeamsMessage -message $rebootMessage -uri $teamsWebhookUri

$taskAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-Command Restart-Computer -Force"
$taskTrigger = New-ScheduledTaskTrigger -Once -At $rebootTime
Register-ScheduledTask -TaskName "RebootForHostnameChange" -Action $taskAction -Trigger $taskTrigger -RunLevel Highest -Force
