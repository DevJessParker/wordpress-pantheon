# WordPress + Pantheon Quickstart Setup Script (Windows)
# This script automates the installation and configuration process
# Requires: PowerShell 5.1 or higher

#Requires -Version 5.1

[CmdletBinding()]
param(
    [switch]$SkipLandoInstall,
    [string]$LandoInstallPath = "",
    [switch]$Help
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Helper function to extract UUID from various input formats
function Extract-PantheonUUID {
    param(
        [string]$UserInput
    )

    # Remove whitespace
    $UserInput = $UserInput.Trim()

    # UUID regex pattern (8-4-4-4-12 format)
    $uuidPattern = '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'

    # Extract UUID from input
    if ($UserInput -match $uuidPattern) {
        $uuid = $matches[0]

        # Check if input contains environment references
        if ($UserInput -match '#(test|live)' -or $UserInput -match '/(test|live)') {
            Write-ColorOutput "WARNING: This tool only works with DEV environment" -Type Warning
            Write-ColorOutput "Test and Live environments are not supported for local development" -Type Warning
            Write-ColorOutput "The UUID will be used with the dev environment only" -Type Info
        }

        return $uuid.ToLower()
    } else {
        Write-ColorOutput "Invalid UUID format" -Type Error
        Write-ColorOutput "Expected format: <uuid>" -Type Info
        Write-ColorOutput "" -Type Info
        Write-ColorOutput "You can paste:" -Type Info
        Write-ColorOutput "  - Just the UUID: <uuid>" -Type Info
        Write-ColorOutput "  - With fragment: <uuid>#dev/code" -Type Info
        Write-ColorOutput "  - Full URL: https://dashboard.pantheon.io/sites/<uuid>" -Type Info
        return $null
    }
}

# Helper functions for colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Type = "Info"
    )

    switch ($Type) {
        "Success" {
            Write-Host "[OK] $Message" -ForegroundColor Green
        }
        "Info" {
            Write-Host "[INFO] $Message" -ForegroundColor Cyan
        }
        "Warning" {
            Write-Host "[WARN] $Message" -ForegroundColor Yellow
        }
        "Error" {
            Write-Host "[ERROR] $Message" -ForegroundColor Red
        }
        "Header" {
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Magenta
            Write-Host $Message -ForegroundColor Magenta
            Write-Host "========================================" -ForegroundColor Magenta
            Write-Host ""
        }
    }
}

if ($Help) {
    Write-Host @"
WordPress + Pantheon Quickstart Setup

Usage: .\quickstart.ps1 [options]

IMPORTANT: This script MUST be run as Administrator

Options:
  -SkipLandoInstall           Skip Lando installation check/install
  -LandoInstallPath <path>    Custom installation path for Lando
                              Default: C:\Program Files\Lando
  -Help                       Show this help message

Examples:
  Right-click PowerShell -> Run as Administrator, then:

  .\quickstart.ps1
  .\quickstart.ps1 -LandoInstallPath "D:\Tools\Lando"
  .\quickstart.ps1 -SkipLandoInstall

This script will:
  1. Check for prerequisites (Git, Docker Desktop)
  2. Install Lando (if not present)
  3. Configure environment variables
  4. Set up Lando configuration
  5. Authenticate with Terminus
  6. Start the development environment
  7. Pull database and files from Pantheon

Requirements:
  - Windows 10/11
  - Administrator privileges (REQUIRED)
  - PowerShell 5.1 or higher
  - Internet connection
  - Pantheon account with machine token

"@
    exit 0
}

Write-ColorOutput "WordPress + Pantheon Quickstart Setup" -Type Header

# Check PowerShell version
$psVersion = $PSVersionTable.PSVersion
Write-ColorOutput "PowerShell Version: $($psVersion.Major).$($psVersion.Minor)" -Type Info

if ($psVersion.Major -lt 5) {
    Write-ColorOutput "PowerShell 5.1 or higher is required. Please upgrade PowerShell." -Type Error
    Write-ColorOutput "Download from: https://aka.ms/powershell" -Type Info
    exit 1
}

##############################################################################
# 1. Check Prerequisites
##############################################################################

Write-ColorOutput "Step 1: Checking Prerequisites" -Type Header

# Check if running as administrator (REQUIRED)
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-ColorOutput "ERROR: This script requires Administrator privileges" -Type Error
    Write-ColorOutput "" -Type Info
    Write-ColorOutput "Please run PowerShell as Administrator:" -Type Info
    Write-ColorOutput "  1. Close this window" -Type Info
    Write-ColorOutput "  2. Right-click PowerShell" -Type Info
    Write-ColorOutput "  3. Select 'Run as Administrator'" -Type Info
    Write-ColorOutput "  4. Run the script again: .\quickstart.ps1" -Type Info
    Write-Host ""
    Write-Host "Press any key to exit..." -NoNewline
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# Check Git
Write-ColorOutput "Checking for Git..." -Type Info
try {
    $gitVersion = & git --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "Git is installed: $gitVersion" -Type Success
    } else {
        throw "Git command failed"
    }
} catch {
    Write-ColorOutput "Git is not installed!" -Type Error
    Write-ColorOutput "Please install Git from: https://git-scm.com/download/win" -Type Info
    Write-ColorOutput "After installing Git, restart PowerShell and re-run this script." -Type Info
    exit 1
}

