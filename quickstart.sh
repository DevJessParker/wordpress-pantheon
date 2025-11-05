#!/bin/bash

##############################################################################
# WordPress + Pantheon Quickstart Setup Script (macOS/Linux)
# This script automates the installation and configuration process
##############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Helper functions
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_info() { echo -e "${CYAN}ℹ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_header() { echo -e "\n${MAGENTA}========================================\n$1\n========================================${NC}\n"; }

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
  - macOS or Linux
  - Git installed
  - Docker Desktop installed and running
  - Internet connection
  - Pantheon account with machine token

EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
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
    print_info "Detected: macOS"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    print_info "Detected: Linux"
else
    print_error "Unsupported operating system: $OSTYPE"
    exit 1
fi

# Check Git
print_info "Checking for Git..."
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version)
    print_success "Git is installed: $GIT_VERSION"
else
    print_error "Git is not installed!"
    if [ "$OS" = "macos" ]; then
        print_info "Install with: brew install git"
        print_info "Or download from: https://git-scm.com/download/mac"
    else
        print_info "Install with: sudo apt-get install git (Ubuntu/Debian)"
        print_info "Or: sudo yum install git (CentOS/RHEL)"
    fi
    exit 1
fi

# Check Docker
print_info "Checking for Docker..."
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    print_success "Docker is installed: $DOCKER_VERSION"

    # Check if Docker is running
    if docker ps &> /dev/null; then
        print_success "Docker is running"
    else
        print_warning "Docker is installed but not running"
        print_info "Please start Docker Desktop and wait for it to be ready"
        echo -n "Press Enter when Docker Desktop is running..."
        read
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
        LANDO_VERSION=$(lando version)
        print_success "Lando is already installed: $LANDO_VERSION"
    else
        print_warning "Lando is not installed"
        print_info "Installing Lando..."

        if [ "$OS" = "macos" ]; then
            # macOS installation
            if command -v brew &> /dev/null; then
                print_info "Installing via Homebrew..."
                brew install lando
                print_success "Lando installed successfully"
            else
                print_info "Downloading Lando installer..."
                LANDO_URL="https://github.com/lando/lando/releases/download/v3.21.0/lando-x64-v3.21.0.dmg"
                curl -L -o /tmp/lando.dmg "$LANDO_URL"

                print_info "Mounting installer..."
                hdiutil attach /tmp/lando.dmg

                print_info "Installing Lando..."
                sudo cp -R /Volumes/Lando/Lando.app /Applications/

                print_info "Cleaning up..."
                hdiutil detach /Volumes/Lando
                rm /tmp/lando.dmg

                # Add to PATH
                echo 'export PATH="/Applications/Lando.app/Contents/Resources:$PATH"' >> ~/.bash_profile
                echo 'export PATH="/Applications/Lando.app/Contents/Resources:$PATH"' >> ~/.zshrc
                export PATH="/Applications/Lando.app/Contents/Resources:$PATH"

                print_success "Lando installed successfully"
                print_warning "You may need to restart your terminal for Lando to be available"
            fi
        else
            # Linux installation
            print_info "Downloading Lando installer..."
            LANDO_URL="https://github.com/lando/lando/releases/download/v3.21.0/lando-x64-v3.21.0.deb"

            if command -v dpkg &> /dev/null; then
                # Debian/Ubuntu
                wget -O /tmp/lando.deb "$LANDO_URL"
                sudo dpkg -i /tmp/lando.deb
                rm /tmp/lando.deb
            else
                print_error "Automatic installation not supported for your Linux distribution"
                print_info "Please install manually from: https://docs.lando.dev/getting-started/installation.html"
                exit 1
            fi

            print_success "Lando installed successfully"
        fi

        # Verify installation
        if command -v lando &> /dev/null; then
            print_success "Lando is now available: $(lando version)"
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
    read -p "Do you want to reconfigure? (y/N): " OVERWRITE
    if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
        print_info "Keeping existing .env file"
    else
        rm .env
    fi
fi

