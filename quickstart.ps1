##############################################################################
# WordPress + Pantheon Quickstart Setup Script (Windows)
# This script automates the installation and configuration process
##############################################################################

param(
    [switch]$SkipLandoInstall,
    [switch]$Help
)

# Colors for output
function Write-Success { param($Message) Write-Host "✓ $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "ℹ $Message" -ForegroundColor Cyan }
function Write-Warning { param($Message) Write-Host "⚠ $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "✗ $Message" -ForegroundColor Red }
function Write-Header { param($Message) Write-Host "`n========================================" -ForegroundColor Magenta; Write-Host $Message -ForegroundColor Magenta; Write-Host "========================================`n" -ForegroundColor Magenta }

if ($Help) {
    Write-Host @"
WordPress + Pantheon Quickstart Setup

Usage: .\quickstart.ps1 [options]

Options:
  -SkipLandoInstall    Skip Lando installation check/install
  -Help                Show this help message

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
  - Administrator privileges (for installations)
  - Internet connection
  - Pantheon account with machine token

"@
    exit 0
}

Write-Header "WordPress + Pantheon Quickstart Setup"

##############################################################################
# 1. Check Prerequisites
##############################################################################

Write-Header "Step 1: Checking Prerequisites"

# Check if running as administrator for installations
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Not running as Administrator. May need elevated privileges for installations."
    Write-Info "If installations fail, re-run as Administrator"
}

# Check Git
Write-Info "Checking for Git..."
$gitInstalled = Get-Command git -ErrorAction SilentlyContinue
if ($gitInstalled) {
    $gitVersion = git --version
    Write-Success "Git is installed: $gitVersion"
} else {
    Write-Error "Git is not installed!"
    Write-Info "Please install Git from: https://git-scm.com/download/win"
    Write-Info "After installing Git, re-run this script."
    exit 1
}

# Check Docker Desktop
Write-Info "Checking for Docker Desktop..."
$dockerInstalled = Get-Command docker -ErrorAction SilentlyContinue
if ($dockerInstalled) {
    try {
        $dockerVersion = docker --version
        Write-Success "Docker is installed: $dockerVersion"

        # Check if Docker is running
        docker ps > $null 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Docker is running"
        } else {
            Write-Warning "Docker is installed but not running"
            Write-Info "Please start Docker Desktop and wait for it to be ready"
            Write-Host "Press any key when Docker Desktop is running..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    } catch {
        Write-Warning "Docker might not be running properly"
    }
} else {
    Write-Error "Docker Desktop is not installed!"
    Write-Info "Please install Docker Desktop from: https://www.docker.com/products/docker-desktop"
    Write-Info "After installing Docker Desktop, re-run this script."
    exit 1
}

##############################################################################
# 2. Install Lando
##############################################################################

if (-not $SkipLandoInstall) {
    Write-Header "Step 2: Checking/Installing Lando"

    $landoInstalled = Get-Command lando -ErrorAction SilentlyContinue
    if ($landoInstalled) {
        $landoVersion = lando version
        Write-Success "Lando is already installed: $landoVersion"
    } else {
        Write-Warning "Lando is not installed"
        Write-Info "Downloading Lando installer..."

        $landoUrl = "https://github.com/lando/lando/releases/download/v3.21.0/lando-x64-v3.21.0.exe"
        $installerPath = "$env:TEMP\lando-installer.exe"

        try {
            Invoke-WebRequest -Uri $landoUrl -OutFile $installerPath
            Write-Success "Lando installer downloaded"

            Write-Info "Installing Lando... (this may take a few minutes)"
            Write-Warning "Please follow the installer prompts"

            Start-Process -FilePath $installerPath -Wait

            Write-Success "Lando installation complete"
            Write-Warning "You may need to restart your terminal/PowerShell for Lando to be available"
            Write-Info "After restarting, run this script again to continue setup"

            Remove-Item $installerPath -ErrorAction SilentlyContinue
            exit 0
        } catch {
            Write-Error "Failed to download or install Lando"
            Write-Info "Please manually install from: https://docs.lando.dev/getting-started/installation.html"
            exit 1
        }
    }
} else {
    Write-Info "Skipping Lando installation check"
}

##############################################################################
# 3. Configure Environment
##############################################################################

Write-Header "Step 3: Configuring Environment"

# Check if .env already exists
if (Test-Path ".env") {
    Write-Warning ".env file already exists"
    $overwrite = Read-Host "Do you want to reconfigure? (y/N)"
    if ($overwrite -ne "y" -and $overwrite -ne "Y") {
        Write-Info "Keeping existing .env file"
    } else {
        Remove-Item ".env"
    }
}

if (-not (Test-Path ".env")) {
    Write-Info "Creating .env file..."

    # Prompt for Pantheon credentials
    Write-Host "`nPlease provide your Pantheon site information:"
    Write-Info "You can find these in your Pantheon Dashboard"
    Write-Host ""

    $pantheonSite = Read-Host "Pantheon Site Name (e.g., my-awesome-site)"
    $pantheonSiteId = Read-Host "Pantheon Site UUID (from Settings → About)"
    $terminusToken = Read-Host "Terminus Machine Token (from Account → Machine Tokens)" -AsSecureString
    $terminusTokenPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($terminusToken))

    # Create .env file
    Copy-Item ".env.example" ".env"

    # Update .env with user values
    (Get-Content ".env") | ForEach-Object {
        $_ -replace 'PANTHEON_SITE=your-site-name', "PANTHEON_SITE=$pantheonSite" `
           -replace 'PANTHEON_SITE_ID=your-site-uuid', "PANTHEON_SITE_ID=$pantheonSiteId" `
           -replace 'TERMINUS_TOKEN=your-terminus-machine-token', "TERMINUS_TOKEN=$terminusTokenPlain" `
           -replace 'PANTHEON_SITE_URL=dev-your-site-name.pantheonsite.io', "PANTHEON_SITE_URL=dev-$pantheonSite.pantheonsite.io"
    } | Set-Content ".env"

    Write-Success ".env file created and configured"
}

# Update .lando.yml with site details
Write-Info "Updating .lando.yml configuration..."
if (Test-Path ".env") {
    # Read PANTHEON_SITE and PANTHEON_SITE_ID from .env
    $envContent = Get-Content ".env"
    $pantheonSite = ($envContent | Select-String "PANTHEON_SITE=" | ForEach-Object { $_.ToString().Split("=")[1] })
    $pantheonSiteId = ($envContent | Select-String "PANTHEON_SITE_ID=" | ForEach-Object { $_.ToString().Split("=")[1] })

    # Update .lando.yml
    (Get-Content ".lando.yml") | ForEach-Object {
        $_ -replace 'site: YOUR_PANTHEON_SITE_NAME', "site: $pantheonSite" `
           -replace 'id: YOUR_PANTHEON_SITE_ID', "id: $pantheonSiteId"
    } | Set-Content ".lando.yml"

    Write-Success ".lando.yml updated with your site details"
}