# Check Docker Desktop
Write-ColorOutput "Checking for Docker Desktop..." -Type Info
try {
    $dockerVersion = & docker --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "Docker is installed: $dockerVersion" -Type Success

        # Check if Docker is running
        $null = & docker ps 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "Docker is running" -Type Success
        } else {
            Write-ColorOutput "Docker is installed but not running" -Type Warning
            Write-ColorOutput "Please start Docker Desktop and wait for it to be ready" -Type Info
            Write-Host "Press any key when Docker Desktop is running..." -NoNewline
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            Write-Host ""
        }
    } else {
        throw "Docker command failed"
    }
} catch {
    Write-ColorOutput "Docker Desktop is not installed!" -Type Error
    Write-ColorOutput "Please install Docker Desktop from: https://www.docker.com/products/docker-desktop" -Type Info
    Write-ColorOutput "After installing Docker Desktop, restart PowerShell and re-run this script." -Type Info
    exit 1
}

##############################################################################
# 2. Install Lando
##############################################################################

if (-not $SkipLandoInstall) {
    Write-ColorOutput "Step 2: Checking/Installing Lando" -Type Header

    # Check if Lando is already installed
    $landoInstalled = $false
    $landoPath = $null
    $landoVersion = $null

    # Check common installation locations
    $possiblePaths = @(
        "C:\Program Files\Lando\lando.exe",
        "${env:ProgramFiles}\Lando\lando.exe",
        "${env:LOCALAPPDATA}\Programs\Lando\lando.exe"
    )

    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            $landoPath = Split-Path $path -Parent
            $landoInstalled = $true
            break
        }
    }

    # Try to get version from PATH
    if (-not $landoInstalled) {
        try {
            $landoVersion = & lando version 2>&1
            if ($LASTEXITCODE -eq 0) {
                $landoInstalled = $true
            }
        } catch {
            # Lando not in PATH, continue with installation
        }
    } else {
        # Found Lando at specific path, get version
        try {
            $landoVersion = & "$landoPath\lando.exe" version 2>&1
        } catch {
            Write-ColorOutput "Lando found but unable to verify version" -Type Warning
        }
    }

    # Check if installed version needs upgrade
    $needsUpgrade = $false
    if ($landoInstalled -and $landoVersion) {
        if ($landoPath) {
            Write-ColorOutput "Lando is already installed at: $landoPath" -Type Success
        } else {
            Write-ColorOutput "Lando is already installed (found in PATH)" -Type Success
        }
        Write-ColorOutput "Version: $landoVersion" -Type Info

        # Check if it's a beta version
        if ($landoVersion -match 'beta') {
            Write-ColorOutput "Beta version detected - upgrading to stable release" -Type Warning
            $needsUpgrade = $true
        }
        # Check if it's a very old version (pre-v3.20)
        elseif ($landoVersion -match 'v(\d+)\.(\d+)\.(\d+)') {
            $major = [int]$matches[1]
            $minor = [int]$matches[2]

            if ($major -lt 3 -or ($major -eq 3 -and $minor -lt 20)) {
                Write-ColorOutput "Outdated version detected - upgrading to latest stable" -Type Warning
                $needsUpgrade = $true
            }
        }

        if (-not $needsUpgrade) {
            Write-ColorOutput "Lando version is up-to-date (idempotent check passed)" -Type Success
        }
    }

    # Prompt for confirmation if upgrading existing installation
    $proceedWithInstall = $true
    if ($needsUpgrade) {
        Write-ColorOutput "" -Type Info
        Write-ColorOutput "Your current Lando installation will be upgraded to the latest stable version." -Type Warning
        Write-ColorOutput "Current version: $landoVersion" -Type Info
        Write-ColorOutput "" -Type Info
        Write-Host -NoNewline "Do you want to proceed with the upgrade? (Y/N/Exit): "
        $response = Read-Host

        switch ($response.ToUpper()) {
            "Y" {
                Write-ColorOutput "Proceeding with Lando upgrade..." -Type Success
                $proceedWithInstall = $true
            }
            "N" {
                Write-ColorOutput "Skipping Lando upgrade. Continuing with existing version..." -Type Warning
                Write-ColorOutput "Note: Your beta/outdated version may have compatibility issues" -Type Info
                $proceedWithInstall = $false
            }
            "EXIT" {
                Write-ColorOutput "Exiting script as requested." -Type Info
                exit 0
            }
            default {
                Write-ColorOutput "Invalid response. Treating as 'No' - skipping upgrade..." -Type Warning
                $proceedWithInstall = $false
            }
        }
        Write-ColorOutput "" -Type Info
    }

    if ((-not $landoInstalled -or $needsUpgrade) -and $proceedWithInstall) {
        if ($needsUpgrade) {
            Write-ColorOutput "Preparing to upgrade Lando..." -Type Info
        } else {
            Write-ColorOutput "Lando is not installed" -Type Warning
        }

        # Lando official installer URL (no longer on GitHub releases)
        # Latest stable version is downloaded from lando.dev
        $landoUrl = "https://files.lando.dev/installer/lando-x64-stable.exe"
        $installerPath = Join-Path $env:TEMP "lando-installer.exe"

        # Download with retry logic
        $maxRetries = 3
        $retryCount = 0
        $downloadSuccess = $false

        while ($retryCount -lt $maxRetries -and -not $downloadSuccess) {
            try {
                $retryCount++
                if ($retryCount -gt 1) {
                    $waitTime = [Math]::Pow(2, $retryCount - 1)
                    Write-ColorOutput "Retry attempt $retryCount of $maxRetries (waiting ${waitTime}s)..." -Type Info
                    Start-Sleep -Seconds $waitTime
                }

                Write-ColorOutput "Downloading Lando installer... (attempt $retryCount/$maxRetries)" -Type Info

                # Use Invoke-WebRequest with timeout
                $webRequest = Invoke-WebRequest -Uri $landoUrl -OutFile $installerPath -TimeoutSec 300 -UseBasicParsing -ErrorAction Stop

                # Verify file was downloaded
                if (Test-Path $installerPath) {
                    $fileSize = (Get-Item $installerPath).Length
                    if ($fileSize -gt 1MB) {
                        Write-ColorOutput "Lando installer downloaded successfully ($([Math]::Round($fileSize/1MB, 2)) MB)" -Type Success
                        $downloadSuccess = $true
                    } else {
                        Write-ColorOutput "Downloaded file seems incomplete (size: $fileSize bytes)" -Type Warning
                        Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
                        throw "Incomplete download"
                    }
                } else {
                    throw "Download failed - file not found"
                }

            } catch {
                Write-ColorOutput "Download attempt $retryCount failed: $($_.Exception.Message)" -Type Warning
                if ($retryCount -eq $maxRetries) {
                    Write-ColorOutput "All download attempts failed" -Type Error
                    Write-ColorOutput "You can manually download from: $landoUrl" -Type Info
                    Write-ColorOutput "Then run the installer and re-run this script with: .\quickstart.ps1 -SkipLandoInstall" -Type Info
                    if (Test-Path $installerPath) {
                        Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
                    }
                    exit 1
                }
            }
        }

        # Install Lando
        if ($downloadSuccess) {
            try {
                Write-ColorOutput "Installing Lando silently... (this may take a few minutes)" -Type Info

                # Determine installation directory
                if ($LandoInstallPath -ne "") {
                    # User specified custom path
                    $installDir = $LandoInstallPath
                    Write-ColorOutput "Using custom installation path: $installDir" -Type Info

                    # Validate custom path
                    $parentDir = Split-Path $installDir -Parent
                    if (-not (Test-Path $parentDir)) {
                        try {
                            New-Item -ItemType Directory -Path $parentDir -Force -ErrorAction Stop | Out-Null
                            Write-ColorOutput "Created parent directory: $parentDir" -Type Success
                        } catch {
                            Write-ColorOutput "Cannot create directory: $parentDir" -Type Error
                            Write-ColorOutput "Error: $_" -Type Error
                            exit 1
                        }
                    }
                } else {
                    # Use default system-wide installation path (requires admin)
                    $installDir = "C:\Program Files\Lando"
                    Write-ColorOutput "Installing to system directory: $installDir" -Type Info
                }

                # Create installation directory if it doesn't exist
                if (-not (Test-Path $installDir)) {
                    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
                }

                # Run installer with silent flags
                # Common silent install flags for Windows installers:
                # /S = Silent (NSIS)
                # /VERYSILENT = Very Silent (Inno Setup)
                # /NORESTART = Don't restart computer
                # /D= = Installation directory (must be last parameter)

                $installerArgs = @(
                    "/VERYSILENT",
                    "/SUPPRESSMSGBOXES",
                    "/NORESTART",
                    "/SP-",
                    "/NOICONS",
                    "/TASKS=`"desktopicon,addtopath`"",
                    "/DIR=`"$installDir`""
                )

                Write-ColorOutput "Running silent installation..." -Type Info
                $process = Start-Process -FilePath $installerPath -ArgumentList $installerArgs -Wait -PassThru -NoNewWindow

                # Clean up installer
                if (Test-Path $installerPath) {
                    Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
                }

                # Check exit code (0 = success, some installers return other codes for success)
                $exitCode = $process.ExitCode
                Write-ColorOutput "Installer exited with code: $exitCode" -Type Info

                # Common successful exit codes: 0, 1641 (reboot initiated), 3010 (reboot required)
                if ($exitCode -eq 0 -or $exitCode -eq 1641 -or $exitCode -eq 3010 -or $exitCode -eq $null) {
                    Write-ColorOutput "Lando installation completed" -Type Success
                    Write-ColorOutput "Verifying installation and refreshing PATH..." -Type Info

                    # Wait for installation to fully complete
                    Start-Sleep -Seconds 3

                    # Refresh PATH from registry for current session
                    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
                    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
                    $env:Path = "$machinePath;$userPath"

                    # Verify the installation directory
                    if (Test-Path "$installDir\lando.exe") {
                        Write-ColorOutput "Lando executable found at: $installDir" -Type Success

                        # Explicitly add to system PATH if not already there
                        $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
                        if ($machinePath -notlike "*$installDir*") {
                            try {
                                Write-ColorOutput "Adding $installDir to system PATH..." -Type Info
                                [Environment]::SetEnvironmentVariable("Path", "$machinePath;$installDir", "Machine")
                                Write-ColorOutput "Successfully added to system PATH (persists for all users)" -Type Success
                            } catch {
                                Write-ColorOutput "Could not update system PATH: $_" -Type Error
                                Write-ColorOutput "Installation may be incomplete" -Type Warning
                            }
                        } else {
                            Write-ColorOutput "Already in system PATH" -Type Success
                        }

                        # Refresh environment variables for current session
                        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
                        if ($env:Path -notlike "*$installDir*") {
                            $env:Path = "$installDir;$env:Path"
                        }

                        # Mark this session as having refreshed PATH
                        $env:QUICKSTART_PATH_REFRESHED = "true"

                        Write-ColorOutput "PATH updated for THIS PowerShell session" -Type Success
                        Write-ColorOutput "Note: Other open PowerShell windows won't see Lando until reopened" -Type Info

                        # Wait for file system to settle
                        Start-Sleep -Seconds 5

                        # Try multiple verification attempts
                        $verifySuccess = $false
                        $maxAttempts = 3

                        for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
                            try {
                                Write-ColorOutput "Verifying Lando installation (attempt $attempt/$maxAttempts)..." -Type Info

                                # Try running lando directly from the installation path
                                $landoExePath = Join-Path $installDir "lando.exe"
                                $landoVersion = & $landoExePath version 2>&1

                                if ($LASTEXITCODE -eq 0 -and $landoVersion) {
                                    Write-ColorOutput "Lando verified successfully: $landoVersion" -Type Success
                                    Write-ColorOutput "Installation directory: $installDir" -Type Info
                                    $verifySuccess = $true
                                    break
                                } else {
                                    throw "Lando returned exit code: $LASTEXITCODE"
                                }
                            } catch {
                                if ($attempt -lt $maxAttempts) {
                                    Write-ColorOutput "Verification attempt $attempt failed, retrying..." -Type Warning
                                    Start-Sleep -Seconds 3
                                } else {
                                    Write-ColorOutput "Could not verify Lando automatically after $maxAttempts attempts" -Type Warning
                                    Write-ColorOutput "Error: $_" -Type Info
                                }
                            }
                        }

                        if ($verifySuccess) {
                            Write-ColorOutput "Continuing with setup..." -Type Info
                            Write-Host ""
                            # Don't exit - continue with the rest of the script
                        } else {
                            Write-ColorOutput "Lando is installed but automatic verification failed" -Type Warning
                            Write-ColorOutput "" -Type Info
                            Write-ColorOutput "This is usually due to PATH refresh timing. Try one of these:" -Type Info
                            Write-ColorOutput "" -Type Info
                            Write-ColorOutput "Option 1: Continue anyway (if you know Lando works)" -Type Info
                            $continue = Read-Host "  Press 'y' to continue setup, or any other key to exit"

                            if ($continue -eq "y" -or $continue -eq "Y") {
                                Write-ColorOutput "Continuing with setup..." -Type Success
                                Write-Host ""
                                # Continue with script
                            } else {
                                Write-ColorOutput "" -Type Info
                                Write-ColorOutput "Option 2: Manual verification and PATH setup:" -Type Info
                                Write-ColorOutput "  1. Verify installation:" -Type Info
                                Write-ColorOutput "     Test-Path '$installDir\lando.exe'" -Type Info
                                Write-ColorOutput "  2. Add to PATH (run as Administrator):" -Type Info
                                Write-ColorOutput "     `$path = [Environment]::GetEnvironmentVariable('Path', 'Machine')" -Type Info
                                Write-ColorOutput "     [Environment]::SetEnvironmentVariable('Path', `"`$path;$installDir`", 'Machine')" -Type Info
                                Write-ColorOutput "  3. Open a NEW PowerShell window" -Type Info
                                Write-ColorOutput "  4. Run: lando version" -Type Info
                                Write-ColorOutput "  5. If that works, run: .\quickstart.ps1 -SkipLandoInstall" -Type Info
                                exit 0
                            }
                        }
                    } else {
                        Write-ColorOutput "Installation completed but lando.exe not found at expected location" -Type Warning
                        Write-ColorOutput "Expected: $installDir\lando.exe" -Type Info

                        # Check other common locations
                        $foundElsewhere = $false
                        $otherPaths = @(
                            "C:\Program Files\Lando\lando.exe",
                            "${env:LOCALAPPDATA}\Programs\Lando\lando.exe"
                        )

                        foreach ($altPath in $otherPaths) {
                            if (Test-Path $altPath) {
                                $altDir = Split-Path $altPath -Parent
                                Write-ColorOutput "Found Lando at: $altDir" -Type Success
                                if ($env:Path -notlike "*$altDir*") {
                                    $env:Path += ";$altDir"
                                }
                                $foundElsewhere = $true
                                break
                            }
                        }

                        if (-not $foundElsewhere) {
                            Write-ColorOutput "Please restart PowerShell and verify installation manually" -Type Warning
                            Write-ColorOutput "Then run: .\quickstart.ps1 -SkipLandoInstall" -Type Info
                            exit 0
                        }
                    }
                } else {
                    Write-ColorOutput "Installation may have failed (exit code: $exitCode)" -Type Warning
                    Write-ColorOutput "Common exit codes: 0=success, 1641=reboot initiated, 3010=reboot required" -Type Info
                    Write-ColorOutput "Please verify manually with: lando version" -Type Info
                    Write-ColorOutput "If installed, continue with: .\quickstart.ps1 -SkipLandoInstall" -Type Info
                    exit 0
                }

            } catch {
                Write-ColorOutput "Failed to install Lando: $_" -Type Error
                Write-ColorOutput "Please manually install from: https://docs.lando.dev/getting-started/installation.html" -Type Info
                if (Test-Path $installerPath) {
                    Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
                }
                exit 1
            }
        }
    } else {
        # Lando is already installed and up-to-date (message already shown above)
        Write-ColorOutput "Skipping installation..." -Type Info

        # Make sure Lando is in PATH for current session
        if ($landoPath -and $env:Path -notlike "*$landoPath*") {
            Write-ColorOutput "Adding Lando to PATH for current session..." -Type Info
            $env:Path += ";$landoPath"
        }
    }
} else {
    Write-ColorOutput "Skipping Lando installation check (user requested)" -Type Info
}

