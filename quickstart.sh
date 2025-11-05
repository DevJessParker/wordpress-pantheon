#!/usr/bin/env bash

##############################################################################
# WordPress + Pantheon Quickstart Setup Script (macOS/Linux)
# This script automates the installation and configuration process
# Requires: Bash 4.0 or higher
##############################################################################

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Check Bash version
BASH_MAJOR_VERSION="${BASH_VERSINFO[0]}"
if [ "$BASH_MAJOR_VERSION" -lt 4 ]; then
    echo "[ERROR] Bash 4.0 or higher is required. You have Bash $BASH_VERSION"
    echo "[INFO] Please upgrade Bash and try again"
    exit 1
fi

# Colors for output (with fallback for terminals that don't support colors)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    MAGENTA='\033[0;35m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    CYAN=''
    MAGENTA=''
    NC=''
fi

# Helper functions
print_success() { echo -e "${GREEN}[OK] $1${NC}"; }
print_info() { echo -e "${CYAN}[INFO] $1${NC}"; }
print_warning() { echo -e "${YELLOW}[WARN] $1${NC}"; }
print_error() { echo -e "${RED}[ERROR] $1${NC}"; }
print_header() {
    echo ""
    echo -e "${MAGENTA}========================================${NC}"
    echo -e "${MAGENTA}$1${NC}"
    echo -e "${MAGENTA}========================================${NC}"
    echo ""
}

# Parse arguments
SKIP_LANDO_INSTALL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-lando-install)
            SKIP_LANDO_INSTALL=true
            shift
            ;;
        --help|-h)
            cat <<EOF
WordPress + Pantheon Quickstart Setup

Usage: ./quickstart.sh [options]

Options:
  --skip-lando-install    Skip Lando installation check/install
  --help, -h              Show this help message

This script will:
  1. Check for prerequisites (Git, Docker)
  2. Install Lando (if not present)
  3. Configure environment variables
  4. Set up Lando configuration
  5. Authenticate with Terminus
  6. Start the development environment
  7. Pull database and files from Pantheon

Requirements:
  - macOS 10.13+ or Linux (Ubuntu 18.04+, Debian 9+, CentOS 7+)
  - Bash 4.0 or higher
  - Git installed
  - Docker Desktop installed and running
  - Internet connection
  - Pantheon account with machine token

EOF
            exit 0
            ;;
        *)
            echo "[ERROR] Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

print_header "WordPress + Pantheon Quickstart Setup"

##############################################################################
# 1. Check Prerequisites
##############################################################################

print_header "Step 1: Checking Prerequisites"

# Detect OS
OS="unknown"
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    OS_VERSION=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
    print_info "Detected: macOS $OS_VERSION"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        print_info "Detected: $PRETTY_NAME"
    else
        print_info "Detected: Linux (unknown distribution)"
    fi
else
    print_error "Unsupported operating system: $OSTYPE"
    print_info "This script supports macOS and Linux only"
    exit 1
fi

# Check Git
print_info "Checking for Git..."
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version 2>&1 || echo "unknown")
    print_success "Git is installed: $GIT_VERSION"
else
    print_error "Git is not installed!"
    if [ "$OS" = "macos" ]; then
        print_info "Install with: xcode-select --install"
        print_info "Or with Homebrew: brew install git"
    else
        if command -v apt-get &> /dev/null; then
            print_info "Install with: sudo apt-get update && sudo apt-get install git"
        elif command -v yum &> /dev/null; then
            print_info "Install with: sudo yum install git"
        elif command -v dnf &> /dev/null; then
            print_info "Install with: sudo dnf install git"
        else
            print_info "Please install Git using your system's package manager"
        fi
    fi
    exit 1
fi