##############################################################################
# 4. Start Lando
##############################################################################

Write-Header "Step 4: Starting Lando Environment"

Write-Info "Starting Lando... (this may take several minutes on first run)"
lando start

if ($LASTEXITCODE -eq 0) {
    Write-Success "Lando started successfully!"
} else {
    Write-Error "Failed to start Lando"
    Write-Info "Check the error messages above and try running 'lando start' manually"
    exit 1
}

##############################################################################
# 5. Authenticate with Terminus
##############################################################################

Write-Header "Step 5: Authenticating with Terminus"

# Read token from .env
$envContent = Get-Content ".env"
$terminusToken = ($envContent | Select-String "TERMINUS_TOKEN=" | ForEach-Object { $_.ToString().Split("=")[1] })

Write-Info "Authenticating with Terminus..."
lando terminus auth:login --machine-token=$terminusToken

if ($LASTEXITCODE -eq 0) {
    Write-Success "Terminus authentication successful!"

    # Verify authentication
    $whoami = lando terminus auth:whoami
    Write-Success "Logged in as: $whoami"
} else {
    Write-Error "Failed to authenticate with Terminus"
    Write-Info "Please check your machine token and try again"
    exit 1
}

##############################################################################
# 6. Pull Data from Pantheon
##############################################################################

Write-Header "Step 6: Syncing Data from Pantheon"

Write-Info "This will pull the database and files from your Pantheon Dev environment"
$pullData = Read-Host "Do you want to pull data now? (Y/n)"

if ($pullData -ne "n" -and $pullData -ne "N") {
    Write-Info "Pulling database from Pantheon Dev..."
    lando pull-db

    if ($LASTEXITCODE -eq 0) {
        Write-Success "Database pulled successfully!"
    } else {
        Write-Warning "Failed to pull database. You can try again later with: lando pull-db"
    }

    Write-Info "Pulling files from Pantheon Dev..."
    lando pull-files

    if ($LASTEXITCODE -eq 0) {
        Write-Success "Files pulled successfully!"
    } else {
        Write-Warning "Failed to pull files. You can try again later with: lando pull-files"
    }
} else {
    Write-Info "Skipping data sync. You can run 'lando pull' later to sync data"
}

##############################################################################
# 7. Complete!
##############################################################################

Write-Header "Setup Complete!"

Write-Host @"

Your WordPress + Pantheon local development environment is ready!

🌐 Access your site:
   Site URL:      https://wordpress-pantheon.lndo.site
   Admin URL:     https://wordpress-pantheon.lndo.site/wp-admin
   PhpMyAdmin:    https://pma.wordpress-pantheon.lndo.site

📚 Useful Commands:
   lando start           - Start the development environment
   lando stop            - Stop the development environment
   lando pull-db         - Pull database from Pantheon Dev
   lando pull-files      - Pull files from Pantheon Dev
   lando wp              - Run WP-CLI commands
   lando terminus        - Run Terminus commands

   Or use the Makefile shortcuts:
   make start            - Start Lando
   make pull             - Pull database and files
   make site             - Open site in browser
   make help             - Show all available commands

📖 Documentation:
   README.md             - Full documentation
   SETUP.md              - Detailed setup guide
   SECURITY.md           - Security best practices
   QUICK-REFERENCE.md    - Command reference

🎉 Happy coding!

"@

Write-Success "Setup completed successfully!"
