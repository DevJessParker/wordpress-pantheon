<?php
/**
 * WordPress Configuration for Pantheon
 *
 * This is a sample wp-config.php that works with both Pantheon and local development.
 * Pantheon's wp-config.php is managed by the platform, but this shows best practices.
 *
 * For local development with Lando, this file demonstrates environment detection.
 */

/**
 * Load environment variables from .env file (local development only)
 */
if (file_exists(__DIR__ . '/vendor/autoload.php')) {
    require_once __DIR__ . '/vendor/autoload.php';
}

if (class_exists('Dotenv\Dotenv') && file_exists(__DIR__ . '/.env')) {
    $dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
    $dotenv->load();
}

/**
 * Detect environment
 */
if (isset($_ENV['PANTHEON_ENVIRONMENT'])) {
    // Running on Pantheon
    $env = $_ENV['PANTHEON_ENVIRONMENT'];
    define('WP_ENVIRONMENT_TYPE', $env === 'live' ? 'production' : ($env === 'test' ? 'staging' : 'development'));
} else {
    // Local development
    define('WP_ENVIRONMENT_TYPE', 'local');
}

/**
 * Database Configuration
 * Pantheon provides these automatically, but we set defaults for local
 */
if (isset($_ENV['PANTHEON_ENVIRONMENT'])) {
    // Pantheon database config (provided by platform)
    define('DB_NAME', $_ENV['DB_NAME']);
    define('DB_USER', $_ENV['DB_USER']);
    define('DB_PASSWORD', $_ENV['DB_PASSWORD']);
    define('DB_HOST', $_ENV['DB_HOST'] . ':' . $_ENV['DB_PORT']);
} else {
    // Local database config
    define('DB_NAME', getenv('DB_NAME') ?: 'wordpress');
    define('DB_USER', getenv('DB_USER') ?: 'wordpress');
    define('DB_PASSWORD', getenv('DB_PASSWORD') ?: 'wordpress');
    define('DB_HOST', getenv('DB_HOST') ?: 'database');
}

define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');
$table_prefix = getenv('DB_PREFIX') ?: 'wp_';

/**
 * Authentication Unique Keys and Salts
 * Generate new keys: https://api.wordpress.org/secret-key/1.1/salt/
 */
define('AUTH_KEY',         getenv('AUTH_KEY') ?: 'put your unique phrase here');
define('SECURE_AUTH_KEY',  getenv('SECURE_AUTH_KEY') ?: 'put your unique phrase here');
define('LOGGED_IN_KEY',    getenv('LOGGED_IN_KEY') ?: 'put your unique phrase here');
define('NONCE_KEY',        getenv('NONCE_KEY') ?: 'put your unique phrase here');
define('AUTH_SALT',        getenv('AUTH_SALT') ?: 'put your unique phrase here');
define('SECURE_AUTH_SALT', getenv('SECURE_AUTH_SALT') ?: 'put your unique phrase here');
define('LOGGED_IN_SALT',   getenv('LOGGED_IN_SALT') ?: 'put your unique phrase here');
define('NONCE_SALT',       getenv('NONCE_SALT') ?: 'put your unique phrase here');

/**
 * WordPress URLs
 */
if (isset($_SERVER['HTTP_HOST'])) {
    $protocol = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
    define('WP_HOME', $protocol . '://' . $_SERVER['HTTP_HOST']);
    define('WP_SITEURL', WP_HOME);
}

/**
 * Redis Object Cache (Pantheon and Local)
 */
if (isset($_ENV['PANTHEON_ENVIRONMENT'])) {
    // Pantheon Redis config
    define('WP_REDIS_CLIENT', 'pecl');
    define('WP_REDIS_HOST', $_ENV['CACHE_HOST']);
    define('WP_REDIS_PORT', $_ENV['CACHE_PORT']);
    define('WP_REDIS_PASSWORD', $_ENV['CACHE_PASSWORD']);
} else {
    // Local Redis config (Lando)
    define('WP_REDIS_HOST', getenv('REDIS_HOST') ?: 'cache');
    define('WP_REDIS_PORT', getenv('REDIS_PORT') ?: 6379);
}

/**
 * Debug Configuration
 */
if (WP_ENVIRONMENT_TYPE === 'local' || WP_ENVIRONMENT_TYPE === 'development') {
    define('WP_DEBUG', true);
    define('WP_DEBUG_LOG', true);
    define('WP_DEBUG_DISPLAY', false);
    define('SCRIPT_DEBUG', true);
    define('SAVEQUERIES', true);
    @ini_set('display_errors', 0);
} else {
    define('WP_DEBUG', false);
    define('WP_DEBUG_LOG', false);
    define('WP_DEBUG_DISPLAY', false);
}

/**
 * Security Hardening
 */
// Disable file editing in admin
define('DISALLOW_FILE_EDIT', true);

// Disable file modifications in production
if (WP_ENVIRONMENT_TYPE === 'production') {
    define('DISALLOW_FILE_MODS', true);
}

// Force SSL in admin (Pantheon handles SSL automatically)
if (isset($_ENV['PANTHEON_ENVIRONMENT']) || isset($_SERVER['HTTPS'])) {
    define('FORCE_SSL_ADMIN', true);
}

// Limit post revisions
define('WP_POST_REVISIONS', 10);

// Set autosave interval to 5 minutes
define('AUTOSAVE_INTERVAL', 300);

// Increase memory limit
define('WP_MEMORY_LIMIT', '256M');
define('WP_MAX_MEMORY_LIMIT', '512M');

/**
 * Pantheon-specific configurations
 */
if (isset($_ENV['PANTHEON_ENVIRONMENT'])) {
    // Pantheon Search (if using Solr)
    if (isset($_ENV['PANTHEON_INDEX_HOST'])) {
        define('PANTHEON_INDEX_HOST', $_ENV['PANTHEON_INDEX_HOST']);
        define('PANTHEON_INDEX_PORT', $_ENV['PANTHEON_INDEX_PORT']);
    }

    // Set filesystem method
    define('FS_METHOD', 'direct');
}

/**
 * Custom Content Directory (if using)
 */
// define('WP_CONTENT_DIR', dirname(__FILE__) . '/wp-content');
// define('WP_CONTENT_URL', WP_HOME . '/wp-content');

/**
 * Multisite (if needed)
 */
// define('WP_ALLOW_MULTISITE', true);
// define('MULTISITE', true);
// define('SUBDOMAIN_INSTALL', false);
// define('DOMAIN_CURRENT_SITE', 'example.com');
// define('PATH_CURRENT_SITE', '/');
// define('SITE_ID_CURRENT_SITE', 1);
// define('BLOG_ID_CURRENT_SITE', 1);

/**
 * Cron Configuration
 */
// Disable WP-Cron (if using system cron on Pantheon)
// define('DISABLE_WP_CRON', true);

/**
 * Cookie Configuration
 */
if (isset($_ENV['PANTHEON_ENVIRONMENT'])) {
    $pantheon_domain = $_ENV['PANTHEON_ENVIRONMENT'] . '-' . $_ENV['PANTHEON_SITE_NAME'] . '.pantheonsite.io';
    define('COOKIE_DOMAIN', $pantheon_domain);
}

/* That's all, stop editing! Happy publishing. */

/** Absolute path to the WordPress directory. */
if (!defined('ABSPATH')) {
    define('ABSPATH', __DIR__ . '/');
}

/** Sets up WordPress vars and included files. */
require_once ABSPATH . 'wp-settings.php';
