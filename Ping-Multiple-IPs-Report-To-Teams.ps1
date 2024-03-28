#Usage ./script.ps1 # of pings, "IP1", "ip2, "ip3" etc.   e.g. ./PingScript.ps1 200 "1.1.1.1", "8.8.8.8", "192.168.1.1"

# Function to send messages to Teams with a title
Function Send-TeamsMessage {
    param (
        [string]$title,
        [string]$message,
        [string]$uri # Webhook URL for Teams
    )

    try {
        # Create the body content for the Teams message
        $body = @{
            title = $title
            text = $message
        } | ConvertTo-Json

        # Send the POST request to the webhook URL
        Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/json"
    } catch {
        Write-Host "Failed to send message to Teams: $_"
    }
}

# Webhook URL for your Teams channel
$webhookUrl = "webhook uri goes here"

# Get the hostname, current time, and number of pings
$hostname = [System.Net.Dns]::GetHostName()
$dateTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$pingCount = $args[0]

# Send a starting message
$startTitle = "Ping Operation Started on $hostname at $dateTime for $pingCount pings"
$startMessage = "Starting the ping operation with $pingCount pings."
Send-TeamsMessage -title $startTitle -message $startMessage -uri $webhookUrl

# Read the IP addresses from the subsequent arguments
$addresses = $args[1..$args.Length]

# Interval between pings in seconds (you can also pass this as an argument if needed)
$pingInterval = 1

# Initialize a hashtable to store results
$results = @{}

# Loop for the specified number of pings
try {
    for ($i = 0; $i -lt $pingCount; $i++) {
        foreach ($address in $addresses) {
            $pingResults = Test-Connection -ComputerName $address -Count 1 -ErrorAction SilentlyContinue

            if ($pingResults) {
                $results[$address] += @($pingResults.ResponseTime)
            } else {
                $results[$address] += @('Failed')
            }
        }

        # Wait for the specified interval before pinging again
        Start-Sleep -Seconds $pingInterval
    }

    # Compile the results
    $finalResults = $addresses | ForEach-Object {
        $address = $_
        $successes = ($results[$address] | Where-Object { $_ -ne 'Failed' -and $_ -notlike 'Error*' }).Count
        $failures = ($results[$address] | Where-Object { $_ -eq 'Failed' }).Count
        $packetLoss = ($failures / $pingCount) * 100

        @{
            Address = $address
            Successes = $successes
            Failures = $failures
            PacketLossPercentage = $packetLoss
        }
    }

    # Send the compiled results to Teams
    $messageText = "Ping results:`n" + ($finalResults | Format-Table | Out-String)
    $resultsTitle = "Ping Operation Completed on $hostname at $(Get-Date -Format "yyyy-MM-dd HH:mm:ss") for $pingCount pings"
    Send-TeamsMessage -title $resultsTitle -message $messageText -uri $webhookUrl

} catch {
    $errorMessage = "An error occurred during the ping operation: $_"
    $errorTitle = "Ping Operation Error on $hostname at $(Get-Date -Format "yyyy-MM-dd HH:mm:ss") for $pingCount pings"
    Send-TeamsMessage -title $errorTitle -message $errorMessage -uri $webhookUrl
}

# Output the compiled results to the console
$finalResults | Format-Table -AutoSize
