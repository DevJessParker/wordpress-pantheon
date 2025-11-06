#!/bin/bash

###############################################################################
# Pull Files from Pantheon Dev Environment
# This script syncs wp-content/uploads from Pantheon to local
###############################################################################

set -e

# Change to WordPress directory
cd /app/web 2>/dev/null || cd /app/wordpress 2>/dev/null || cd /app || { echo "Error: Cannot find WordPress directory"; exit 1; }

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Pulling Files from Pantheon Dev${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if required environment variables are set
if [ -z "$PANTHEON_SITE" ]; then
    echo -e "${RED}Error: PANTHEON_SITE environment variable not set${NC}"
    echo "Please set it in your .env file"
    exit 1
fi

# Check if Terminus is authenticated
if ! terminus auth:whoami > /dev/null 2>&1; then
    echo -e "${YELLOW}Terminus not authenticated. Please login:${NC}"
    terminus auth:login
fi

echo -e "${YELLOW}Step 1/3: Creating backup on Pantheon Dev...${NC}"
terminus backup:create ${PANTHEON_SITE}.dev --element=files --keep-for=1

echo -e "${YELLOW}Step 2/3: Getting backup URL...${NC}"
BACKUP_URL=$(terminus backup:get ${PANTHEON_SITE}.dev --element=files)

echo -e "${YELLOW}Step 3/3: Downloading and extracting files...${NC}"
mkdir -p /tmp/pantheon-files
cd /tmp/pantheon-files

# Download
curl -o files.tar.gz "$BACKUP_URL"

# Extract
tar -xzf files.tar.gz

# Sync to local wp-content/uploads
mkdir -p /app/wp-content/uploads
rsync -avz --delete files_dev/ /app/wp-content/uploads/

# Clean up
cd /app
rm -rf /tmp/pantheon-files

echo ""
echo -e "${GREEN}✓ Files pulled successfully!${NC}"
echo -e "${GREEN}✓ Uploads synced to wp-content/uploads/${NC}"
echo ""
