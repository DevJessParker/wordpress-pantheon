#Requires -Version 5.1

<#
.SYNOPSIS
    WordPress + Pantheon Quickstart Setup Script for Windows
.DESCRIPTION
    Automates the installation and configuration process for Windows developers.
    NOTE: This script does NOT require Administrator privileges.
          Lando installation (if needed) will be handled separately.
.PARAMETER SkipLandoInstall
    Skip Lando installation check
.PARAMETER Force
    Force full rebuild (destroy existing containers)
.EXAMPLE
    .\quickstart.ps1
#>

[CmdletBinding()]
param(
    [switch]$SkipLandoInstall,
    [switch]$Force
)

Write-Host "========================================" -ForegroundColor Magenta
Write-Host "WordPress + Pantheon Quickstart (Windows)" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

Write-Host "[INFO] NOTE: This script does NOT require Administrator privileges" -ForegroundColor Cyan
Write-Host "[INFO] If Lando is not installed, you'll need to install it manually" -ForegroundColor Cyan
Write-Host ""

# Check prerequisites
Write-Host "[INFO] Checking prerequisites..." -ForegroundColor Cyan

# Function to download and install Lando
function Install-Lando {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host "Installing Lando" -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host ""

    Write-Host "[INFO] Using official Lando installer..." -ForegroundColor Cyan
    Write-Host ""

    try {
        # Use official Lando PowerShell installer
        # https://docs.lando.dev/install/windows.html
        $installerUrl = "https://get.lando.dev/setup-lando.ps1"

        Write-Host "[INFO] Downloading installer script..." -ForegroundColor Cyan
        Write-Host "[INFO] From: $installerUrl" -ForegroundColor Gray
        Write-Host ""

        # Download the installer script
        $installerScript = Invoke-RestMethod -Uri $installerUrl -UseBasicParsing

        Write-Host "[OK] Installer script downloaded" -ForegroundColor Green
        Write-Host ""
        Write-Host "[INFO] Running Lando installation..." -ForegroundColor Cyan
        Write-Host "[WARN] This will install the latest stable version" -ForegroundColor Yellow
        Write-Host "[WARN] You may see UAC prompts - click 'Yes' to continue" -ForegroundColor Yellow
        Write-Host ""

        # Execute the installer script
        # Save to temp file and execute with proper parameter binding
        $tempScript = Join-Path $env:TEMP "setup-lando.ps1"
        [System.IO.File]::WriteAllText($tempScript, $installerScript)
        & $tempScript -Yes -Version stable -Arch auto
        Remove-Item $tempScript -Force -ErrorAction SilentlyContinue

        Write-Host ""
        Write-Host "[OK] Lando installation completed!" -ForegroundColor Green
        Write-Host "[INFO] Please restart PowerShell for changes to take effect" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "After restarting PowerShell, run this script again:" -ForegroundColor Yellow
        Write-Host "  .\quickstart.ps1" -ForegroundColor Yellow
        Write-Host ""

        exit 0

    } catch {
        Write-Host "[ERROR] Failed to install Lando: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Manual installation:" -ForegroundColor Yellow
        Write-Host "  Run this command in PowerShell:" -ForegroundColor Yellow
        Write-Host "    iex (irm 'https://get.lando.dev/setup-lando.ps1' -UseB)" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Or visit: https://docs.lando.dev/install/windows.html" -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }
}

# Check Lando
if (-not (Get-Command lando -ErrorAction SilentlyContinue)) {
    Write-Host "[WARN] Lando is not installed!" -ForegroundColor Yellow
    Write-Host ""
    $install = Read-Host "Would you like to download and install Lando now? (Y/n)"

    if ($install -ne 'n') {
        Install-Lando
    } else {
        Write-Host ""
        Write-Host "[INFO] Manual installation steps:" -ForegroundColor Cyan
        Write-Host "  1. Visit: https://github.com/lando/lando/releases/latest" -ForegroundColor Cyan
        Write-Host "  2. Download: lando-x64-stable.exe" -ForegroundColor Cyan
        Write-Host "  3. Run the installer (requires Admin)" -ForegroundColor Cyan
        Write-Host "  4. Restart PowerShell and run this script again" -ForegroundColor Cyan
        Write-Host ""
        exit 1
    }
}

Write-Host "[OK] Lando is installed" -ForegroundColor Green

# Check Lando version and warn about beta versions
$landoVersion = lando version 2>&1 | Out-String
if ($landoVersion -match 'v(\d+)\.(\d+)\.(\d+)(-beta)?') {
    $major = [int]$matches[1]
    $minor = [int]$matches[2]
    $patch = [int]$matches[3]
    $isBeta = $matches[4] -eq '-beta'

    if ($isBeta) {
        Write-Host "[ERROR] You're running a beta version of Lando (v$major.$minor.$patch-beta)" -ForegroundColor Red
        Write-Host "[ERROR] Beta versions use deprecated Docker images that will cause startup failures" -ForegroundColor Red
        Write-Host ""
        Write-Host "Common errors you'll encounter:" -ForegroundColor Yellow
        Write-Host "  - manifest for bitnami/nginx:1.17.10-debian-10-r52 not found" -ForegroundColor Gray
        Write-Host "  - manifest for bitnami/mysql:5.7.29-debian-10-r51 not found" -ForegroundColor Gray
        Write-Host ""

        $upgrade = Read-Host "Would you like to upgrade to the latest stable version now? (Y/n)"

        if ($upgrade -ne 'n') {
            Install-Lando
        } else {
            Write-Host ""
            $continue = Read-Host "Continue with beta version anyway? This will likely fail (y/N)"
            if ($continue -ne 'y') {
                Write-Host ""
                Write-Host "[INFO] Exiting. Please update Lando and run this script again." -ForegroundColor Cyan
                Write-Host "[INFO] Manual update: https://github.com/lando/lando/releases/latest" -ForegroundColor Cyan
                Write-Host ""
                exit 1
            }
            Write-Host ""
        }
    }

    if ($major -lt 3 -or ($major -eq 3 -and $minor -lt 23)) {
        Write-Host "[WARN] Lando version is outdated (detected: v$major.$minor)" -ForegroundColor Yellow
        Write-Host "[WARN] Recommend updating to v3.23+ for best compatibility" -ForegroundColor Yellow
        Write-Host ""

        $upgrade = Read-Host "Would you like to upgrade to the latest stable version? (y/N)"

        if ($upgrade -eq 'y') {
            Install-Lando
        } else {
            Write-Host "[INFO] Continuing with current version..." -ForegroundColor Cyan
            Write-Host ""
        }
    }
}

# Check Docker
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] Docker is not installed!" -ForegroundColor Red
    Write-Host "Install from: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
    exit 1
}