# Check Docker
print_info "Checking for Docker..."
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version 2>&1 || echo "unknown")
    print_success "Docker is installed: $DOCKER_VERSION"

    # Check if Docker is running
    if docker ps &> /dev/null; then
        print_success "Docker is running"
    else
        print_warning "Docker is installed but not running"
        print_info "Please start Docker Desktop and wait for it to be ready"
        echo -n "Press Enter when Docker Desktop is running..."
        read -r
    fi
else
    print_error "Docker is not installed!"
    print_info "Please install Docker Desktop from: https://www.docker.com/products/docker-desktop"
    exit 1
fi

##############################################################################
# 2. Install Lando
##############################################################################

if [ "$SKIP_LANDO_INSTALL" = false ]; then
    print_header "Step 2: Checking/Installing Lando"

    if command -v lando &> /dev/null; then
        LANDO_VERSION=$(lando version 2>&1 || echo "unknown")
        print_success "Lando is already installed: $LANDO_VERSION"
    else
        print_warning "Lando is not installed"
        print_info "Installing Lando..."

        LANDO_VERSION="3.21.0"

        if [ "$OS" = "macos" ]; then
            # macOS installation
            if command -v brew &> /dev/null; then
                print_info "Installing via Homebrew..."
                brew install --cask lando || {
                    print_error "Failed to install Lando via Homebrew"
                    print_info "Please install manually from: https://docs.lando.dev/getting-started/installation.html"
                    exit 1
                }
                print_success "Lando installed successfully via Homebrew"
            else
                print_info "Homebrew not found. Downloading Lando installer..."
                LANDO_URL="https://github.com/lando/lando/releases/download/v${LANDO_VERSION}/lando-x64-v${LANDO_VERSION}.dmg"
                INSTALLER_PATH="/tmp/lando.dmg"

                curl -fsSL -o "$INSTALLER_PATH" "$LANDO_URL" || {
                    print_error "Failed to download Lando installer"
                    print_info "Please install manually from: https://docs.lando.dev/getting-started/installation.html"
                    exit 1
                }

                print_info "Mounting installer..."
                hdiutil attach "$INSTALLER_PATH" -nobrowse -quiet

                print_info "Installing Lando (requires sudo)..."
                sudo cp -R /Volumes/Lando/Lando.app /Applications/ || {
                    print_error "Failed to install Lando"
                    hdiutil detach /Volumes/Lando -quiet 2>/dev/null || true
                    rm -f "$INSTALLER_PATH"
                    exit 1
                }

                print_info "Cleaning up..."
                hdiutil detach /Volumes/Lando -quiet || true
                rm -f "$INSTALLER_PATH"

                # Add to PATH for current session
                export PATH="/Applications/Lando.app/Contents/Resources:$PATH"

                # Add to shell profile
                for PROFILE in "$HOME/.bash_profile" "$HOME/.zshrc" "$HOME/.bashrc"; do
                    if [ -f "$PROFILE" ]; then
                        if ! grep -q "Lando.app/Contents/Resources" "$PROFILE" 2>/dev/null; then
                            echo 'export PATH="/Applications/Lando.app/Contents/Resources:$PATH"' >> "$PROFILE"
                        fi
                    fi
                done

                print_success "Lando installed successfully"
                print_warning "You may need to restart your terminal for PATH changes to take effect"
            fi
        else
            # Linux installation
            print_info "Downloading Lando installer..."

            if command -v dpkg &> /dev/null; then
                # Debian/Ubuntu
                LANDO_URL="https://github.com/lando/lando/releases/download/v${LANDO_VERSION}/lando-x64-v${LANDO_VERSION}.deb"
                INSTALLER_PATH="/tmp/lando.deb"

                curl -fsSL -o "$INSTALLER_PATH" "$LANDO_URL" || {
                    print_error "Failed to download Lando installer"
                    print_info "Please install manually from: https://docs.lando.dev/getting-started/installation.html"
                    exit 1
                }

                print_info "Installing Lando (requires sudo)..."
                sudo dpkg -i "$INSTALLER_PATH" || {
                    print_error "Failed to install Lando"
                    rm -f "$INSTALLER_PATH"
                    exit 1
                }

                rm -f "$INSTALLER_PATH"
                print_success "Lando installed successfully"

            elif command -v rpm &> /dev/null; then
                # Red Hat/CentOS/Fedora
                LANDO_URL="https://github.com/lando/lando/releases/download/v${LANDO_VERSION}/lando-x64-v${LANDO_VERSION}.rpm"
                INSTALLER_PATH="/tmp/lando.rpm"

                curl -fsSL -o "$INSTALLER_PATH" "$LANDO_URL" || {
                    print_error "Failed to download Lando installer"
                    print_info "Please install manually from: https://docs.lando.dev/getting-started/installation.html"
                    exit 1
                }

                print_info "Installing Lando (requires sudo)..."
                sudo rpm -i "$INSTALLER_PATH" || {
                    print_error "Failed to install Lando"
                    rm -f "$INSTALLER_PATH"
                    exit 1
                }

                rm -f "$INSTALLER_PATH"
                print_success "Lando installed successfully"
            else
                print_error "Unsupported Linux distribution for automatic installation"
                print_info "Please install manually from: https://docs.lando.dev/getting-started/installation.html"
                exit 1
            fi
        fi

        # Verify installation
        if command -v lando &> /dev/null; then
            LANDO_VERSION=$(lando version 2>&1)
            print_success "Lando is now available: $LANDO_VERSION"
        else
            print_warning "Lando was installed but is not in PATH"
            print_info "Please restart your terminal and run this script again"
            exit 0
        fi
    fi
