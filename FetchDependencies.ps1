param(
    [Parameter(Mandatory)]
    [string]$DestinationFolder
)

# Ensure destination folder exists
if (-not (Test-Path $DestinationFolder)) {
    New-Item -Path $DestinationFolder -ItemType Directory | Out-Null
}

# Define URLs for the files to download
$downloads = @{
    "Sysmon.zip" = "https://download.sysinternals.com/files/Sysmon.zip"
    "sysmonconfig-export.xml" = "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml"
    "YamatoSecurityConfigureWinEventLogs.bat" = "https://raw.githubusercontent.com/Yamato-Security/EnableWindowsLogSettings/main/YamatoSecurityConfigureWinEventLogs.bat"
}

# Download each file
foreach ($file in $downloads.Keys) {
    $url = $downloads[$file]
    $destination = Join-Path $DestinationFolder $file

    try {
        Write-Host "Downloading $file..."
        Invoke-WebRequest -Uri $url -OutFile $destination -UseBasicParsing
        Write-Host "$file downloaded successfully."
    } catch {
        Write-Warning "Failed to download ($file): {$_}"
    }
}

# Extract Sysmon if it's a zip file
$sysmonZipPath = Join-Path $DestinationFolder "Sysmon.zip"
if (Test-Path $sysmonZipPath) {
    try {
        Write-Host "Extracting Sysmon..."
        Expand-Archive -Path $sysmonZipPath -DestinationPath $DestinationFolder -Force
        Remove-Item -Path $sysmonZipPath -Force

        # Remove unnecessary files
        $filesToRemove = @(
            "Eula.txt",
            "Sysmon64.exe",
            "Sysmon64a.exe"
        )

        foreach ($file in $filesToRemove) {
            $fullPath = Join-Path $DestinationFolder $file
            if (Test-Path $fullPath) {
                Remove-Item $fullPath -Force
                Write-Host "Removed $file"
            }
        }

        Write-Host "Sysmon extracted and cleaned successfully."
    } catch {
        Write-Warning "Failed to extract Sysmon: $_"
    }
}