##############################################################################
# 3. Configure Environment
##############################################################################

Write-ColorOutput "Step 3: Configuring Environment" -Type Header

# Check if .env already exists
if (Test-Path ".env") {
    Write-ColorOutput ".env file already exists" -Type Warning
    $overwrite = Read-Host "Do you want to reconfigure? (y/N)"
    if ($overwrite -ne "y" -and $overwrite -ne "Y") {
        Write-ColorOutput "Keeping existing .env file" -Type Info
    } else {
        Remove-Item ".env" -Force
    }
}

if (-not (Test-Path ".env")) {
    Write-ColorOutput "Creating .env file..." -Type Info

    # Prompt for Pantheon credentials
    Write-Host ""
    Write-Host "Please provide your Pantheon site information:"
    Write-ColorOutput "You can find these in your Pantheon Dashboard" -Type Info
    Write-Host ""

    $pantheonSite = Read-Host "Pantheon Site Name (e.g., my-awesome-site)"

    # Get and validate UUID with retry logic
    $pantheonSiteId = $null
    $maxAttempts = 3
    $attempt = 0

    while ($null -eq $pantheonSiteId -and $attempt -lt $maxAttempts) {
        $attempt++
        Write-Host ""
        Write-ColorOutput "Pantheon Site UUID (Attempt $attempt/$maxAttempts)" -Type Info
        Write-ColorOutput "You can paste the UUID in any of these formats:" -Type Info
        Write-ColorOutput "  - UUID only: <uuid>" -Type Info
        Write-ColorOutput "  - With hash: <uuid>#dev/code" -Type Info
        Write-ColorOutput "  - Full URL: https://dashboard.pantheon.io/sites/<uuid>" -Type Info
        Write-Host ""
        $uuidInput = Read-Host "Pantheon Site UUID"
        $pantheonSiteId = Extract-PantheonUUID -UserInput $uuidInput

        if ($null -eq $pantheonSiteId -and $attempt -lt $maxAttempts) {
            Write-Host ""
            Write-ColorOutput "Please try again" -Type Warning
        }
    }

    if ($null -eq $pantheonSiteId) {
        Write-ColorOutput "Failed to get valid UUID after $maxAttempts attempts" -Type Error
        exit 1
    }

    Write-ColorOutput "Using UUID: $pantheonSiteId" -Type Success
    Write-ColorOutput "This will connect to the DEV environment only" -Type Info
    Write-Host ""

    Write-ColorOutput "Terminus Machine Token" -Type Info
    Write-ColorOutput "Find or create your token at: https://dashboard.pantheon.io/personal-settings/machine-tokens" -Type Info
    Write-Host ""
    $terminusTokenSecure = Read-Host "Terminus Machine Token" -AsSecureString
    $terminusToken = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($terminusTokenSecure))

    # Create .env file
    if (-not (Test-Path ".env.example")) {
        Write-ColorOutput ".env.example not found! Are you in the correct directory?" -Type Error
        exit 1
    }

    Copy-Item ".env.example" ".env" -Force

    # Update .env with user values
    $envContent = Get-Content ".env" -Raw
    $envContent = $envContent -replace 'PANTHEON_SITE=your-site-name', "PANTHEON_SITE=$pantheonSite"
    $envContent = $envContent -replace 'PANTHEON_SITE_ID=your-site-uuid', "PANTHEON_SITE_ID=$pantheonSiteId"
    $envContent = $envContent -replace 'TERMINUS_TOKEN=your-terminus-machine-token', "TERMINUS_TOKEN=$terminusToken"
    $envContent = $envContent -replace 'PANTHEON_SITE_URL=dev-your-site-name.pantheonsite.io', "PANTHEON_SITE_URL=dev-$pantheonSite.pantheonsite.io"

    Set-Content ".env" -Value $envContent -NoNewline

    Write-ColorOutput ".env file created and configured" -Type Success
}