# Check if Docker is running
try {
    docker ps 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw }
    Write-Host "[OK] Docker is running" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Docker is not running!" -ForegroundColor Red
    Write-Host "Please start Docker Desktop and try again" -ForegroundColor Yellow
    exit 1
}

# Configure environment
Write-Host ""
Write-Host "========================================"  -ForegroundColor Magenta
Write-Host "Configuring Environment" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

if (Test-Path ".env") {
    Write-Host "[WARN] .env file already exists" -ForegroundColor Yellow
    $overwrite = Read-Host "Reconfigure? (y/N)"
    if ($overwrite -ne 'y') {
        Write-Host "[INFO] Keeping existing .env" -ForegroundColor Cyan
    } else {
        Remove-Item ".env"
    }
}

if (-not (Test-Path ".env")) {
    if (-not (Test-Path ".env.example")) {
        Write-Host "[ERROR] .env.example not found!" -ForegroundColor Red
        exit 1
    }

    Write-Host "Enter your Pantheon site details:" -ForegroundColor Cyan
    Write-Host ""
    $site = Read-Host "Site Name (e.g., my-site)"
    $uuid = Read-Host "Site UUID"
    $token = Read-Host "Machine Token" -AsSecureString
    $tokenPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($token))

    # Create .env with Unix line endings (LF)
    $content = Get-Content ".env.example" -Raw
    $content = $content -replace "PANTHEON_SITE=your-site-name", "PANTHEON_SITE=$site"
    $content = $content -replace "PANTHEON_SITE_ID=your-site-uuid", "PANTHEON_SITE_ID=$uuid"
    $content = $content -replace "TERMINUS_TOKEN=your-terminus-machine-token", "TERMINUS_TOKEN=$tokenPlain"
    $content = $content -replace "PANTHEON_SITE_URL=dev-your-site-name.pantheonsite.io", "PANTHEON_SITE_URL=dev-$site.pantheonsite.io"
    $content = $content -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText("$PWD\.env", $content)

    Write-Host "[OK] .env created" -ForegroundColor Green
}

