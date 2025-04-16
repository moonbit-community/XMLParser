param() # Indicate this is a script file

$download_url = "https://www.w3.org/XML/Test/xmlts20130923.zip"
$target_dir = "resource"
$zip_file = "xmlts20130923.zip"
$ErrorActionPreference = "Stop" # Exit script on first error

try {
    if (-not (Test-Path $target_dir)) {
        New-Item -ItemType Directory -Force -Path $target_dir | Out-Null
    }

    Write-Host "Download $($download_url) ..."
    Invoke-WebRequest -Uri $download_url -OutFile $zip_file

    Write-Host "Unzip to $($target_dir) ..."
    Expand-Archive -Path $zip_file -DestinationPath $target_dir -Force

    Write-Host "Removed $($zip_file)"
    Remove-Item -Path $zip_file

} catch {
    Write-Error "Script failed: $($_.Exception.Message)"
    exit 1
}

Write-Host "Test suite downloaded and extracted successfully." 