# Create .lando.yml from template if it doesn't exist
if (-not (Test-Path ".lando.yml")) {
    if (Test-Path ".lando.yml.example") {
        Write-ColorOutput "Creating .lando.yml from template..." -Type Info
        Copy-Item ".lando.yml.example" ".lando.yml"
        Write-ColorOutput ".lando.yml created from template" -Type Success
    } else {
        Write-ColorOutput ".lando.yml.example template not found! Are you in the correct directory?" -Type Error
        exit 1
    }
}

# Update .lando.yml with site details
Write-ColorOutput "Updating .lando.yml configuration..." -Type Info
if (Test-Path ".env") {
    # Read PANTHEON_SITE and PANTHEON_SITE_ID from .env
    $envLines = Get-Content ".env"
    $pantheonSite = ($envLines | Where-Object { $_ -match "^PANTHEON_SITE=" }) -replace "PANTHEON_SITE=", ""
    $pantheonSiteId = ($envLines | Where-Object { $_ -match "^PANTHEON_SITE_ID=" }) -replace "PANTHEON_SITE_ID=", ""

    # Update .lando.yml (local file, gitignored)
    $landoContent = Get-Content ".lando.yml" -Raw
    $landoContent = $landoContent -replace 'site: YOUR_PANTHEON_SITE_NAME', "site: $pantheonSite"
    $landoContent = $landoContent -replace 'id: YOUR_PANTHEON_SITE_ID', "id: $pantheonSiteId"
    Set-Content ".lando.yml" -Value $landoContent -NoNewline

    Write-ColorOutput ".lando.yml updated with your site details" -Type Success
}