# Update .lando.yml
if (Test-Path ".lando.yml.example") {
    Copy-Item ".lando.yml.example" ".lando.yml" -Force

    # Read env vars
    $envVars = @{}
    Get-Content ".env" | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]*)\s*=\s*(.*)$') {
            $envVars[$matches[1].Trim()] = $matches[2].Trim() -replace "`r", "" -replace "`n", ""
        }
    }

    # Update .lando.yml
    $landoContent = Get-Content ".lando.yml" -Raw

    # Replace site configuration
    $landoContent = $landoContent -replace "site: YOUR_PANTHEON_SITE_NAME", "site: $($envVars['PANTHEON_SITE'])"
    $landoContent = $landoContent -replace "id: YOUR_PANTHEON_SITE_ID", "id: $($envVars['PANTHEON_SITE_ID'])"

    # Add env_file reference if not present (fixes TERMINUS_TOKEN loading)
    if ($landoContent -notmatch 'env_file:') {
        $landoContent = $landoContent -replace "(?m)(id: .+?)(\r?\n)", "`$1`n  env_file:`n    - .env`$2"
    }

    # Fix deprecated Bitnami MySQL image (replace with official MySQL image)
    # This fixes: "manifest for bitnami/mysql:5.7.29-debian-10-r51 not found"
    if ($landoContent -match 'type: mysql:5\.7' -and $landoContent -notmatch 'image: mysql:5\.7') {
        $landoContent = $landoContent -replace "(?ms)(database:.*?overrides:)", "`$1`n      image: mysql:5.7"
    }

    # Normalize line endings to Unix (LF)
    $landoContent = $landoContent -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText("$PWD\.lando.yml", $landoContent)

    Write-Host "[OK] .lando.yml configured with .env reference and image fixes" -ForegroundColor Green
}

# Start Lando
Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "Starting Lando" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "[INFO] First run: 3-6 minutes" -ForegroundColor Cyan
Write-Host "[INFO] Subsequent runs: 15-30 seconds" -ForegroundColor Cyan
Write-Host ""

if ($Force) {
    Write-Host "[INFO] Force rebuild requested..." -ForegroundColor Cyan
    lando stop 2>&1 | Out-Null
    Start-Sleep -Seconds 2
    lando destroy -y 2>&1 | Out-Null
    Start-Sleep -Seconds 2
}

# Retry logic for lando start
$MaxAttempts = 3
$LandoStarted = $false
$BitnamiError = $false

for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    if ($attempt -eq 1) {
        Write-Host "[INFO] Starting Lando (attempt $attempt/$MaxAttempts)..." -ForegroundColor Cyan
        Write-Host ""
        $landoOutput = lando start 2>&1 | Out-String
        Write-Host $landoOutput

        # Check for Bitnami image errors
        if ($landoOutput -match 'bitnami/(nginx|mysql).*not found') {
            $BitnamiError = $true
        }
    }
    elseif ($attempt -eq 2) {
        Write-Host "[WARN] First attempt failed. Destroying and starting fresh (attempt $attempt/$MaxAttempts)..." -ForegroundColor Yellow
        lando stop 2>&1 | Out-Null
        Start-Sleep -Seconds 2
        lando destroy -y 2>&1 | Out-Null
        Start-Sleep -Seconds 2
        $landoOutput = lando start 2>&1 | Out-String
        Write-Host $landoOutput

        if ($landoOutput -match 'bitnami/(nginx|mysql).*not found') {
            $BitnamiError = $true
        }
    }
    else {
        Write-Host "[WARN] Second attempt failed. Performing aggressive cleanup (attempt $attempt/$MaxAttempts)..." -ForegroundColor Yellow
        lando stop 2>&1 | Out-Null
        Start-Sleep -Seconds 2
        lando destroy -y 2>&1 | Out-Null
        Start-Sleep -Seconds 2
        $landoOutput = lando start 2>&1 | Out-String
        Write-Host $landoOutput

        if ($landoOutput -match 'bitnami/(nginx|mysql).*not found') {
            $BitnamiError = $true
        }
    }

    # If Bitnami error detected, stop retrying
    if ($BitnamiError) {
        Write-Host ""
        Write-Host "[ERROR] Deprecated Bitnami Docker images detected!" -ForegroundColor Red
        Write-Host "[ERROR] This is a known issue with Lando beta versions" -ForegroundColor Red
        Write-Host ""
        Write-Host "The ONLY solution is to update Lando to the latest stable version." -ForegroundColor Yellow
        Write-Host ""

        $upgrade = Read-Host "Would you like to download and install the latest stable version now? (Y/n)"

        if ($upgrade -ne 'n') {
            # Clean up failed containers first
            Write-Host ""
            Write-Host "[INFO] Cleaning up failed containers..." -ForegroundColor Cyan
            lando destroy -y 2>&1 | Out-Null

            Install-Lando
        } else {
            Write-Host ""
            Write-Host "[INFO] Manual update steps:" -ForegroundColor Cyan
            Write-Host "  1. Download: https://github.com/lando/lando/releases/latest" -ForegroundColor Cyan
            Write-Host "  2. Install: lando-x64-stable.exe (requires Admin)" -ForegroundColor Cyan
            Write-Host "  3. Restart PowerShell and run this script again" -ForegroundColor Cyan
            Write-Host ""
            exit 1
        }
    }

    # Verify containers are actually running (not just checking exit code)
    Start-Sleep -Seconds 5
    Write-Host "[INFO] Verifying containers are running..." -ForegroundColor Cyan

    $landoInfo = lando info --format json 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue

    if ($landoInfo -and $landoInfo.Count -gt 0) {
        $healthyServices = ($landoInfo | Where-Object { $_.healthy -eq $true }).Count
        if ($healthyServices -gt 0) {
            Write-Host "[OK] Lando started successfully! ($healthyServices healthy services)" -ForegroundColor Green
            $LandoStarted = $true
            break
        }
    }

    if ($attempt -lt $MaxAttempts) {
        Write-Host "[WARN] Containers not running properly, will retry..." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
    }
}

