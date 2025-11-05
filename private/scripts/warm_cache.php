<?php
/**
 * Quicksilver Script: Warm Cache
 *
 * This script warms up the cache after deployment.
 */

echo "Warming cache after deployment...\n";

// Get the site URL
$site_url = getenv('PANTHEON_ENVIRONMENT');
$domain = $site_url . '-' . getenv('PANTHEON_SITE_NAME') . '.pantheonsite.io';

// Common pages to warm
$pages = [
    '/',
    '/about/',
    '/contact/',
    '/blog/',
];

foreach ($pages as $page) {
    $url = 'https://' . $domain . $page;
    echo "Warming: $url\n";

    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
    curl_exec($ch);
    curl_close($ch);
}

echo "✓ Cache warmed successfully!\n";