##############################################################################
# 4. Start Lando
##############################################################################

Write-ColorOutput "Step 4: Starting Lando Environment" -Type Header

# Clean up any partial Composer installations before starting
if ((Test-Path "vendor") -and (-not (Test-Path "vendor/autoload.php"))) {
    Write-ColorOutput "Cleaning up partial Composer installation..." -Type Info
    Remove-Item -Recurse -Force vendor -ErrorAction SilentlyContinue
}

# Stop this project's containers (project-specific, doesn't affect other Lando projects)
Write-ColorOutput "Stopping wordpress-pantheon containers if running..." -Type Info
& lando stop 2>&1 | Out-Null
Start-Sleep -Seconds 2

# Destroy existing wordpress-pantheon project for clean slate (project-specific)
Write-ColorOutput "Destroying existing project containers for clean start..." -Type Info
try {
    # Check if project exists first
    $ErrorActionPreference = 'Continue'
    $projectInfo = & lando info --format json 2>&1 | Out-String
    $ErrorActionPreference = 'Stop'

    if ($projectInfo -match '\[' -and $projectInfo -match 'wordpress-pantheon') {
        # Project exists, destroy it
        $ErrorActionPreference = 'Continue'
        & lando destroy -y 2>&1 | Out-Null
        $ErrorActionPreference = 'Stop'
        Start-Sleep -Seconds 2
        Write-ColorOutput "Existing project destroyed - starting fresh build..." -Type Success
    } else {
        Write-ColorOutput "No existing project found - proceeding with fresh build..." -Type Success
    }
} catch {
    # Destroy command failed or no project exists - both are fine, continue
    Write-ColorOutput "No existing project found - proceeding with fresh build..." -Type Success
}