if (-not $LandoStarted) {
    Write-Host ""
    Write-Host "[ERROR] Failed to start Lando after $MaxAttempts attempts" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting steps:" -ForegroundColor Yellow
    Write-Host "  1. Check Docker Desktop is running and healthy" -ForegroundColor Gray
    Write-Host "  2. Restart Docker Desktop completely" -ForegroundColor Gray
    Write-Host "  3. Try manually: lando stop; lando destroy -y; lando start" -ForegroundColor Gray
    Write-Host "  4. Check for port conflicts (80, 443, 3306 in use)" -ForegroundColor Gray
    Write-Host "  5. Check Lando logs: lando logs" -ForegroundColor Gray
    Write-Host "  6. Update Lando from: https://github.com/lando/lando/releases/latest" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Performance troubleshooting:" -ForegroundColor Yellow
    Write-Host "  - Check your internet connection" -ForegroundColor Gray
    Write-Host "  - Check Docker Desktop resources (CPU/Memory in Settings)" -ForegroundColor Gray
    Write-Host "  - Consider using WSL2 for 5-10x faster performance" -ForegroundColor Gray
    Write-Host ""
    exit 1
}

# Authenticate with Terminus
Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "Authenticating with Terminus" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

$envVars = @{}
Get-Content ".env" | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]*)\s*=\s*(.*)$') {
        $envVars[$matches[1].Trim()] = $matches[2].Trim() -replace "`r", "" -replace "`n", ""
    }
}

lando ssh -c "mkdir -p /var/www/.terminus/cache && chmod -R 755 /var/www/.terminus" 2>&1 | Out-Null
lando terminus auth:login --machine-token="$($envVars['TERMINUS_TOKEN'])" 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Terminus authenticated" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Terminus authentication failed" -ForegroundColor Red
    Write-Host "Check your TERMINUS_TOKEN in .env" -ForegroundColor Yellow
    exit 1
}

# Pull data
Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "Syncing Data from Pantheon" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

$pullData = Read-Host "Pull database and files? (Y/n)"
if ($pullData -ne 'n') {
    Write-Host "[INFO] Pulling from Pantheon..." -ForegroundColor Cyan
    $env:TERMINUS_MACHINE_TOKEN = $envVars['TERMINUS_TOKEN']
    lando pull

    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Pull completed!" -ForegroundColor Green
    }
}

# Done!
Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "Setup Complete!" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "Your site is ready!" -ForegroundColor Green
Write-Host ""
Write-Host "Site URL:  https://wordpress-pantheon.lndo.site" -ForegroundColor Cyan
Write-Host "Admin:     https://wordpress-pantheon.lndo.site/wp-admin" -ForegroundColor Cyan
Write-Host ""
Write-Host "Commands:" -ForegroundColor Yellow
Write-Host "  lando start      - Start environment (15-30s)" -ForegroundColor Gray
Write-Host "  lando stop       - Stop environment" -ForegroundColor Gray
Write-Host "  lando pull-db    - Pull database" -ForegroundColor Gray
Write-Host "  lando wp         - Run WP-CLI commands" -ForegroundColor Gray
Write-Host ""
Write-Host "Performance Tip:" -ForegroundColor Yellow
Write-Host "  For 5-10x faster performance, use WSL2:" -ForegroundColor Gray
Write-Host "    wsl" -ForegroundColor Gray
Write-Host "    cd ~" -ForegroundColor Gray
Write-Host "    git clone <repo>" -ForegroundColor Gray
Write-Host "    ./quickstart.sh" -ForegroundColor Gray
Write-Host ""
