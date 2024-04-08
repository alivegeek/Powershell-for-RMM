 <#
.SYNOPSIS
    Scan disk utilization on the C drive and send results or log errors to Microsoft Teams.

.DESCRIPTION
    This script scans the C drive to identify the top disk space consumers and sends the results
    or logs any errors to a specified Microsoft Teams channel using a webhook URL. The results
    are also saved to a .txt log file in the "C:\temp" directory.

.NOTES
   
    - The number of top disk space consumers to display is set to 100.
    - The minimum file size threshold is set to 100 MB.
    - The log file is saved to "C:\temp\DiskUtilizationLog.txt".

.EXAMPLE
    just run the script as system, no args needed.
#>

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

# Set the webhook URL for your Teams channel
$webhookUrl = "Web Hook Goes Here"

# Set the number of top disk space consumers to display
$topCount = 100

# Set the minimum file size threshold in MB
$minSizeThreshold = 100

# Set the log file path
$logFilePath = "C:\temp\DiskUtilizationLog.txt"

try {
    # Get the C drive
    $drive = Get-PSDrive -Name C

    # Get the list of top disk space consumers on the C drive
    $topFiles = Get-ChildItem -Path $drive.Root -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Length -ge ($minSizeThreshold * 1MB) } |
        Select-Object -Property @{Name="Size(MB)";Expression={[math]::Round($_.Length / 1MB, 2)}}, FullName, LastWriteTime |
        Sort-Object -Property "Size(MB)" -Descending |
        Select-Object -First $topCount

    # Prepare the message for Teams and the log file
    $message = "Top $topCount disk space consumers on drive C:`n"
    $message += ($topFiles | Format-Table -AutoSize | Out-String)

    # Send the message to Teams
    Send-TeamsMessage -message $message -uri $webhookUrl

    # Save the message to the log file
    $message | Out-File -FilePath $logFilePath -Append
}
catch {
    # Log any errors to Teams and the log file
    $errorMessage = "An error occurred while scanning disk utilization:`n$($_.Exception.Message)"
    Send-TeamsMessage -message $errorMessage -uri $webhookUrl
    $errorMessage | Out-File -FilePath $logFilePath -Append
} 