Write-ColorOutput "Starting Lando... (this may take several minutes on first run)" -Type Info

$landoStarted = $false
$maxAttempts = 3

for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
    # Capture output to check for errors
    $startOutput = ""

    if ($attempt -eq 1) {
        Write-ColorOutput "Starting Lando (attempt $attempt/$maxAttempts)..." -Type Info
        # Capture output while also displaying it
        $ErrorActionPreference = 'Continue'
        $startOutput = & lando start 2>&1 | Tee-Object -Variable tempOutput | Out-String
        $startOutput = $tempOutput -join "`n"
        $ErrorActionPreference = 'Stop'
    } elseif ($attempt -eq 2) {
        Write-ColorOutput "First attempt failed. Destroying and starting fresh (attempt $attempt/$maxAttempts)..." -Type Warning
        # Project-specific stop (doesn't affect other Lando projects)
        & lando stop 2>&1 | Out-Null
        Start-Sleep -Seconds 2
        # Gracefully handle destroy warnings (project-specific)
        $ErrorActionPreference = 'Continue'
        & lando destroy -y 2>&1 | Out-Null
        $ErrorActionPreference = 'Stop'
        Start-Sleep -Seconds 2
        $ErrorActionPreference = 'Continue'
        $startOutput = & lando start 2>&1 | Tee-Object -Variable tempOutput | Out-String
        $startOutput = $tempOutput -join "`n"
        $ErrorActionPreference = 'Stop'
    } else {
        Write-ColorOutput "Second attempt failed. Performing aggressive cleanup (attempt $attempt/$maxAttempts)..." -Type Warning
        # Project-specific stop (doesn't affect other Lando projects)
        & lando stop 2>&1 | Out-Null
        Start-Sleep -Seconds 2
        # Gracefully handle destroy warnings (project-specific, cleans up this project's resources)
        $ErrorActionPreference = 'Continue'
        & lando destroy -y 2>&1 | Out-Null
        $ErrorActionPreference = 'Stop'
        Start-Sleep -Seconds 2
        # Note: Removed 'docker system prune' - too aggressive, affects all Docker projects
        # lando destroy already cleans up this project's containers, networks, and volumes
        $ErrorActionPreference = 'Continue'
        $startOutput = & lando start 2>&1 | Tee-Object -Variable tempOutput | Out-String
        $startOutput = $tempOutput -join "`n"
        $ErrorActionPreference = 'Stop'
    }

    # Check for critical errors in the output
    $hasErrors = $false
    $errorLines = @()

    if ($startOutput) {
        # Extract lines containing errors
        $outputLines = $startOutput -split "`n"
        foreach ($line in $outputLines) {
            if ($line -match "Error response from daemon|manifest.*not found|ERROR ==>|Error$") {
                $errorLines += $line.Trim()
            }
        }

        if ($errorLines.Count -gt 0) {
            Write-ColorOutput "Detected errors in Lando startup output:" -Type Warning
            Write-ColorOutput "" -Type Info
            foreach ($errLine in $errorLines) {
                Write-ColorOutput "  $errLine" -Type Error
            }
            Write-ColorOutput "" -Type Info
            $hasErrors = $true
        }
    }

    # Verify containers are actually running and healthy
    Start-Sleep -Seconds 5
    Write-ColorOutput "Verifying containers are running..." -Type Info

    try {
        $landoInfo = & lando info --format json 2>&1 | Out-String
        $containersHealthy = $false

        if ($LASTEXITCODE -eq 0 -and $landoInfo -match '\[' -and $landoInfo -notmatch '"service":\s*\[\s*\]') {
            # Parse JSON to check for running services
            try {
                $landoData = $landoInfo | ConvertFrom-Json
                if ($landoData -and $landoData.Count -gt 0) {
                    # Check if services exist and are not in error state
                    $serviceCount = 0
                    $serviceStatus = @()

                    foreach ($service in $landoData) {
                        if ($service.service) {
                            $serviceCount++
                            $status = if ($service.healthy -eq $true) { "healthy" } elseif ($service.healthy -eq $false) { "UNHEALTHY" } else { "unknown" }
                            $serviceStatus += "  - $($service.service): $status"
                        }
                    }

                    # Show service status for debugging
                    if ($serviceCount -gt 0) {
                        Write-ColorOutput "Container status:" -Type Info
                        foreach ($status in $serviceStatus) {
                            if ($status -match "UNHEALTHY") {
                                Write-ColorOutput "$status (may be normal before WordPress is installed)" -Type Warning
                            } elseif ($status -match "healthy") {
                                Write-ColorOutput $status -Type Success
                            } else {
                                Write-ColorOutput $status -Type Info
                            }
                        }
                        Write-ColorOutput "" -Type Info
                    }

                    # Containers are healthy if they're RUNNING, even if health checks fail
                    # Health checks may fail before WordPress files/DB are installed - this is expected
                    # Prioritize actual container status over warning messages in output
                    if ($serviceCount -gt 0) {
                        $containersHealthy = $true
                        if ($hasErrors) {
                            Write-ColorOutput "Note: Error messages detected in output, but containers started successfully" -Type Warning
                            Write-ColorOutput "This may indicate image fallbacks or non-critical warnings" -Type Info
                        }
                        Write-ColorOutput "Containers are running (health checks will pass after WordPress setup)" -Type Info
                    }
                }
            } catch {
                Write-ColorOutput "Could not parse lando info JSON: $_" -Type Warning
            }
        } else {
            Write-ColorOutput "No containers detected in lando info output" -Type Warning
        }

        if ($containersHealthy) {
            Write-ColorOutput "Lando started successfully!" -Type Success
            $landoStarted = $true
            break
        } else {
            if ($hasErrors) {
                Write-ColorOutput "Startup completed but with errors - see error details above" -Type Warning
            } else {
                Write-ColorOutput "Containers not running properly" -Type Warning
            }
            if ($attempt -lt $maxAttempts) {
                Write-ColorOutput "Will retry with more aggressive cleanup..." -Type Warning
                Start-Sleep -Seconds 2
            }
        }
    } catch {
        Write-ColorOutput "Verification failed: $_" -Type Warning
        if ($attempt -lt $maxAttempts) {
            Write-ColorOutput "Will retry with more aggressive cleanup..." -Type Warning
            Start-Sleep -Seconds 2
        }
    }
}

