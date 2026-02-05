# Ensure script is running as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "❌ Please run this script as Administrator."
    exit 1
}

# Configuration
$enabledModules = @("AdvancedPaste", "PowerOCR", "FancyZones", "Workspaces")
$powerToysPath = "$env:LOCALAPPDATA\Microsoft\PowerToys"

# Step 1: Install PowerToys
Write-Host "📦 Installing PowerToys using winget..." -ForegroundColor Cyan
$wingetInstalled = Get-Command winget -ErrorAction SilentlyContinue
if (-not $wingetInstalled) {
    Write-Error "❌ winget is not available. Please install winget first."
    exit 1
}

# Install PowerToys
try {
    $process = Start-Process -FilePath "winget" -ArgumentList "install", "--id", "Microsoft.PowerToys", "--scope", "machine", "--silent", "--accept-package-agreements", "--accept-source-agreements" -Wait -NoNewWindow -PassThru
    if ($process.ExitCode -ne 0) {
        Write-Error "❌ Failed to install PowerToys. Exit code: $($process.ExitCode)"
        exit 1
    }
} catch {
    Write-Error "❌ Error installing PowerToys: $_"
    exit 1
}

Write-Host "✅ PowerToys installed successfully." -ForegroundColor Green

# Wait for installation to complete
Write-Host "⏳ Waiting for PowerToys to initialize..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Step 2: Locate PowerToys.DSC.exe
$dscExe = "$powerToysPath\PowerToys.DSC.exe"
if (-not (Test-Path $dscExe)) {
    $dscExe = "C:\Program Files\PowerToys\PowerToys.DSC.exe"
}
if (-not (Test-Path $dscExe)) {
    Write-Error "❌ PowerToys.DSC.exe not found."
    exit 1
}

# Step 3: Stop PowerToys service to modify settings
Write-Host "🛑 Stopping PowerToys..." -ForegroundColor Yellow
Stop-Process -Name "PowerToys" -Force -ErrorAction SilentlyContinue
Stop-Process -Name "PowerToys.Settings" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Step 4: Modify settings.json directly (Most reliable method)
Write-Host "🔧 Disabling unwanted modules..." -ForegroundColor Cyan
$settingsPath = "$env:LOCALAPPDATA\Microsoft\PowerToys\settings.json"

# All available modules
$allModules = @(
    "AdvancedPaste","AlwaysOnTop","Awake","ColorPicker","CropAndLock","EnvironmentVariables",
    "FancyZones","FileLocksmith","FindMyMouse","Hosts","ImageResizer","KeyboardManager","MeasureTool",
    "MouseHighlighter","MouseJump","MousePointerCrosshairs","Peek","PowerAccent","PowerOCR","PowerRename",
    "RegistryPreview","ShortcutGuide","TextExtractor","VideoConference","Workspaces","ZoomIt"
)

if (Test-Path $settingsPath) {
    # Backup original settings
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupPath = "$settingsPath.backup-$timestamp"
    Copy-Item $settingsPath $backupPath -Force
    Write-Host "📁 Backup created: $backupPath" -ForegroundColor Gray
    
    # Read and modify settings
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
    
    # Enable only selected modules
    foreach ($module in $allModules) {
        $moduleKey = "{$module}"
        if ($settings.enabled.$moduleKey) {
            $shouldEnable = $enabledModules -contains $module
            $settings.enabled.$moduleKey.value = $shouldEnable
            Write-Host "  $(if ($shouldEnable) {'✅ Enabled'} else {'❌ Disabled'}) $module"
        }
    }
    
    # Save modified settings
    $settings | ConvertTo-Json -Depth 10 | Out-File $settingsPath -Encoding UTF8
    Write-Host "✅ Settings file updated." -ForegroundColor Green
    
} else {
    Write-Warning "⚠️ Settings file not found. Creating default configuration..."
    
    # Create minimal settings with only enabled modules
    $defaultSettings = @{
        "version" = "1.0"
        "name" = "settings"
        "enabled" = @{}
    }
    
    # Add module states
    foreach ($module in $allModules) {
        $moduleKey = "{$module}"
        $defaultSettings.enabled[$moduleKey] = @{
            "value" = $enabledModules -contains $module
        }
    }
    
    # Ensure directory exists
    $settingsDir = Split-Path $settingsPath -Parent
    if (-not (Test-Path $settingsDir)) {
        New-Item -ItemType Directory -Path $settingsDir -Force
    }
    
    $defaultSettings | ConvertTo-Json -Depth 10 | Out-File $settingsPath -Encoding UTF8
    Write-Host "✅ Created new settings file." -ForegroundColor Green
}

# Step 5: Use DSC to verify and apply module settings
Write-Host "`n⚙️ Applying module-specific configurations..." -ForegroundColor Cyan
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

foreach ($module in $enabledModules) {
    $configPath = Join-Path $scriptDir "$module.json"
    if (Test-Path $configPath) {
        try {
            $configJson = Get-Content $configPath -Raw
            & $dscExe set --module $module --resource settings --input $configJson
            Write-Host "✅ Configured $module" -ForegroundColor Green
        } catch {
            $errorMsg = $_.Exception.Message
            Write-Warning "⚠️ Could not configure $module: $errorMsg"
        }
    } else {
        Write-Warning "⚠️ No configuration file for $module"
    }
}

# Step 6: Start PowerToys with new settings
Write-Host "`n🚀 Starting PowerToys with new configuration..." -ForegroundColor Cyan
$powertoysExe = "$powerToysPath\PowerToys.exe"
if (Test-Path $powertoysExe) {
    Start-Process $powertoysExe
    Write-Host "✅ PowerToys started." -ForegroundColor Green
} else {
    # Try program files location
    $powertoysExe = "C:\Program Files\PowerToys\PowerToys.exe"
    if (Test-Path $powertoysExe) {
        Start-Process $powertoysExe
        Write-Host "✅ PowerToys started." -ForegroundColor Green
    } else {
        Write-Warning "⚠️ Could not find PowerToys.exe to start"
    }
}

# Summary
Write-Host "`n" + "="*50
Write-Host "🎉 CONFIGURATION COMPLETE" -ForegroundColor Green
Write-Host "="*50
Write-Host "Enabled modules:" -ForegroundColor Cyan
foreach ($module in $enabledModules) {
    Write-Host "  • $module"
}
Write-Host "`nAll other modules have been disabled."
Write-Host "="*50