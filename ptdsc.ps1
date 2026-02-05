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

# Step 3: Enable only selected modules
Write-Host "`n🔧 Enabling selected modules..."
$modules = @("AdvancedPaste", "PowerOCR", "FancyZones", "Workspaces")
$allModules = @(
    "AdvancedPaste","AlwaysOnTop","App","Awake","ColorPicker","CropAndLock","EnvironmentVariables",
    "FancyZones","FileLocksmith","FindMyMouse","Hosts","ImageResizer","KeyboardManager","MeasureTool",
    "MouseHighlighter","MouseJump","MousePointerCrosshairs","Peek","PowerAccent","PowerOCR","PowerRename",
    "RegistryPreview","ShortcutGuide","Workspaces","ZoomIt"
)

# Build the correct JSON structure using ordered hashtables
$enabledMap = [ordered]@{}
foreach ($module in $allModules) {
    $enabledMap[$module] = $modules -contains $module
}
$settings = [ordered]@{
    name = "App"
    version = "1.0"
    properties = [ordered]@{
        enabled = $enabledMap
    }
}

# Write to temp file with correct encoding and compression
$tempJsonPath = "$env:TEMP\powertoys_enabled_modules.json"
$settings | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $tempJsonPath -Encoding utf8NoBOM

# Read the JSON file content and pass it correctly
$jsonContent = Get-Content $tempJsonPath -Raw
& $dscExe set --resource settings --input $jsonContent
Write-Host "✅ Selected modules enabled.`n"

# Step 4: Reapply settings for each module
Write-Host "📂 Reapplying module settings..."
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
foreach ($module in $modules) {
    $inputPath = Join-Path $scriptDir "$module.json"
    if (Test-Path $inputPath) {
        try {
            # Read the JSON file content
            $moduleJson = Get-Content $inputPath -Raw
            
            # Debug: Check what we're passing
            # Write-Host "Applying JSON for $module : $moduleJson"
            
            # Pass the JSON content directly
            & $dscExe set --module $module --resource settings --input $moduleJson
            Write-Host ("✅ Applied settings for {0}" -f $module)
        } catch {
            Write-Host ("❌ Error applying {0}: {1}" -f $module, $_.Exception.Message)
        }
    } else {
        Write-Host ("⚠️ Missing file: {0}" -f $inputPath)
    }
}