if (-not $landoStarted) {
    Write-ColorOutput "Failed to start Lando after $maxAttempts attempts" -Type Error
    Write-ColorOutput "" -Type Info
    Write-ColorOutput "Troubleshooting steps:" -Type Info
    Write-ColorOutput "  1. Check Docker Desktop is running and healthy" -Type Info
    Write-ColorOutput "  2. Restart Docker Desktop completely" -Type Info
    Write-ColorOutput "  3. Try manually: lando stop && lando destroy -y && lando start" -Type Info
    Write-ColorOutput "     (project-specific, won't affect other Lando projects)" -Type Info
    Write-ColorOutput "  4. Check for port conflicts (80, 443, 3306 in use)" -Type Info
    Write-ColorOutput "  5. Check Lando logs: lando logs" -Type Info
    Write-ColorOutput "  6. Update Lando: Visit https://docs.lando.dev/getting-started/installation.html" -Type Info
    Write-ColorOutput "" -Type Info
    Write-ColorOutput "If issues persist, check Docker Desktop logs for errors" -Type Info
    exit 1
}

##############################################################################
# 5. Authenticate with Terminus
##############################################################################

Write-ColorOutput "Step 5: Authenticating with Terminus" -Type Header

# Read token from .env
$envLines = Get-Content ".env"
$terminusToken = ($envLines | Where-Object { $_ -match "^TERMINUS_TOKEN=" }) -replace "TERMINUS_TOKEN=", ""

