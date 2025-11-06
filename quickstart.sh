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

# Helper function to get SHA256 hash of a file
get_file_hash() {
    local file_path="$1"

    if [ ! -f "$file_path" ]; then
        echo ""
        return 1
    fi

    # Try different hash commands based on availability
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file_path" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file_path" | awk '{print $1}'
    else
        echo ""
        return 1
    fi
}

# Helper function to read build info
get_lando_build_info() {
    local build_info_path=".lando-build-info"

    if [ ! -f "$build_info_path" ]; then
        echo ""
        return 1
    fi

    cat "$build_info_path"
}

# Helper function to write build info
set_lando_build_info() {
    local lando_yml_hash="$1"
    local container_state="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    cat > .lando-build-info <<EOF
{
  "lastBuildTime": "$timestamp",
  "landoYmlHash": "$lando_yml_hash",
  "lastSuccessfulStart": "$timestamp",
  "containerState": "$container_state"
}
EOF
}

# Helper function to check container state
test_container_state() {
    local lando_info=$(lando info --format json 2>/dev/null || echo "")

    # Check if lando info returned valid JSON with services
    if echo "$lando_info" | grep -q '\[' && ! echo "$lando_info" | grep -q '"service":\s*\[\s*\]'; then
        # Containers exist, check if running
        local container_list=$(lando list --format json 2>/dev/null || echo "")

        if echo "$container_list" | grep -q 'wordpress-pantheon' && echo "$container_list" | grep -q '"running"\s*:\s*"true"'; then
            echo "running"
        else
            echo "stopped"
        fi
    else
        echo "missing"
    fi
}

# Function to extract UUID from various input formats
extract_pantheon_uuid() {
    local input="$1"

    # Remove whitespace
    input=$(echo "$input" | xargs)

    # UUID regex pattern (8-4-4-4-12 format)
    local uuid_pattern='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'

    # Extract UUID from input
    if [[ $input =~ $uuid_pattern ]]; then
        local uuid="${BASH_REMATCH[0]}"

        # Check if input contains environment references
        if [[ $input =~ \#(test|live) ]] || [[ $input =~ /(test|live) ]]; then
            print_warning "WARNING: This tool only works with DEV environment"
            print_warning "Test and Live environments are not supported for local development"
            print_info "The UUID will be used with the dev environment only"
        fi

        # Return UUID in lowercase
        echo "${uuid,,}"
        return 0
    else
        print_error "Invalid UUID format"
        print_info "Expected format: <uuid>"
        echo ""
        print_info "You can paste:"
        print_info "  - Just the UUID: <uuid>"
        print_info "  - With fragment: <uuid>#dev/code"
        print_info "  - Full URL: https://dashboard.pantheon.io/sites/<uuid>"
        return 1
    fi
}

# Parse arguments
SKIP_LANDO_INSTALL=false
LANDO_INSTALL_PATH=""
FORCE_REBUILD=false
QUICK_START=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-lando-install)
            SKIP_LANDO_INSTALL=true
            shift
            ;;
        --lando-install-path)
            LANDO_INSTALL_PATH="$2"
            shift 2
            ;;
        --force)
            FORCE_REBUILD=true
            shift
            ;;
        --quick-start)
            QUICK_START=true
            shift
            ;;
        --help|-h)
            cat <<EOF
WordPress + Pantheon Quickstart Setup

Usage: sudo ./quickstart.sh [options]

IMPORTANT: This script MUST be run with sudo (root privileges)

Options:
  --skip-lando-install           Skip Lando installation check/install
  --lando-install-path <path>    Custom installation path for Lando
                                 Default (macOS): /usr/local/bin
                                 Default (Linux): /usr/local/bin
  --force                        Force full rebuild (destroy existing containers)
  --quick-start                  Skip container rebuild if possible (fastest startup)
  --help, -h                     Show this help message

Container Orchestration:
  By default, the script intelligently detects if containers need to be rebuilt:
  - First run: Full build (3-5 minutes)
  - Config unchanged + containers exist: Fast restart (30 seconds)
  - Config changed: Full rebuild

  Use --force to always do a full rebuild (useful if containers are corrupted)
  Use --quick-start to skip rebuild checks entirely (fastest, assumes healthy containers)

Examples:
  sudo ./quickstart.sh
  sudo ./quickstart.sh --lando-install-path "/opt/lando"
  sudo ./quickstart.sh --skip-lando-install
  sudo ./quickstart.sh --force
  sudo ./quickstart.sh --quick-start

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
  - Root privileges (sudo) - REQUIRED
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
# 0. Check for root/sudo privileges
##############################################################################

