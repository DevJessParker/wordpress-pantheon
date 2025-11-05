#!/bin/bash

###############################################################################
# Push Database to Pantheon Dev Environment
# WARNING: This will OVERWRITE the Pantheon Dev database
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${RED}========================================${NC}"
echo -e "${RED}WARNING: Push Database to Pantheon Dev${NC}"
echo -e "${RED}========================================${NC}"
echo ""
echo -e "${YELLOW}This will OVERWRITE the database on Pantheon Dev environment!${NC}"
echo ""

# Confirmation prompt
read -p "Are you sure you want to continue? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo -e "${GREEN}Cancelled. No changes made.${NC}"
    exit 0
fi

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

echo -e "${YELLOW}Step 1/5: Creating backup of Pantheon Dev (safety)...${NC}"
terminus backup:create ${PANTHEON_SITE}.dev --element=db --keep-for=7

echo -e "${YELLOW}Step 2/5: Exporting local database...${NC}"
mkdir -p /tmp/local-db
LOCAL_URL="https://wordpress-pantheon.lndo.site"

# Get the Pantheon URL
PANTHEON_URL=$(terminus env:info ${PANTHEON_SITE}.dev --field=domain)

# Export database
wp db export /tmp/local-db/local.sql

echo -e "${YELLOW}Step 3/5: Updating URLs for Pantheon...${NC}"
# Create a copy and update URLs
wp search-replace "$LOCAL_URL" "https://$PANTHEON_URL" --skip-columns=guid --all-tables --export=/tmp/local-db/pantheon.sql

echo -e "${YELLOW}Step 4/5: Compressing database...${NC}"
gzip /tmp/local-db/pantheon.sql

echo -e "${YELLOW}Step 5/5: Uploading to Pantheon...${NC}"
# Put site in SFTP mode
terminus connection:set ${PANTHEON_SITE}.dev sftp

# Import via Terminus
terminus import:database ${PANTHEON_SITE}.dev /tmp/local-db/pantheon.sql.gz

# Clear cache on Pantheon
terminus env:clear-cache ${PANTHEON_SITE}.dev

# Clean up
rm -rf /tmp/local-db

echo ""
echo -e "${GREEN}✓ Database pushed successfully!${NC}"
echo -e "${YELLOW}⚠ Remember to test on Pantheon Dev before deploying to Test/Live${NC}"
echo ""