Write-ColorOutput "Authenticating with Terminus..." -Type Info
try {
    & lando terminus auth:login --machine-token=$terminusToken
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "Terminus authentication successful!" -Type Success

        # Verify authentication
        $whoami = & lando terminus auth:whoami
        Write-ColorOutput "Logged in as: $whoami" -Type Success
    } else {
        throw "Terminus auth failed with exit code $LASTEXITCODE"
    }
} catch {
    Write-ColorOutput "Failed to authenticate with Terminus: $_" -Type Error
    Write-ColorOutput "Please check your machine token and try again" -Type Info
    exit 1
}

##############################################################################
# 6. Pull Data from Pantheon
##############################################################################

Write-ColorOutput "Step 6: Syncing Data from Pantheon" -Type Header

Write-ColorOutput "This will pull the database and files from your Pantheon Dev environment" -Type Info
$pullData = Read-Host "Do you want to pull data now? (Y/n)"

if ($pullData -ne "n" -and $pullData -ne "N") {
    Write-ColorOutput "Pulling database from Pantheon Dev..." -Type Info
    try {
        & lando pull-db
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "Database pulled successfully!" -Type Success
        } else {
            Write-ColorOutput "Failed to pull database. You can try again later with: lando pull-db" -Type Warning
        }
    } catch {
        Write-ColorOutput "Error pulling database: $_" -Type Warning
    }

    Write-ColorOutput "Pulling files from Pantheon Dev..." -Type Info
    try {
        & lando pull-files
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "Files pulled successfully!" -Type Success
        } else {
            Write-ColorOutput "Failed to pull files. You can try again later with: lando pull-files" -Type Warning
        }
    } catch {
        Write-ColorOutput "Error pulling files: $_" -Type Warning
    }
} else {
    Write-ColorOutput "Skipping data sync. You can run 'lando pull' later to sync data" -Type Info
}

##############################################################################
# 7. Complete!
##############################################################################

Write-ColorOutput "Setup Complete!" -Type Header

Write-Host @"

Your WordPress + Pantheon local development environment is ready!

[SITES]
   Site URL:      https://wordpress-pantheon.lndo.site
   Admin URL:     https://wordpress-pantheon.lndo.site/wp-admin
   PhpMyAdmin:    https://pma.wordpress-pantheon.lndo.site

[COMMANDS]
   lando start           - Start the development environment
   lando stop            - Stop the development environment
   lando pull-db         - Pull database from Pantheon Dev
   lando pull-files      - Pull files from Pantheon Dev
   lando wp              - Run WP-CLI commands
   lando terminus        - Run Terminus commands

[DOCUMENTATION]
   README.md             - Full documentation
   SETUP.md              - Detailed setup guide
   SECURITY.md           - Security best practices
   QUICK-REFERENCE.md    - Command reference

"@

# Check if this is a fresh Lando installation and provide window guidance
if ($env:QUICKSTART_PATH_REFRESHED -eq "true") {
    Write-Host ""
    Write-ColorOutput "IMPORTANT: PowerShell Window Sessions" -Type Header
    Write-Host @"

[OK] THIS PowerShell window has refreshed PATH - Lando commands will work here
[INFO] Other PowerShell windows opened BEFORE installation will NOT have Lando in PATH
[INFO] To use Lando in a different window, you must open a NEW PowerShell window

To test in any window, run:
   lando --version

If you get "command not found" in another window:
   1. Close that PowerShell window
   2. Open a NEW PowerShell window
   3. Run: lando --version (should work now)

QUICK FIX for old windows (run in any window to refresh PATH):
   `$env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")
   lando --version

"@
}

Write-ColorOutput "Setup completed successfully!" -Type Success
