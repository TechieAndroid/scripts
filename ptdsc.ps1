# Ensure script is running as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "❌ Please run this script as Administrator."
    exit 1
}

# Step 1: Install PowerToys via winget (per-user install)
Write-Host "📦 Installing PowerToys using winget..."
$wingetInstalled = Get-Command winget -ErrorAction SilentlyContinue
if (-not $wingetInstalled) {
    Write-Error "❌ winget is not available. Please install winget before running this script."
    exit 1
}
Start-Process -FilePath "winget" -ArgumentList "install", "--id", "Microsoft.PowerToys", "--scope", "machine", "--silent", "--accept-package-agreements", "--accept-source-agreements" -Wait -NoNewWindow

# Step 2: Locate PowerToys.DSC.exe
$dscExe = "$env:LOCALAPPDATA\Microsoft\PowerToys\PowerToys.DSC.exe"
if (-not (Test-Path $dscExe)) {
    $dscExe = "C:\Program Files\PowerToys\PowerToys.DSC.exe"
}
if (-not (Test-Path $dscExe)) {
    Write-Error "❌ PowerToys.DSC.exe not found. Please verify installation."
    exit 1
}

# Step 3: Disable all modules except the selected ones
Write-Host "`n🔧 Configuring PowerToys modules..."
$enabledModules = @("AdvancedPaste", "PowerOCR", "FancyZones", "Workspaces")
$allModules = @(
    "AdvancedPaste","AlwaysOnTop","App","Awake","ColorPicker","CropAndLock","EnvironmentVariables",
    "FancyZones","FileLocksmith","FindMyMouse","Hosts","ImageResizer","KeyboardManager","MeasureTool",
    "MouseHighlighter","MouseJump","MousePointerCrosshairs","Peek","PowerAccent","PowerOCR","PowerRename",
    "RegistryPreview","ShortcutGuide","Workspaces","ZoomIt"
)

# Create a hashtable with all modules disabled by default
$moduleStates = [ordered]@{}
foreach ($module in $allModules) {
    $moduleStates[$module] = $enabledModules -contains $module
}

# Create the JSON structure
$settings = [ordered]@{
    name = "General"
    version = "1"
    properties = [ordered]@{
        startup_launch_enabled = $true
        enabled = $moduleStates
        is_elevated = $true
        run_elevated = $false
        is_admin = $true
        download_updates_automatically = $true
        show_updates_notifications = $true
    }
}

# Write to temp file
$tempJsonPath = "$env:TEMP\powertoys_modules_config.json"
$settings | ConvertTo-Json -Depth 5 | Out-File -FilePath $tempJsonPath -Encoding utf8NoBOM

# Apply the settings
try {
    $jsonContent = Get-Content $tempJsonPath -Raw
    & $dscExe set --module "General" --resource settings --input $jsonContent
    Write-Host "✅ Module configuration applied successfully.`n"
} catch {
    Write-Host "❌ Error applying module configuration: $_"
}

# Step 4: Apply module-specific settings
Write-Host "📂 Applying module-specific settings..."
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# First, let's check what format the JSON files should have
foreach ($module in $enabledModules) {
    $inputPath = Join-Path $scriptDir "$module.json"
    if (Test-Path $inputPath) {
        try {
            # Read the JSON file
            $moduleJson = Get-Content $inputPath -Raw
            
            # Check if the JSON has the "settings" wrapper
            $jsonObject = $moduleJson | ConvertFrom-Json
            
            if ($jsonObject.PSObject.Properties.Name -contains "settings") {
                # Extract just the settings object content
                $settingsContent = $jsonObject.settings
                
                # Ensure it has name and version at the top level
                if (-not $settingsContent.PSObject.Properties.Name -contains "name") {
                    $settingsContent | Add-Member -NotePropertyName "name" -NotePropertyValue $module -Force
                }
                if (-not $settingsContent.PSObject.Properties.Name -contains "version") {
                    $settingsContent | Add-Member -NotePropertyName "version" -NotePropertyValue "1" -Force
                }
                
                $moduleJson = $settingsContent | ConvertTo-Json -Depth 10 -Compress
            } else {
                # Ensure it has name and version
                if (-not $jsonObject.PSObject.Properties.Name -contains "name") {
                    $jsonObject | Add-Member -NotePropertyName "name" -NotePropertyValue $module -Force
                }
                if (-not $jsonObject.PSObject.Properties.Name -contains "version") {
                    $jsonObject | Add-Member -NotePropertyName "version" -NotePropertyValue "1" -Force
                }
                
                $moduleJson = $jsonObject | ConvertTo-Json -Depth 10 -Compress
            }
            
            # Apply the settings
            & $dscExe set --module $module --resource settings --input $moduleJson
            Write-Host ("✅ Applied settings for {0}" -f $module)
            
        } catch {
            Write-Host ("❌ Error processing {0}: {1}" -f $module, $_.Exception.Message)
            Write-Host ("   Trying raw JSON...")
            
            # Try with raw JSON as fallback
            try {
                & $dscExe set --module $module --resource settings --input $moduleJson
                Write-Host ("✅ Applied settings for {0} (raw)" -f $module)
            } catch {
                Write-Host ("❌ Failed to apply settings for {0}: {1}" -f $module, $_.Exception.Message)
            }
        }
    } else {
        Write-Host ("⚠️ Missing settings file: {0}" -f $inputPath)
    }
}

Write-Host "`n🎉 PowerToys configuration complete!"
Write-Host "Enabled modules: $($enabledModules -join ', ')"