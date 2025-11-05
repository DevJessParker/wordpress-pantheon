# Security Best Practices

This document outlines security best practices for WordPress + Pantheon development.

## 🔐 Environment Variables & Secrets

### Never Commit Secrets
- ✅ Use `.env` files for local secrets (already in `.gitignore`)
- ✅ Use CI/CD secret management for deployment keys
- ❌ Never commit `.env` files or credentials to git

### Required Secrets

#### For CI/CD (GitHub/GitLab/Bitbucket):
1. **PANTHEON_SSH_KEY**: Your Pantheon SSH private key
2. **TERMINUS_TOKEN**: Pantheon machine token (generate at: https://dashboard.pantheon.io/users/#account/tokens)
3. **PANTHEON_SITE_NAME**: Your Pantheon site name
4. **PANTHEON_SITE_ID**: Your Pantheon site UUID

### How to Add Secrets:

**GitHub:**
```bash
Settings → Secrets and variables → Actions → New repository secret
```

**GitLab:**
```bash
Settings → CI/CD → Variables → Add Variable (mark as masked)
```

**Bitbucket:**
```bash
Repository settings → Pipelines → Repository variables → Add variable (secured)
```

## 🔒 WordPress Security Hardening

### 1. Strong Authentication
```bash
# Generate strong salts
wp config shuffle-salts

# Enforce strong passwords
wp plugin install better-wp-security --activate
```

### 2. File Permissions
Pantheon automatically sets correct permissions. For local:
```bash
chmod 644 wp-config.php
chmod 755 wp-content/
chmod 755 wp-content/themes/
chmod 755 wp-content/plugins/
```

### 3. Disable File Editing
Add to `wp-config.php`:
```php
define('DISALLOW_FILE_EDIT', true);
define('DISALLOW_FILE_MODS', true); // Production only
```

### 4. Hide WordPress Version
Add to theme's `functions.php`:
```php
remove_action('wp_head', 'wp_generator');
```

### 5. Security Headers
Pantheon automatically adds:
- X-Frame-Options
- X-Content-Type-Options
- Strict-Transport-Security (HSTS)

### 6. Regular Updates
```bash
# Check for updates
lando wp core check-update
lando wp plugin list --update=available
lando wp theme list --update=available

# Update (test on Dev first!)
lando wp core update
lando wp plugin update --all
lando wp theme update --all
```

## 🛡️ Database Security

### Production Database Access
- ✅ Only access via Terminus or Pantheon Dashboard
- ✅ Use read-only connections when possible
- ❌ Never expose database ports publicly

### Database Backups
Pantheon automatically creates backups:
- Daily backups on all environments
- Retained for 7 days (configurable)

Manual backup:
```bash
terminus backup:create your-site.env --element=db
```

### Sanitizing Data
When pulling production data to dev:
```bash
# Anonymize user data
lando wp user list --role=subscriber --field=ID | xargs -I % lando wp user update % --user_email=%@example.com

# Clear sensitive transients
lando wp transient delete --all
```

## 🔍 Security Scanning

### Automated Security Scans
Our CI/CD pipeline includes:
1. **Trivy** - Container and filesystem vulnerability scanning
2. **Composer Audit** - PHP dependency vulnerability checks
3. **WordPress Core/Plugin Updates** - Automated update checks

### Manual Security Checks
```bash
# Run security check script
lando security-check

# Check plugin vulnerabilities
lando wp plugin verify-checksums --all

# Check core files
lando wp core verify-checksums
```

### Regular Security Audits
1. Review user accounts quarterly
2. Audit installed plugins/themes monthly
3. Check security logs weekly
4. Update WordPress core/plugins immediately for security releases

## 🚨 Security Incident Response

### If Compromised:
1. **Immediate Actions:**
   ```bash
   # Lock down the site
   terminus lock:enable your-site.env

   # Force logout all users
   lando wp user session destroy --all

   # Change all passwords
   wp user update admin --user_pass=NEW_STRONG_PASSWORD

   # Regenerate salts
   wp config shuffle-salts
   ```

2. **Investigation:**
   - Check Pantheon logs: `terminus logs:list your-site.env`
   - Review recent file changes: `git log --all --stat`
   - Scan for malware: Use Wordfence or Sucuri plugins

3. **Recovery:**
   - Restore from clean backup
   - Update all credentials
   - Patch vulnerabilities
   - Monitor for 30 days

## 📋 Security Checklist

### Initial Setup:
- [ ] Generate strong WordPress salts
- [ ] Set up 2FA for Pantheon account
- [ ] Configure CI/CD secrets
- [ ] Enable HTTPS (automatic on Pantheon)
- [ ] Set up security monitoring

### Monthly:
- [ ] Update WordPress core
- [ ] Update all plugins and themes
- [ ] Review user accounts and permissions
- [ ] Check for failed login attempts
- [ ] Review security scan results

### Quarterly:
- [ ] Audit installed plugins (remove unused)
- [ ] Review and rotate API keys
- [ ] Test backup restoration
- [ ] Security training for team

## 📚 Additional Resources

- [Pantheon Security](https://pantheon.io/security)
- [WordPress Security Whitepaper](https://wordpress.org/about/security/)
- [OWASP WordPress Security Guide](https://owasp.org/www-project-web-security-testing-guide/)
- [WPScan Vulnerability Database](https://wpscan.com/wordpresses)

## 🆘 Security Contact

For security issues, contact:
- Pantheon Support: https://dashboard.pantheon.io/support
- WordPress Security Team: security@wordpress.org
