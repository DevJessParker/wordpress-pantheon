#!/bin/bash

###############################################################################
# Security Check Script
# Runs various security checks on the WordPress installation
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}WordPress Security Check${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check 1: WordPress Core Updates
echo -e "${YELLOW}[1/8] Checking WordPress core updates...${NC}"
if wp core check-update --format=count | grep -q "^0$"; then
    echo -e "${GREEN}✓ WordPress core is up to date${NC}"
else
    echo -e "${RED}⚠ WordPress core updates available${NC}"
    wp core check-update
fi
echo ""

# Check 2: Plugin Updates
echo -e "${YELLOW}[2/8] Checking plugin updates...${NC}"
PLUGIN_UPDATES=$(wp plugin list --update=available --format=count)
if [ "$PLUGIN_UPDATES" -eq "0" ]; then
    echo -e "${GREEN}✓ All plugins are up to date${NC}"
else
    echo -e "${RED}⚠ $PLUGIN_UPDATES plugin(s) have updates available${NC}"
    wp plugin list --update=available
fi
echo ""

# Check 3: Theme Updates
echo -e "${YELLOW}[3/8] Checking theme updates...${NC}"
THEME_UPDATES=$(wp theme list --update=available --format=count)
if [ "$THEME_UPDATES" -eq "0" ]; then
    echo -e "${GREEN}✓ All themes are up to date${NC}"
else
    echo -e "${RED}⚠ $THEME_UPDATES theme(s) have updates available${NC}"
    wp theme list --update=available
fi
echo ""

# Check 4: File Permissions
echo -e "${YELLOW}[4/8] Checking file permissions...${NC}"
if [ -w "/app/wp-config.php" ]; then
    echo -e "${GREEN}✓ wp-config.php permissions OK${NC}"
else
    echo -e "${RED}⚠ wp-config.php is not writable${NC}"
fi
echo ""

# Check 5: Debug Mode
echo -e "${YELLOW}[5/8] Checking debug mode...${NC}"
if wp config get WP_DEBUG --type=constant | grep -q "true"; then
    echo -e "${YELLOW}⚠ WP_DEBUG is enabled (OK for local dev)${NC}"
else
    echo -e "${GREEN}✓ WP_DEBUG is disabled${NC}"
fi
echo ""

# Check 6: Salts and Keys
echo -e "${YELLOW}[6/8] Checking security keys and salts...${NC}"
MISSING_SALTS=0
for KEY in AUTH_KEY SECURE_AUTH_KEY LOGGED_IN_KEY NONCE_KEY AUTH_SALT SECURE_AUTH_SALT LOGGED_IN_SALT NONCE_SALT; do
    if ! wp config get $KEY --type=constant > /dev/null 2>&1; then
        echo -e "${RED}⚠ Missing: $KEY${NC}"
        MISSING_SALTS=$((MISSING_SALTS + 1))
    fi
done
if [ "$MISSING_SALTS" -eq "0" ]; then
    echo -e "${GREEN}✓ All security keys and salts are set${NC}"
fi
echo ""

# Check 7: Database Prefix
echo -e "${YELLOW}[7/8] Checking database table prefix...${NC}"
DB_PREFIX=$(wp config get table_prefix --type=variable)
if [ "$DB_PREFIX" = "wp_" ]; then
    echo -e "${YELLOW}⚠ Using default 'wp_' prefix (consider changing for better security)${NC}"
else
    echo -e "${GREEN}✓ Using custom database prefix: $DB_PREFIX${NC}"
fi
echo ""

# Check 8: Admin User Check
echo -e "${YELLOW}[8/8] Checking for default admin username...${NC}"
if wp user get admin --field=ID > /dev/null 2>&1; then
    echo -e "${RED}⚠ Default 'admin' username exists (security risk)${NC}"
else
    echo -e "${GREEN}✓ No default 'admin' username found${NC}"
fi
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Security check complete${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Recommendations:${NC}"
echo "  - Keep WordPress core, plugins, and themes updated"
echo "  - Use strong, unique passwords for all users"
echo "  - Enable two-factor authentication"
echo "  - Regular backups (automated on Pantheon)"
echo "  - Monitor security logs"
echo ""
