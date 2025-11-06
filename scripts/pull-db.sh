#!/bin/bash

###############################################################################
# Pull Database from Pantheon Dev Environment
# This script safely pulls the database from Pantheon and imports it locally
###############################################################################

set -e

# Change to WordPress directory (WP-CLI needs to run from WordPress root)
cd /app/web 2>/dev/null || cd /app || { echo "Error: Cannot find WordPress directory"; exit 1; }

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Pulling Database from Pantheon Dev${NC}"
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

echo -e "${YELLOW}Step 1/4: Creating backup on Pantheon Dev...${NC}"
terminus backup:create ${PANTHEON_SITE}.dev --element=db --keep-for=1

echo -e "${YELLOW}Step 2/4: Getting backup URL...${NC}"
BACKUP_URL=$(terminus backup:get ${PANTHEON_SITE}.dev --element=db)

echo -e "${YELLOW}Step 3/4: Downloading backup...${NC}"
mkdir -p /tmp/pantheon-backups
curl -o /tmp/pantheon-backups/pantheon-dev.sql.gz "$BACKUP_URL"

echo -e "${YELLOW}Step 4/4: Importing database...${NC}"
gunzip -c /tmp/pantheon-backups/pantheon-dev.sql.gz | wp db import -

# Get the Pantheon URL for search-replace
PANTHEON_URL=$(terminus env:info ${PANTHEON_SITE}.dev --field=domain)
LOCAL_URL="https://wordpress-pantheon.lndo.site"

echo -e "${YELLOW}Updating URLs in database...${NC}"
wp search-replace "https://$PANTHEON_URL" "$LOCAL_URL" --skip-columns=guid --all-tables
wp search-replace "http://$PANTHEON_URL" "$LOCAL_URL" --skip-columns=guid --all-tables

# Flush cache
echo -e "${YELLOW}Flushing cache...${NC}"
wp cache flush

# Clean up
rm -rf /tmp/pantheon-backups

echo ""
echo -e "${GREEN}✓ Database pulled successfully!${NC}"
echo -e "${GREEN}✓ URLs updated to $LOCAL_URL${NC}"
echo ""