if [ ! -f ".env" ]; then
    print_info "Creating .env file..."

    # Prompt for Pantheon credentials
    echo ""
    echo "Please provide your Pantheon site information:"
    print_info "You can find these in your Pantheon Dashboard"
    echo ""

    read -p "Pantheon Site Name (e.g., my-awesome-site): " PANTHEON_SITE
    read -p "Pantheon Site UUID (from Settings → About): " PANTHEON_SITE_ID
    read -sp "Terminus Machine Token (from Account → Machine Tokens): " TERMINUS_TOKEN
    echo ""

    # Create .env file from template
    cp .env.example .env

    # Update .env with user values
    if [[ "$OS" == "macos" ]]; then
        # macOS sed
        sed -i '' "s/PANTHEON_SITE=your-site-name/PANTHEON_SITE=$PANTHEON_SITE/" .env
        sed -i '' "s/PANTHEON_SITE_ID=your-site-uuid/PANTHEON_SITE_ID=$PANTHEON_SITE_ID/" .env
        sed -i '' "s/TERMINUS_TOKEN=your-terminus-machine-token/TERMINUS_TOKEN=$TERMINUS_TOKEN/" .env
        sed -i '' "s/PANTHEON_SITE_URL=dev-your-site-name.pantheonsite.io/PANTHEON_SITE_URL=dev-$PANTHEON_SITE.pantheonsite.io/" .env
    else
        # Linux sed
        sed -i "s/PANTHEON_SITE=your-site-name/PANTHEON_SITE=$PANTHEON_SITE/" .env
        sed -i "s/PANTHEON_SITE_ID=your-site-uuid/PANTHEON_SITE_ID=$PANTHEON_SITE_ID/" .env
        sed -i "s/TERMINUS_TOKEN=your-terminus-machine-token/TERMINUS_TOKEN=$TERMINUS_TOKEN/" .env
        sed -i "s/PANTHEON_SITE_URL=dev-your-site-name.pantheonsite.io/PANTHEON_SITE_URL=dev-$PANTHEON_SITE.pantheonsite.io/" .env
    fi

    print_success ".env file created and configured"
fi

# Update .lando.yml with site details
print_info "Updating .lando.yml configuration..."
if [ -f ".env" ]; then
    # Read PANTHEON_SITE and PANTHEON_SITE_ID from .env
    source .env

    # Update .lando.yml
    if [[ "$OS" == "macos" ]]; then
        sed -i '' "s/site: YOUR_PANTHEON_SITE_NAME/site: $PANTHEON_SITE/" .lando.yml
        sed -i '' "s/id: YOUR_PANTHEON_SITE_ID/id: $PANTHEON_SITE_ID/" .lando.yml
    else
        sed -i "s/site: YOUR_PANTHEON_SITE_NAME/site: $PANTHEON_SITE/" .lando.yml
        sed -i "s/id: YOUR_PANTHEON_SITE_ID/id: $PANTHEON_SITE_ID/" .lando.yml
    fi

    print_success ".lando.yml updated with your site details"
fi

##############################################################################
# 4. Start Lando
##############################################################################

print_header "Step 4: Starting Lando Environment"

print_info "Starting Lando... (this may take several minutes on first run)"
lando start

if [ $? -eq 0 ]; then
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
source .env

print_info "Authenticating with Terminus..."
lando terminus auth:login --machine-token=$TERMINUS_TOKEN

if [ $? -eq 0 ]; then
    print_success "Terminus authentication successful!"

    # Verify authentication
    WHOAMI=$(lando terminus auth:whoami)
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
read -p "Do you want to pull data now? (Y/n): " PULL_DATA

if [[ ! "$PULL_DATA" =~ ^[Nn]$ ]]; then
    print_info "Pulling database from Pantheon Dev..."
    lando pull-db

    if [ $? -eq 0 ]; then
        print_success "Database pulled successfully!"
    else
        print_warning "Failed to pull database. You can try again later with: lando pull-db"
    fi

    print_info "Pulling files from Pantheon Dev..."
    lando pull-files

    if [ $? -eq 0 ]; then
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

EOF

print_success "Setup completed successfully!"
