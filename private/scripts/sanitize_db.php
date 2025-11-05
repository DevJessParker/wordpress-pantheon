<?php
/**
 * Quicksilver Script: Sanitize Database
 *
 * This script runs after database cloning to sanitize sensitive data.
 */

echo "Sanitizing database after clone...\n";

// Disable email sending
passthru("wp option update blogdescription 'DEVELOPMENT ENVIRONMENT - DO NOT SEND EMAILS'");

// Update admin email to a safe address
passthru("wp option update admin_email dev@example.com");

// Anonymize user emails (except admin)
passthru("wp user list --role=subscriber,contributor,author,editor --field=ID | xargs -I % wp user update % --user_email=%@example.com");

// Clear transients
passthru('wp transient delete --all');

// Regenerate salts
passthru('wp config shuffle-salts');

echo "✓ Database sanitized successfully!\n";
