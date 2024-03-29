<#
.SYNOPSIS
    This script performs an internet speed test and reports the results to a Microsoft Teams channel.
.DESCRIPTION
    The script checks if the speedtest.exe utility exists in the specified path. If not, it downloads the utility, extracts it, and then performs a speed test. The results are saved to text files and reported to a Microsoft Teams channel via a webhook.
.EXAMPLE
    .\SpeedTestReport.ps1
#>


#Enforce TLS 1.2 for compatibility on server 2016
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
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

# The webhook URL for the Microsoft Teams channel
$Uri = "Your Teams URi Goes Here!"
$DownloadURL = "https://install.speedtest.net/app/cli/ookla-speedtest-1.0.0-win64.zip"

Try {
    # Check if speedtest.exe exists, if not download and extract it
    if (-Not (Test-Path "C:\temp\speedtest.exe")) {
        Invoke-WebRequest -Uri $DownloadURL -OutFile "C:\temp\speedtest.zip"
        Expand-Archive -LiteralPath "C:\temp\speedtest.zip" -DestinationPath "C:\temp"
    }
    
    # Perform the speed test and get the results in JSON format
    $Speedtest = & "C:\temp\speedtest.exe" --format=json --accept-license --accept-gdpr
    $Speedtest | Out-File "C:\temp\Last.txt" -Force
    $Speedtest = $Speedtest | ConvertFrom-Json

    # Output the contents of the $Speedtest variable to verify it contains the expected data
    $Speedtest | Out-File "C:\temp\SpeedtestDebugOutput.txt" -Force

    # Get the hostname of the PC
    $Hostname = [System.Net.Dns]::GetHostName()

    # Create a custom object to hold the results
    [PSCustomObject]$SpeedObject = @{
        downloadspeed = [math]::Round($Speedtest.download.bandwidth / 1000000 * 8, 2)
        uploadspeed   = [math]::Round($Speedtest.upload.bandwidth / 1000000 * 8, 2)
        packetloss    = [math]::Round($Speedtest.packetLoss)
        isp           = $Speedtest.isp
        ExternalIP    = $Speedtest.interface.externalIp
        InternalIP    = $Speedtest.interface.internalIp
        UsedServer    = $Speedtest.server.host
        URL           = $Speedtest.result.url
        Jitter        = [math]::Round($Speedtest.ping.jitter)
        Latency       = [math]::Round($Speedtest.ping.latency)
    }

    # Save each measurement to a separate text file
    $SpeedObject.downloadspeed | Out-File "C:\temp\LastDownloadspeed.txt" -Force
    $SpeedObject.uploadspeed | Out-File "C:\temp\LastUploadspeed.txt" -Force
    $SpeedObject.packetloss | Out-File "C:\temp\LastPacketloss.txt" -Force
    $SpeedObject.Jitter | Out-File "C:\temp\LastJitter.txt" -Force
    $SpeedObject.Latency | Out-File "C:\temp\LastLatency.txt" -Force

    # Create a message containing the results and send it to the Teams channel
    $message = @"
Speed Test Results (Hostname: $Hostname):
- Download Speed: $($SpeedObject.downloadspeed) Mbps
- Upload Speed: $($SpeedObject.uploadspeed) Mbps
- Packet Loss: $($SpeedObject.packetloss) %
- ISP: $($SpeedObject.isp)
- External IP: $($SpeedObject.ExternalIP)
- Internal IP: $($SpeedObject.InternalIP)
- Used Server: $($SpeedObject.UsedServer)
- Test URL: $($SpeedObject.URL)
- Jitter: $($SpeedObject.Jitter) ms
- Latency: $($SpeedObject.Latency) ms
"@
    Send-TeamsMessage -message $message -uri $Uri
}
Catch {
    # Catch any errors and report them to the Teams channel
    $ErrorMessage = $_.Exception.Message
    Send-TeamsMessage -message "Error occurred: $ErrorMessage" -uri $Uri
}