else
    print_info "Skipping Lando installation check"
fi

##############################################################################
# 3. Configure Environment
##############################################################################

print_header "Step 3: Configuring Environment"

# Check if .env already exists
if [ -f ".env" ]; then
    print_warning ".env file already exists"
    read -rp "Do you want to reconfigure? (y/N): " OVERWRITE
    if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
        print_info "Keeping existing .env file"
    else
        rm -f .env
    fi
fi

if [ ! -f ".env" ]; then
    print_info "Creating .env file..."

    # Check for .env.example
    if [ ! -f ".env.example" ]; then
        print_error ".env.example not found! Are you in the correct directory?"
        exit 1
    fi

    # Prompt for Pantheon credentials
    echo ""
    echo "Please provide your Pantheon site information:"
    print_info "You can find these in your Pantheon Dashboard"
    echo ""

    read -rp "Pantheon Site Name (e.g., my-awesome-site): " PANTHEON_SITE
    read -rp "Pantheon Site UUID (from Settings -> About): " PANTHEON_SITE_ID
    read -rsp "Terminus Machine Token (from Account -> Machine Tokens): " TERMINUS_TOKEN
    echo ""

    # Validate inputs
    if [ -z "$PANTHEON_SITE" ] || [ -z "$PANTHEON_SITE_ID" ] || [ -z "$TERMINUS_TOKEN" ]; then
        print_error "All fields are required!"
        exit 1
    fi

    # Create .env file from template
    cp .env.example .env

    # Update .env with user values (compatible with both macOS and Linux sed)
    if [[ "$OS" == "macos" ]]; then
        # macOS sed requires empty string after -i
        sed -i '' "s|PANTHEON_SITE=your-site-name|PANTHEON_SITE=$PANTHEON_SITE|" .env
        sed -i '' "s|PANTHEON_SITE_ID=your-site-uuid|PANTHEON_SITE_ID=$PANTHEON_SITE_ID|" .env
        sed -i '' "s|TERMINUS_TOKEN=your-terminus-machine-token|TERMINUS_TOKEN=$TERMINUS_TOKEN|" .env
        sed -i '' "s|PANTHEON_SITE_URL=dev-your-site-name.pantheonsite.io|PANTHEON_SITE_URL=dev-$PANTHEON_SITE.pantheonsite.io|" .env
    else
        # Linux sed
        sed -i "s|PANTHEON_SITE=your-site-name|PANTHEON_SITE=$PANTHEON_SITE|" .env
        sed -i "s|PANTHEON_SITE_ID=your-site-uuid|PANTHEON_SITE_ID=$PANTHEON_SITE_ID|" .env
        sed -i "s|TERMINUS_TOKEN=your-terminus-machine-token|TERMINUS_TOKEN=$TERMINUS_TOKEN|" .env
        sed -i "s|PANTHEON_SITE_URL=dev-your-site-name.pantheonsite.io|PANTHEON_SITE_URL=dev-$PANTHEON_SITE.pantheonsite.io|" .env
    fi

    print_success ".env file created and configured"
