# Google Drive Resumable Upload Script with User Input

# Get user input
$accessToken = Read-Host -Prompt "Enter your Google Drive access token"
$filePath = Read-Host -Prompt "Enter the full path to the file you want to upload"
$mimeType = Read-Host -Prompt "Enter the MIME type of the file (e.g., 'application/octet-stream' for binary files)"

# Validate file path
if (-not (Test-Path -Path $filePath)) {
    Write-Host "Error: File not found at the specified path."
    exit
}

# Get file name from path
$fileName = [System.IO.Path]::GetFileName($filePath)
$fileSize = (Get-Item $filePath).Length

# Step 1: Initiate the resumable upload session
$initUrl = "https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable"
$headers = @{
    "Authorization" = "Bearer $accessToken"
    "Content-Type" = "application/json; charset=UTF-8"
    "X-Upload-Content-Type" = $mimeType
    "X-Upload-Content-Length" = $fileSize
}

# Optional metadata for the file
$metadata = @{
    name = $fileName
    mimeType = $mimeType
} | ConvertTo-Json

try {
    Write-Host "Initiating resumable upload session..."
    Write-Host "File: $fileName"
    Write-Host "Size: $($fileSize / 1MB) MB"
    Write-Host "MIME Type: $mimeType"
    
    # Start the resumable session with full response capture
    $response = Invoke-WebRequest -Uri $initUrl -Method Post -Headers $headers -Body $metadata
    
    # Debug output
    Write-Host "Response Status Code: $($response.StatusCode)"
    Write-Host "Response Headers: $($response.Headers | Out-String)"
    
    # Get the session URI from the response headers
    if ($response.Headers -and $response.Headers['Location']) {
        $sessionUri = $response.Headers['Location'][0]
        Write-Host "Resumable session started. Session URI: $sessionUri"
    }
    else {
        throw "Failed to get session URI from response - Location header missing"
    }
    
    # Step 2: Upload the file content
    $uploadHeaders = @{
        "Authorization" = "Bearer $accessToken"
        "Content-Type" = $mimeType
        "Content-Length" = $fileSize
    }
    
    Write-Host "Uploading file content..."
    
    # Upload the file with full response capture
    $uploadResponse = Invoke-WebRequest -Uri $sessionUri -Method Put -Headers $uploadHeaders -InFile $filePath
    
    Write-Host "File uploaded successfully!"
    Write-Host "Response Status Code: $($uploadResponse.StatusCode)"
    Write-Host "Response Content: $($uploadResponse.Content)"
}
catch {
    Write-Host "Error occurred: $_"
    
    # More detailed error information
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd()
        Write-Host "Error response: $responseBody"
    }
    
    Write-Host "Full error details: $($_.Exception | Format-List * -Force | Out-String)"
}