# Check if running with sudo or as root (REQUIRED)
if [ "$EUID" -ne 0 ]; then
    print_error "This script requires root privileges (sudo)"
    echo ""
    print_info "Please run the script with sudo:"
    echo ""
    print_info "  sudo ./quickstart.sh"
    echo ""
    print_info "Or if you want to use specific options:"
    print_info "  sudo ./quickstart.sh --lando-install-path /custom/path"
    echo ""
    echo "Press any key to exit..."
    read -n 1 -s
    exit 1
fi

print_success "Running with root privileges"

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

    # Check if Docker is running (with timeout)
    print_info "Checking if Docker is running..."
    if timeout 10 docker ps &> /dev/null; then
        print_success "Docker is running"
    else
        print_warning "Docker is installed but not running"
        print_info "Please start Docker Desktop and wait for it to be ready (this may take 1-2 minutes)"
        echo ""
        echo -n "Press Enter when Docker Desktop is running..."
        read -r
        echo ""

        # Verify Docker is now running
        if timeout 10 docker ps &> /dev/null; then
            print_success "Docker is now running"
        else
            print_error "Docker is still not running. Please ensure Docker Desktop is fully started."
            print_info "Look for the Docker whale icon in your system tray. It should say 'Docker Desktop is running'"
            exit 1
        fi
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

    LANDO_INSTALLED=false
    NEEDS_UPGRADE=false

    if command -v lando &> /dev/null; then
        LANDO_VERSION=$(lando version 2>&1 || echo "unknown")
        LANDO_INSTALLED=true
        print_success "Lando is already installed: $LANDO_VERSION"

        # Check if it's a beta version
        if echo "$LANDO_VERSION" | grep -q "beta"; then
            print_warning "Beta version detected - upgrading to stable release"
            NEEDS_UPGRADE=true
        # Check if it's a very old version (pre-v3.20)
        elif echo "$LANDO_VERSION" | grep -Eq 'v([0-9]+)\.([0-9]+)\.([0-9]+)'; then
            MAJOR=$(echo "$LANDO_VERSION" | sed -E 's/v([0-9]+)\..*/\1/')
            MINOR=$(echo "$LANDO_VERSION" | sed -E 's/v[0-9]+\.([0-9]+)\..*/\1/')

            if [ "$MAJOR" -lt 3 ] || { [ "$MAJOR" -eq 3 ] && [ "$MINOR" -lt 20 ]; }; then
                print_warning "Outdated version detected - upgrading to latest stable"
                NEEDS_UPGRADE=true
            fi
        fi

        if [ "$NEEDS_UPGRADE" = false ]; then
            print_success "Lando version is up-to-date (idempotent check passed)"
            print_info "Skipping installation..."
        fi
    fi

    # Prompt for confirmation if upgrading existing installation
    PROCEED_WITH_INSTALL=true
    if [ "$NEEDS_UPGRADE" = true ]; then
        echo ""
        print_warning "Your current Lando installation will be upgraded to the latest stable version."
        print_info "Current version: $LANDO_VERSION"
        echo ""
        echo -n "Do you want to proceed with the upgrade? (Y/N/Exit): "
        read -r RESPONSE
        # Convert to uppercase for case-insensitive comparison
        RESPONSE=$(echo "$RESPONSE" | tr '[:lower:]' '[:upper:]')

        case "$RESPONSE" in
            Y|YES)
                print_success "Proceeding with Lando upgrade..."
                PROCEED_WITH_INSTALL=true
                ;;
            N|NO)
                print_warning "Skipping Lando upgrade. Continuing with existing version..."
                print_info "Note: Your beta/outdated version may have compatibility issues"
                PROCEED_WITH_INSTALL=false
                ;;
            EXIT|E)
                print_info "Exiting script as requested."
                exit 0
                ;;
            *)
                print_warning "Invalid response. Treating as 'No' - skipping upgrade..."
                PROCEED_WITH_INSTALL=false
                ;;
        esac
        echo ""
    fi

    if { [ "$LANDO_INSTALLED" = false ] || [ "$NEEDS_UPGRADE" = true ]; } && [ "$PROCEED_WITH_INSTALL" = true ]; then
        if [ "$NEEDS_UPGRADE" = true ]; then
            print_info "Preparing to upgrade Lando..."
        else
            print_warning "Lando is not installed"
            print_info "Installing Lando..."
        fi

        # Lando official installer URLs (no longer on GitHub releases)
        # Latest stable versions are downloaded from lando.dev

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
                LANDO_URL="https://files.lando.dev/installer/lando-x64-stable.dmg"
                INSTALLER_PATH="/tmp/lando.dmg"

                # Download with retry logic
                MAX_RETRIES=3
                RETRY_COUNT=0
                DOWNLOAD_SUCCESS=false

                while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ "$DOWNLOAD_SUCCESS" = false ]; do
                    RETRY_COUNT=$((RETRY_COUNT + 1))

                    if [ $RETRY_COUNT -gt 1 ]; then
                        WAIT_TIME=$((2 ** (RETRY_COUNT - 1)))
                        print_info "Retry attempt $RETRY_COUNT of $MAX_RETRIES (waiting ${WAIT_TIME}s)..."
                        sleep $WAIT_TIME
                    fi

                    print_info "Downloading Lando installer... (attempt $RETRY_COUNT/$MAX_RETRIES)"

                    if curl -fsSL --connect-timeout 30 --max-time 300 -o "$INSTALLER_PATH" "$LANDO_URL"; then
                        # Verify download
                        if [ -f "$INSTALLER_PATH" ]; then
                            FILE_SIZE=$(stat -f%z "$INSTALLER_PATH" 2>/dev/null || stat -c%s "$INSTALLER_PATH" 2>/dev/null || echo 0)
                            if [ "$FILE_SIZE" -gt 1048576 ]; then
                                print_success "Lando installer downloaded successfully ($((FILE_SIZE / 1048576)) MB)"
                                DOWNLOAD_SUCCESS=true
                            else
                                print_warning "Downloaded file seems incomplete (size: $FILE_SIZE bytes)"
                                rm -f "$INSTALLER_PATH"
                            fi
                        fi
                    else
                        print_warning "Download attempt $RETRY_COUNT failed"
                    fi

                    if [ $RETRY_COUNT -eq $MAX_RETRIES ] && [ "$DOWNLOAD_SUCCESS" = false ]; then
                        print_error "All download attempts failed"
                        print_info "You can manually download from: $LANDO_URL"
                        print_info "Then install and re-run this script with: ./quickstart.sh --skip-lando-install"
                        exit 1
                    fi
                done

                if [ "$DOWNLOAD_SUCCESS" = true ]; then
                    print_info "Mounting installer..."
                    hdiutil attach "$INSTALLER_PATH" -nobrowse -quiet

                    # Determine installation location
                    if [ -n "$LANDO_INSTALL_PATH" ]; then
                        INSTALL_DIR="$LANDO_INSTALL_PATH"
                        print_info "Using custom installation path: $INSTALL_DIR"

                        # Validate custom path
                        if [ ! -d "$INSTALL_DIR" ]; then
                            print_info "Creating installation directory..."
                            mkdir -p "$INSTALL_DIR" 2>/dev/null || {
                                print_error "Cannot create directory: $INSTALL_DIR"
                                print_info "Please use a different path or run with sudo"
                                hdiutil detach /Volumes/Lando -quiet 2>/dev/null || true
                                rm -f "$INSTALLER_PATH"
                                exit 1
                            }
                        fi

                        print_info "Installing Lando to custom path..."
                        cp -R /Volumes/Lando/Lando.app "$INSTALL_DIR/" || {
                            print_error "Failed to install Lando"
                            hdiutil detach /Volumes/Lando -quiet 2>/dev/null || true
                            rm -f "$INSTALLER_PATH"
                            exit 1
                        }

                        LANDO_BIN_PATH="$INSTALL_DIR/Lando.app/Contents/Resources"
                    else
                        # Default: Install to /Applications
                        INSTALL_DIR="/Applications"
                        print_info "Installing Lando to default location (requires sudo)..."
                        sudo cp -R /Volumes/Lando/Lando.app /Applications/ || {
                            print_error "Failed to install Lando"
                            hdiutil detach /Volumes/Lando -quiet 2>/dev/null || true
                            rm -f "$INSTALLER_PATH"
                            exit 1
                        }

                        LANDO_BIN_PATH="/Applications/Lando.app/Contents/Resources"
                    fi

                    print_info "Cleaning up..."
                    hdiutil detach /Volumes/Lando -quiet || true
                    rm -f "$INSTALLER_PATH"

                    # Add to PATH for current session
                    export PATH="$LANDO_BIN_PATH:$PATH"
                    print_success "Added to PATH: $LANDO_BIN_PATH"

                    # Add to shell profile
                    for PROFILE in "$HOME/.bash_profile" "$HOME/.zshrc" "$HOME/.bashrc"; do
                        if [ -f "$PROFILE" ]; then
                            if ! grep -q "$LANDO_BIN_PATH" "$PROFILE" 2>/dev/null; then
                                echo "export PATH=\"$LANDO_BIN_PATH:\$PATH\"" >> "$PROFILE"
                                print_info "Added to profile: $PROFILE"
                            fi
                        fi
                    done

                    print_success "Lando installed successfully at: $INSTALL_DIR"
                    print_info "Lando binary path: $LANDO_BIN_PATH"
                fi
            fi
        else
            # Linux installation
            print_info "Downloading Lando installer..."

            if command -v dpkg &> /dev/null; then
                # Debian/Ubuntu
                LANDO_URL="https://files.lando.dev/installer/lando-x64-stable.deb"
                INSTALLER_PATH="/tmp/lando.deb"

                # Download with retry logic
                MAX_RETRIES=3
                RETRY_COUNT=0
                DOWNLOAD_SUCCESS=false

                while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ "$DOWNLOAD_SUCCESS" = false ]; do
                    RETRY_COUNT=$((RETRY_COUNT + 1))

                    if [ $RETRY_COUNT -gt 1 ]; then
                        WAIT_TIME=$((2 ** (RETRY_COUNT - 1)))
                        print_info "Retry attempt $RETRY_COUNT of $MAX_RETRIES (waiting ${WAIT_TIME}s)..."
                        sleep $WAIT_TIME
                    fi

                    print_info "Downloading Lando installer... (attempt $RETRY_COUNT/$MAX_RETRIES)"

                    if curl -fsSL --connect-timeout 30 --max-time 300 -o "$INSTALLER_PATH" "$LANDO_URL"; then
                        if [ -f "$INSTALLER_PATH" ]; then
                            FILE_SIZE=$(stat -c%s "$INSTALLER_PATH" 2>/dev/null || echo 0)
                            if [ "$FILE_SIZE" -gt 1048576 ]; then
                                print_success "Lando installer downloaded successfully ($((FILE_SIZE / 1048576)) MB)"
                                DOWNLOAD_SUCCESS=true
                            else
                                print_warning "Downloaded file seems incomplete (size: $FILE_SIZE bytes)"
                                rm -f "$INSTALLER_PATH"
                            fi
                        fi
                    else
                        print_warning "Download attempt $RETRY_COUNT failed"
                    fi

                    if [ $RETRY_COUNT -eq $MAX_RETRIES ] && [ "$DOWNLOAD_SUCCESS" = false ]; then
                        print_error "All download attempts failed"
                        print_info "You can manually download from: $LANDO_URL"
                        print_info "Then install and re-run this script with: ./quickstart.sh --skip-lando-install"
                        exit 1
                    fi
                done

                if [ "$DOWNLOAD_SUCCESS" = true ]; then
                    print_info "Installing Lando (requires sudo)..."
                    sudo dpkg -i "$INSTALLER_PATH" || {
                        print_error "Failed to install Lando"
                        rm -f "$INSTALLER_PATH"
                        exit 1
                    }

                    rm -f "$INSTALLER_PATH"
                    print_success "Lando installed successfully"
                fi

            elif command -v rpm &> /dev/null; then
                # Red Hat/CentOS/Fedora
                LANDO_URL="https://files.lando.dev/installer/lando-x64-stable.rpm"
                INSTALLER_PATH="/tmp/lando.rpm"

                # Download with retry logic
                MAX_RETRIES=3
                RETRY_COUNT=0
                DOWNLOAD_SUCCESS=false

                while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ "$DOWNLOAD_SUCCESS" = false ]; do
                    RETRY_COUNT=$((RETRY_COUNT + 1))

                    if [ $RETRY_COUNT -gt 1 ]; then
                        WAIT_TIME=$((2 ** (RETRY_COUNT - 1)))
                        print_info "Retry attempt $RETRY_COUNT of $MAX_RETRIES (waiting ${WAIT_TIME}s)..."
                        sleep $WAIT_TIME
                    fi

                    print_info "Downloading Lando installer... (attempt $RETRY_COUNT/$MAX_RETRIES)"

                    if curl -fsSL --connect-timeout 30 --max-time 300 -o "$INSTALLER_PATH" "$LANDO_URL"; then
                        if [ -f "$INSTALLER_PATH" ]; then
                            FILE_SIZE=$(stat -c%s "$INSTALLER_PATH" 2>/dev/null || echo 0)
                            if [ "$FILE_SIZE" -gt 1048576 ]; then
                                print_success "Lando installer downloaded successfully ($((FILE_SIZE / 1048576)) MB)"
                                DOWNLOAD_SUCCESS=true
                            else
                                print_warning "Downloaded file seems incomplete (size: $FILE_SIZE bytes)"
                                rm -f "$INSTALLER_PATH"
                            fi
                        fi
                    else
                        print_warning "Download attempt $RETRY_COUNT failed"
                    fi

                    if [ $RETRY_COUNT -eq $MAX_RETRIES ] && [ "$DOWNLOAD_SUCCESS" = false ]; then
                        print_error "All download attempts failed"
                        print_info "You can manually download from: $LANDO_URL"
                        print_info "Then install and re-run this script with: ./quickstart.sh --skip-lando-install"
                        exit 1
                    fi
                done

                if [ "$DOWNLOAD_SUCCESS" = true ]; then
                    print_info "Installing Lando (requires sudo)..."
                    sudo rpm -i "$INSTALLER_PATH" || {
                        print_error "Failed to install Lando"
                        rm -f "$INSTALLER_PATH"
                        exit 1
                    }

                    rm -f "$INSTALLER_PATH"
                    print_success "Lando installed successfully"
                fi
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

    # Get and validate UUID with retry logic
    PANTHEON_SITE_ID=""
    MAX_ATTEMPTS=3
    ATTEMPT=0

    while [ -z "$PANTHEON_SITE_ID" ] && [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
        ATTEMPT=$((ATTEMPT + 1))
        echo ""
        print_info "Pantheon Site UUID (Attempt $ATTEMPT/$MAX_ATTEMPTS)"
        print_info "You can paste the UUID in any of these formats:"
        print_info "  - UUID only: <uuid>"
        print_info "  - With hash: <uuid>#dev/code"
        print_info "  - Full URL: https://dashboard.pantheon.io/sites/<uuid>"
        echo ""
        read -rp "Pantheon Site UUID: " UUID_INPUT

        if PANTHEON_SITE_ID=$(extract_pantheon_uuid "$UUID_INPUT"); then
            # UUID extracted successfully
            :
        else
            # Invalid UUID
            PANTHEON_SITE_ID=""
            if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
                echo ""
                print_warning "Please try again"
            fi
        fi
    done

    if [ -z "$PANTHEON_SITE_ID" ]; then
        print_error "Failed to get valid UUID after $MAX_ATTEMPTS attempts"
        exit 1
    fi

    print_success "Using UUID: $PANTHEON_SITE_ID"
    print_info "This will connect to the DEV environment only"
    echo ""

    print_info "Terminus Machine Token"
    print_info "Find or create your token at: https://dashboard.pantheon.io/personal-settings/machine-tokens"
    echo ""
    read -rsp "Terminus Machine Token: " TERMINUS_TOKEN
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

# Always regenerate .lando.yml from template to pick up updates (like WP-CLI installation)
if [ -f ".lando.yml.example" ]; then
    print_info "Regenerating .lando.yml from template..."
    cp -f .lando.yml.example .lando.yml
    print_success ".lando.yml regenerated from template"
else
    print_error ".lando.yml.example template not found! Are you in the correct directory?"
    exit 1
fi

# Update .lando.yml with site details from .env
print_info "Updating .lando.yml configuration..."
if [ -f ".env" ]; then
    # Source .env to get variables
    # shellcheck disable=SC1091
    set -a
    source .env
    set +a

    # Update .lando.yml (local file, gitignored)
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

# Clean up any partial Composer installations before starting
if [ -d "vendor" ] && [ ! -f "vendor/autoload.php" ]; then
    print_info "Cleaning up partial Composer installation..."
    rm -rf vendor/
fi

# Smart Container Orchestration
# Determine if we need full rebuild, fast restart, or can use existing containers
print_info "Analyzing container state..."

CURRENT_LANDO_HASH=$(get_file_hash ".lando.yml")
PREVIOUS_BUILD_INFO=$(get_lando_build_info)
CONTAINER_STATE=$(test_container_state)

NEEDS_REBUILD=false
NEEDS_RESTART=false
CAN_USE_EXISTING=false

# Decision logic
if [ "$FORCE_REBUILD" = true ]; then
    print_info "Force rebuild requested (--force flag)"
    NEEDS_REBUILD=true
elif [ "$QUICK_START" = true ]; then
    print_info "Quick start requested (--quick-start flag) - using existing containers"
    CAN_USE_EXISTING=true
elif [ -z "$PREVIOUS_BUILD_INFO" ]; then
    print_info "First run detected - full build required"
    NEEDS_REBUILD=true
else
    # Extract hash from previous build info (simple JSON parsing)
    PREVIOUS_HASH=$(echo "$PREVIOUS_BUILD_INFO" | grep -o '"landoYmlHash": "[^"]*"' | cut -d'"' -f4)

    if [ "$PREVIOUS_HASH" != "$CURRENT_LANDO_HASH" ]; then
        print_info "Configuration changed - full rebuild required"
        print_info "  Previous hash: ${PREVIOUS_HASH:0:16}..."
        print_info "  Current hash:  ${CURRENT_LANDO_HASH:0:16}..."
        NEEDS_REBUILD=true
    elif [ "$CONTAINER_STATE" = "missing" ]; then
        print_info "Containers not found - full build required"
        NEEDS_REBUILD=true
    elif [ "$CONTAINER_STATE" = "stopped" ]; then
        print_info "Containers exist but stopped - fast restart possible"
        NEEDS_RESTART=true
    elif [ "$CONTAINER_STATE" = "running" ]; then
        print_info "Containers already running - verifying health..."
        CAN_USE_EXISTING=true
    else
        print_warning "Unknown container state - full rebuild required"
        NEEDS_REBUILD=true
    fi
fi

# Execute decision
if [ "$NEEDS_REBUILD" = true ]; then
    echo ""
    print_info "Performing full rebuild..."
    echo ""
    print_info "FIRST RUN TIMING EXPECTATIONS:"
    print_info "  - Docker image pull: 1-2 minutes (one-time)"
    print_info "  - Container build: 30-60 seconds (optimized with caching)"
    print_info "  - Composer dependencies: 2-3 minutes (one-time, then cached)"
    print_info "  - Total first run: 3-6 minutes"
    print_info "  - Subsequent rebuilds: 30-90 seconds (most steps cached)"
    echo ""
    print_info "What's happening:"
    print_info "  → Stopping containers..."

    # Stop containers
    lando stop >/dev/null 2>&1
    sleep 2

    print_info "  → Destroying old containers..."

    # Destroy containers
    lando destroy -y >/dev/null 2>&1
    sleep 2

    print_success "  → Ready for fresh build"
    echo ""
    print_info "Starting build process (please be patient)..."
elif [ "$NEEDS_RESTART" = true ]; then
    echo ""
    print_info "Fast restart (~30 seconds)..."
    print_info "  → No rebuild needed, containers already exist"
    print_info "  → Just restarting services"
elif [ "$CAN_USE_EXISTING" = true ]; then
    echo ""
    print_info "Using existing containers (instant)..."
    print_info "  → Containers already running"
    print_info "  → Skipping rebuild and restart"
fi

LANDO_STARTED=false
MAX_ATTEMPTS=3

# Skip lando start if we can use existing containers
if [ "$CAN_USE_EXISTING" = true ]; then
    echo ""
    print_info "Containers already running - verifying health..."
    LANDO_STARTED=true
    # Will verify health below
else
    # Need to start or restart containers
    if [ "$NEEDS_RESTART" = true ]; then
        echo ""
        print_info "Starting existing containers..."
    else
        echo ""
        print_info "Starting Lando... (this may take several minutes on first run)"
    fi

    for attempt in $(seq 1 $MAX_ATTEMPTS); do
        if [ $attempt -eq 1 ]; then
            print_info "Starting Lando (attempt $attempt/$MAX_ATTEMPTS)..."
            echo ""
            if [ "$NEEDS_REBUILD" = true ]; then
                print_info "Building containers now..."
                print_info "You'll see output for:"
                print_info "  1. Docker pulling base images (if needed)"
                print_info "  2. Installing system packages (vim, wget, WP-CLI) - optimized with checks"
                print_info "  3. Installing Composer dependencies (if needed)"
                print_info "  4. Starting MySQL, Redis, PhpMyAdmin services"
                echo ""
                print_warning "This may take 3-6 minutes on first run. Please wait..."
                print_info "TIP: Next time will be much faster (~30 seconds)!"
            else
                print_info "Restarting existing containers (should be quick)..."
            fi
            echo ""
            lando start
        elif [ $attempt -eq 2 ]; then
            print_warning "First attempt failed. Destroying and starting fresh (attempt $attempt/$MAX_ATTEMPTS)..."
            # Project-specific stop (doesn't affect other Lando projects)
            lando stop >/dev/null 2>&1
            sleep 2
            # Gracefully handle destroy warnings (project-specific)
            lando destroy -y >/dev/null 2>&1
            sleep 2
            lando start
        else
            print_warning "Second attempt failed. Performing aggressive cleanup (attempt $attempt/$MAX_ATTEMPTS)..."
            # Project-specific stop (doesn't affect other Lando projects)
            lando stop >/dev/null 2>&1
            sleep 2
            # Gracefully handle destroy warnings (project-specific, cleans up this project's resources)
            lando destroy -y >/dev/null 2>&1
            sleep 2
            # Note: Removed 'docker system prune' - too aggressive, affects all Docker projects
            # lando destroy already cleans up this project's containers, networks, and volumes
            lando start
        fi

    # Always verify containers are actually running, regardless of exit codes
    sleep 5
    print_info "Verifying containers are running..."

    LANDO_INFO=$(lando info --format json 2>/dev/null || echo "")

    if echo "$LANDO_INFO" | grep -q '\[' && ! echo "$LANDO_INFO" | grep -q '"service":\s*\[\s*\]'; then
        print_success "Lando started successfully!"
        LANDO_STARTED=true

        # Install Lando SSL certificate to prevent browser warnings
        echo ""
        print_info "Installing Lando SSL certificate..."
        LANDO_CERT_PATH="$HOME/.lando/certs/lndo.site.pem"

        if [ -f "$LANDO_CERT_PATH" ]; then
            if [[ "$OS" == "macos" ]]; then
                # macOS: Add to System keychain
                if security find-certificate -c "lndo.site" -p /Library/Keychains/System.keychain >/dev/null 2>&1; then
                    print_success "Lando SSL certificate already trusted"
                else
                    if sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$LANDO_CERT_PATH" 2>/dev/null; then
                        print_success "Lando SSL certificate installed successfully!"
                        print_info "You won't see browser security warnings for *.lndo.site domains"
                    else
                        print_warning "Could not install SSL certificate automatically"
                        print_info "You may see browser security warnings for https://wordpress-pantheon.lndo.site"
                        print_info "This is safe - just click 'Advanced' -> 'Proceed' in your browser"
                    fi
                fi
            else
                # Linux: Add to ca-certificates (if available)
                if command -v update-ca-certificates >/dev/null 2>&1; then
                    if [ -f "/usr/local/share/ca-certificates/lndo.site.crt" ]; then
                        print_success "Lando SSL certificate already trusted"
                    else
                        if sudo cp "$LANDO_CERT_PATH" /usr/local/share/ca-certificates/lndo.site.crt 2>/dev/null && \
                           sudo update-ca-certificates 2>/dev/null; then
                            print_success "Lando SSL certificate installed successfully!"
                            print_info "You won't see browser security warnings for *.lndo.site domains"
                        else
                            print_warning "Could not install SSL certificate automatically"
                            print_info "You may see browser security warnings (safe to bypass)"
                        fi
                    fi
                else
                    print_info "Automatic SSL certificate installation not available on this system"
                    print_info "You may see browser security warnings (safe to bypass)"
                fi
            fi
        else
            print_warning "Lando certificate not found at expected location"
            print_info "You may see browser security warnings (safe to bypass)"
        fi

        break
    else
        if [ $attempt -lt $MAX_ATTEMPTS ]; then
            print_warning "Containers not running properly, will retry with more aggressive cleanup..."
            sleep 2
        fi
    fi
    done
fi

# Save build info after successful startup
if [ "$LANDO_STARTED" = true ]; then
    echo ""
    print_info "Saving build state..."
    set_lando_build_info "$CURRENT_LANDO_HASH" "running"
    print_success "Build state saved to .lando-build-info"
fi

if [ "$LANDO_STARTED" = false ]; then
    print_error "Failed to start Lando after $MAX_ATTEMPTS attempts"
    echo ""
    print_info "Troubleshooting steps:"
    print_info "  1. Check Docker Desktop is running and healthy"
    print_info "  2. Restart Docker Desktop completely"
    print_info "  3. Try manually: lando stop && lando destroy -y && lando start"
    print_info "     (project-specific, won't affect other Lando projects)"
    print_info "  4. Check for port conflicts (80, 443, 3306 in use)"
    print_info "  5. Check Lando logs: lando logs"
    print_info "  6. Update Lando: Visit https://docs.lando.dev/getting-started/installation.html"
    echo ""
    print_info "Performance troubleshooting (if startup took > 10 minutes):"
    print_info "  - Check your internet connection (slow downloads)"
    print_info "  - Check Docker Desktop resources (CPU/Memory in Settings)"
    print_info "  - Try: docker system prune (WARNING: removes all unused Docker data)"
    print_info "  - Consider using --quick-start flag for instant startups (assumes healthy containers)"
    echo ""
    print_info "If issues persist, check Docker Desktop logs for errors"
    exit 1
fi

##############################################################################
# 5. Authenticate with Terminus
##############################################################################

echo ""
print_header "Step 5: Authenticating with Terminus"

# Read token from .env
# shellcheck disable=SC1091
set -a
source .env
set +a

# Validate token is present
if [ -z "$TERMINUS_TOKEN" ]; then
    print_error "TERMINUS_TOKEN not found in .env file"
    print_info "Please check your .env file contains: TERMINUS_TOKEN=your-machine-token"
    print_info "Get your token at: https://dashboard.pantheon.io/personal-settings/machine-tokens"
    exit 1
fi

print_info "Authenticating with Terminus..."
print_info "Using machine token from .env file"

# Ensure Terminus cache directory exists with proper permissions
print_info "Setting up Terminus cache directory..."
lando ssh -c "mkdir -p /var/www/.terminus/cache && chmod -R 755 /var/www/.terminus" 2>/dev/null || true

# Authenticate with Terminus
AUTH_OUTPUT=$(lando terminus auth:login --machine-token="$TERMINUS_TOKEN" 2>&1)
AUTH_EXIT_CODE=$?

if [ $AUTH_EXIT_CODE -eq 0 ]; then
    print_success "Terminus authentication successful!"

    # Verify authentication
    WHOAMI=$(lando terminus auth:whoami 2>/dev/null || echo "unknown")
    if [ "$WHOAMI" != "unknown" ] && [ -n "$WHOAMI" ]; then
        print_success "Logged in as: $WHOAMI"
    else
        print_warning "Authentication may have issues (couldn't verify user)"
    fi
else
    print_error "Failed to authenticate with Terminus"
    echo ""
    print_info "Error details:"
    echo "$AUTH_OUTPUT" | grep -i "error" || echo "$AUTH_OUTPUT"
    echo ""
    print_info "Troubleshooting:"
    print_info "  1. Check your machine token is valid"
    print_info "  2. Get a new token at: https://dashboard.pantheon.io/personal-settings/machine-tokens"
    print_info "  3. Update your .env file with: TERMINUS_TOKEN=your-new-token"
    print_info "  4. Make sure the token hasn't expired"
    exit 1
fi

##############################################################################
# 6. Pull Data from Pantheon
##############################################################################

print_header "Step 6: Syncing Data from Pantheon"

print_info "This will pull the database and files from your Pantheon Dev environment"
read -rp "Do you want to pull data now? (Y/n): " PULL_DATA

if [[ ! "$PULL_DATA" =~ ^[Nn]$ ]]; then
    # Use built-in Lando pull command to get code, database, and files from Pantheon
    print_info "Pulling code, database, and files from Pantheon Dev..."
    print_info "This will pull WordPress core, plugins, themes, database, and uploads"
    print_info "Using authenticated Terminus session (no token prompt needed)"
    echo ""

    # Export TERMINUS_MACHINE_TOKEN for lando pull to use
    # This prevents the interactive token prompt
    export TERMINUS_MACHINE_TOKEN="$TERMINUS_TOKEN"

    # Run lando pull with the token available in the environment
    PULL_OUTPUT=$(lando pull 2>&1)
    PULL_EXIT_CODE=$?

    # Display the output
    echo "$PULL_OUTPUT"

    if [ $PULL_EXIT_CODE -eq 0 ]; then
        print_success "Pantheon pull completed!"
    else
        # Check if the error is authentication-related
        if echo "$PULL_OUTPUT" | grep -qi "401\|unauthorized\|authenticate\|token"; then
            echo ""
            print_error "Authentication failed during pull"
            print_info "Your machine token may be invalid or expired"
            print_info "Get a new token at: https://dashboard.pantheon.io/personal-settings/machine-tokens"
            print_info "Then update your .env file with: TERMINUS_TOKEN=your-new-token"
            exit 1
        else
            print_warning "Pantheon pull completed with warnings (see output above)"
            print_info "You may need to run 'lando pull' manually after setup"
        fi
    fi

    # CRITICAL: Verify WordPress core exists after pull
    echo ""
    print_info "Verifying WordPress core was pulled..."

    if lando ssh -c "test -f /app/wordpress/wp-includes/version.php" 2>/dev/null; then
        print_success "WordPress core verified successfully!"
    else
        echo ""
        print_error "ERROR: WordPress core not found after pull!"
        echo ""
        print_info "This usually means:"
        print_info "  - You selected 'No' when asked to pull code"
        print_info "  - The code pull from Pantheon failed"
        print_info "  - Network issues interrupted the download"
        echo ""
        print_error "WordPress core is REQUIRED for database import."
        print_info "Please run the setup again and select 'Yes' when asked to pull code."
        echo ""
        exit 1
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
   lando start           - Start the development environment (~30s after first build)
   lando stop            - Stop the development environment
   lando pull-db         - Pull database from Pantheon Dev
   lando pull-files      - Pull files from Pantheon Dev
   lando wp              - Run WP-CLI commands
   lando terminus        - Run Terminus commands

[PERFORMANCE TIPS]
   Next startup:         ~30 seconds (containers cached)
   Force rebuild:        sudo ./quickstart.sh --force
   Instant startup:      sudo ./quickstart.sh --quick-start (skips health checks)

   OPTIMIZATION: This setup uses smart caching:
   - System packages (vim, wget, WP-CLI) only installed once
   - Composer dependencies cached between rebuilds
   - Container state tracked to avoid unnecessary rebuilds

   If startup feels slow:
   - First run: 3-6 minutes is normal (downloading & building)
   - Subsequent runs: Should be ~30 seconds
   - If consistently slow (>2 min): Check Docker Desktop resources

[DOCUMENTATION]
   README.md             - Full documentation
   SETUP.md              - Detailed setup guide
   SECURITY.md           - Security best practices
   QUICK-REFERENCE.md    - Command reference

EOF

print_success "Setup completed successfully!"