fi

# Update .lando.yml with site details
print_info "Updating .lando.yml configuration..."
if [ -f ".env" ]; then
    # Check for .lando.yml
    if [ ! -f ".lando.yml" ]; then
        print_error ".lando.yml not found! Are you in the correct directory?"
        exit 1
    fi

    # Source .env to get variables
    # shellcheck disable=SC1091
    set -a
    source .env
    set +a

    # Update .lando.yml
    if [[ "$OS" == "macos" ]]; then
        sed -i '' "s|site: YOUR_PANTHEON_SITE_NAME|site: $PANTHEON_SITE|" .lando.yml
        sed -i '' "s|id: YOUR_PANTHEON_SITE_ID|id: $PANTHEON_SITE_ID|" .lando.yml
    else
        sed -i "s|site: YOUR_PANTHEON_SITE_NAME|site: $PANTHEON_SITE|" .lando.yml
        sed -i "s|id: YOUR_PANTHEON_SITE_ID|id: $PANTHEON_SITE_ID|" .lando.yml
    fi

    print_success ".lando.yml updated with your site details"
fi

##############################################################################
# 4. Start Lando
##############################################################################

print_header "Step 4: Starting Lando Environment"

print_info "Starting Lando... (this may take several minutes on first run)"
if lando start; then
    print_success "Lando started successfully!"
else
    print_error "Failed to start Lando"
    print_info "Check the error messages above and try running 'lando start' manually"
    exit 1
fi

##############################################################################
# 5. Authenticate with Terminus
##############################################################################

print_header "Step 5: Authenticating with Terminus"

# Read token from .env
# shellcheck disable=SC1091
set -a
source .env
set +a

print_info "Authenticating with Terminus..."
if lando terminus auth:login --machine-token="$TERMINUS_TOKEN"; then
    print_success "Terminus authentication successful!"

    # Verify authentication
    WHOAMI=$(lando terminus auth:whoami 2>/dev/null || echo "unknown")
    print_success "Logged in as: $WHOAMI"
else
    print_error "Failed to authenticate with Terminus"
    print_info "Please check your machine token and try again"
    exit 1
fi

##############################################################################
# 6. Pull Data from Pantheon
##############################################################################

print_header "Step 6: Syncing Data from Pantheon"

print_info "This will pull the database and files from your Pantheon Dev environment"
read -rp "Do you want to pull data now? (Y/n): " PULL_DATA

if [[ ! "$PULL_DATA" =~ ^[Nn]$ ]]; then
    print_info "Pulling database from Pantheon Dev..."
    if lando pull-db; then
        print_success "Database pulled successfully!"
    else
        print_warning "Failed to pull database. You can try again later with: lando pull-db"
    fi

    print_info "Pulling files from Pantheon Dev..."
    if lando pull-files; then
        print_success "Files pulled successfully!"
    else
        print_warning "Failed to pull files. You can try again later with: lando pull-files"
    fi
else
    print_info "Skipping data sync. You can run 'lando pull' later to sync data"
fi

##############################################################################
# 7. Complete!
##############################################################################

print_header "Setup Complete!"

cat <<EOF

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

EOF

print_success "Setup completed successfully!"
