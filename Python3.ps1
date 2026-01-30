# PowerShell Script to Install Python 3.14.2 Silently for All Users
# Note: Python 3.14.2 is a future version - adjust version number as needed

# Run as Administrator check
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires Administrator privileges. Restarting as Administrator..." -ForegroundColor Yellow
    Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# Configuration
$PythonVersion = "3.14.2"
$PythonInstallerURL = "https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-amd64.exe"
$InstallerPath = "$env:TEMP\python-$PythonVersion-amd64.exe"
$InstallPath = "C:\Program Files\Python$($PythonVersion.Split('.')[0])$($PythonVersion.Split('.')[1])"

Write-Host "=== Python $PythonVersion Silent Installation ===" -ForegroundColor Cyan
Write-Host "Target: 64-bit Windows for All Users" -ForegroundColor Cyan
Write-Host "Install Path: $InstallPath" -ForegroundColor Cyan
Write-Host ""

try {
    # Download Python installer
    Write-Host "Downloading Python $PythonVersion installer..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $PythonInstallerURL -OutFile $InstallerPath -UseBasicParsing
    
    if (Test-Path $InstallerPath) {
        Write-Host "Download completed: $InstallerPath" -ForegroundColor Green
        
        # Install Python with silent options
        Write-Host "Installing Python $PythonVersion for all users..." -ForegroundColor Yellow
        
        # Installation arguments:
        # /quiet - Silent installation
        # InstallAllUsers=1 - Install for all users
        # PrependPath=1 - Add Python to system PATH
        # Include_test=0 - Don't install test suite
        # TargetDir - Custom installation directory
        
        $InstallArgs = @(
            "/quiet",
            "InstallAllUsers=1",
            "PrependPath=1",
            "Include_test=0",
            "Include_launcher=1",
            "SimpleInstall=1",
            "TargetDir=`"$InstallPath`""
        )
        
        $Process = Start-Process -FilePath $InstallerPath -ArgumentList $InstallArgs -Wait -NoNewWindow -PassThru
        
        if ($Process.ExitCode -eq 0) {
            Write-Host "Python $PythonVersion installed successfully!" -ForegroundColor Green
            
            # Verify installation
            $PythonExePath = "$InstallPath\python.exe"
            if (Test-Path $PythonExePath) {
                Write-Host "Verifying installation..." -ForegroundColor Yellow
                $PythonVersionOutput = & "$PythonExePath" --version
                Write-Host "Python version: $PythonVersionOutput" -ForegroundColor Green
                
                # Check PATH
                Write-Host "`nPython has been added to the system PATH." -ForegroundColor Green
                Write-Host "You may need to restart your terminal or computer for PATH changes to take effect." -ForegroundColor Yellow
            }
        } else {
            Write-Host "Installation failed with exit code: $($Process.ExitCode)" -ForegroundColor Red
            exit 1
        }
        
        # Cleanup
        Remove-Item -Path $InstallerPath -Force -ErrorAction SilentlyContinue
        Write-Host "`nCleanup completed." -ForegroundColor Green
        
    } else {
        Write-Host "Download failed!" -ForegroundColor Red
        exit 1
    }
    
} catch {
    Write-Host "An error occurred: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Installation Complete ===" -ForegroundColor Cyan
Write-Host "Python $PythonVersion is now available for all users on this system." -ForegroundColor Cyan