<?php
/**
 * Quicksilver Script: Clear Cache
 *
 * This script runs after code syncs and deployments to clear all caches.
 */

echo "Clearing WordPress object cache...\n";
passthru('wp cache flush');

echo "Clearing page cache...\n";
passthru('wp pantheon cache flush');

echo "✓ Cache cleared successfully!\n";
