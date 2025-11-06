# WordPress + Pantheon Local Development Setup

A complete local development environment for WordPress on Pantheon, featuring database sync, CI/CD pipelines, and development tools.

## 🚀 Features

- **Lando** - Local development environment with Pantheon integration
- **PhpMyAdmin** - GUI database management
- **Redis** - Object caching (matches Pantheon production)
- **Terminus** - Pantheon CLI integration
- **Database Sync** - Easy sync between local and Pantheon Dev
- **CI/CD Pipelines** - Ready-to-use workflows for GitHub, GitLab, and Bitbucket
- **Security Tools** - Automated security scanning and best practices
- **Developer Scripts** - Common tasks automated
- **Performance Optimized** - Smart caching, 30-second restarts after initial build ([see PERFORMANCE.md](PERFORMANCE.md))

## 👥 For New Team Members

**Welcome to the team!** Follow these steps to get your local environment set up:

### Prerequisites

Before running the quickstart script, make sure you have:

1. ✅ **Docker Desktop** installed and **running**
   - [Download Docker Desktop](https://www.docker.com/products/docker-desktop)
   - Start Docker Desktop before proceeding

2. ✅ **Git** installed
   - [Download Git](https://git-scm.com/downloads)

3. ✅ **Pantheon Machine Token** ready
   - Get yours at: https://dashboard.pantheon.io/personal-settings/machine-tokens
   - Create a new token if you don't have one

4. ✅ **Administrator privileges**
   - **Windows**: Run PowerShell as Administrator
   - **macOS/Linux**: You'll need sudo access

5. ✅ **Windows Users: Git Line Ending Configuration** ⚠️
   - **IMPORTANT**: Before cloning, configure Git to preserve Unix line endings
   - This prevents shell script errors in Docker containers
   - Run this command once:
   ```powershell
   git config --global core.autocrlf input
   ```
   - **Why?** Windows Git defaults to converting line endings (LF → CRLF), which breaks shell scripts in Linux containers
   - The `.gitattributes` file in this repo enforces Unix line endings, but Git needs to be configured to respect it

### Team Quickstart

#### Windows Users - Choose Your Path

**Option 1: PowerShell (Easier for Windows users)**
```powershell
# 1. Clone the repository
git clone <your-repo-url>
cd wordpress-pantheon

# 2. Run the PowerShell quickstart script
# NOTE: Does NOT require Administrator - Lando install is separate
.\quickstart.ps1
```

**Option 2: WSL2 + Bash (5-10x Faster Performance!)**
```powershell
# 1. Open WSL2 (Ubuntu)
wsl

# 2. Clone in Linux filesystem (much faster!)
cd ~
git clone <your-repo-url>
cd wordpress-pantheon

# 3. Run bash script (requires sudo)
chmod +x quickstart.sh
sudo ./quickstart.sh
```

**Why WSL2 is faster:** Docker on Windows runs in WSL2. When files are on C: drive (NTFS), Docker translates through a filesystem layer. When files are in WSL2 (ext4), it's native Linux and **5-10x faster**!

**When prompted, provide:**
- Site Name: `your-site-name`
- Site UUID: Paste from Pantheon Dashboard (e.g., `https://dashboard.pantheon.io/sites/<uuid>`)
- Machine Token: Paste your token

#### macOS/Linux
```bash
# 1. Clone the repository
git clone <your-repo-url>
cd wordpress-pantheon

# 2. Run the quickstart script (with sudo!)
chmod +x quickstart.sh
sudo ./quickstart.sh
```

### What the Script Does

The quickstart script will automatically:
- ✅ Check for required software (Git, Docker)
- ✅ Install Lando automatically
- ✅ Configure your environment with guided prompts
- ✅ Authenticate with Pantheon
- ✅ Start your local environment
- ✅ Pull database and files from Pantheon Dev

**First-time setup takes 15-20 minutes.** Subsequent starts are much faster (< 1 minute).

### Access Your Local Site

Once setup completes, access:
- **WordPress Site**: https://wordpress-pantheon.lndo.site
- **Admin**: https://wordpress-pantheon.lndo.site/wp-admin (use Pantheon credentials)
- **PhpMyAdmin**: https://pma.wordpress-pantheon.lndo.site

**Accept the SSL warning** - this is normal for local development with self-signed certificates.

### ⚠️ Important: What NOT to Commit

**NEVER commit these files:**
- `.env` - Contains your personal tokens and credentials
- `wordpress/` - WordPress core (managed by Composer)
- `vendor/` - PHP dependencies (managed by Composer)
- `wp-content/uploads/` - Media files (synced from Pantheon)
- Any `.log` files

**Already tracked in `.gitignore`** - you're safe if you follow normal git workflows!

---

## ⚡ Quickstart (Automated Setup)

**The fastest way to get started!** Our automated setup scripts will install everything you need.

---

## 📋 Prerequisites (Manual Setup)

If you prefer manual setup or the quickstart script doesn't work:

### Required Software:
1. **Docker Desktop** - [Install Docker](https://www.docker.com/products/docker-desktop)
   - Required for Lando to work
   - Must be running before starting Lando

2. **Git** - [Install Git](https://git-scm.com/downloads)

3. **Lando** - [Install Lando](https://docs.lando.dev/getting-started/installation.html)
   - Supports macOS, Windows, and Linux
   - Terminus is installed automatically by Lando

### Pantheon Account:
1. Sign up at [Pantheon.io](https://pantheon.io)
2. Create a WordPress site
3. Generate a machine token: https://dashboard.pantheon.io/users/#account/tokens

## 🛠️ Manual Setup

### 1. Clone the Repository
```bash
git clone <your-repo-url>
cd wordpress-pantheon
```

### 2. Configure Environment
```bash
# Copy the environment template
cp .env.example .env

# Edit .env and add your Pantheon details
nano .env
```

Required values in `.env`:
```bash
PANTHEON_SITE=your-site-name
PANTHEON_SITE_ID=your-site-uuid
TERMINUS_TOKEN=your-machine-token
```

### 3. Update Lando Configuration
Edit `.lando.yml` and update:
```yaml
config:
  site: your-site-name
  id: your-site-uuid
```

### 4. Start Lando
```bash
lando start
```

This will:
- Build your local environment
- Install WordPress
- Set up the database
- Configure Redis caching
- Install PhpMyAdmin

### 5. Authenticate with Terminus
```bash
lando terminus auth:login --machine-token=YOUR_TOKEN
```

### 6. Pull Database and Files from Pantheon
```bash
# Pull database from Pantheon Dev
lando pull-db

# Pull uploaded files
lando pull-files
```

### 7. Access Your Site
- **WordPress Site**: https://wordpress-pantheon.lndo.site
- **PhpMyAdmin**: https://pma.wordpress-pantheon.lndo.site
- **Admin Login**: Use your Pantheon credentials

## 🎮 Available Commands

### Database Operations
```bash
# Pull database from Pantheon Dev
lando pull-db

# Push database to Pantheon Dev (⚠️ USE WITH CAUTION)
lando push-db

# Sync database (creates backup first)
lando sync-db

# Backup local database
lando backup-db
```

### File Operations
```bash
# Pull files (wp-content/uploads) from Pantheon
lando pull-files
```

### Cache Management
```bash
# Clear all caches (WordPress + Redis)
lando clear-cache
```

### WordPress CLI
```bash
# Run any WP-CLI command
lando wp plugin list
lando wp user list
lando wp db export backup.sql

# Examples:
lando wp search-replace 'oldurl.com' 'newurl.com'
lando wp plugin install akismet --activate
lando wp theme activate twentytwentyfour
```

### Terminus Commands
```bash
# Run Terminus commands
lando terminus env:list your-site
lando terminus backup:create your-site.dev
lando terminus env:clear-cache your-site.dev
```

### Security
```bash
# Run security checks
lando security-check
```

### Composer & Development
```bash
# Install PHP dependencies
lando composer install

# Update dependencies
lando composer update
```

## 📁 Project Structure

```
wordpress-pantheon/
├── .github/
│   └── workflows/
│       └── deploy-to-pantheon.yml    # GitHub Actions CI/CD
├── .gitlab-ci.yml                    # GitLab CI/CD
├── bitbucket-pipelines.yml           # Bitbucket CI/CD
├── private/
│   └── scripts/                      # Pantheon Quicksilver scripts
│       ├── clear_cache.php
│       ├── sanitize_db.php
│       └── warm_cache.php
├── scripts/
│   ├── pull-db.sh                    # Database sync scripts
│   ├── push-db.sh
│   ├── pull-files.sh
│   └── security-check.sh
├── wp-content/                       # WordPress content
│   ├── plugins/
│   ├── themes/
│   └── uploads/
├── .env.example                      # Environment template
├── .gitignore
├── .lando.yml                        # Lando configuration
├── pantheon.yml                      # Pantheon platform config
├── README.md
└── SECURITY.md                       # Security best practices
```

## 🔄 Development Workflow

### Daily Team Workflow

**Start of Day:**
```bash
# 1. Make sure Docker Desktop is running

# 2. Pull latest code
git pull origin main

# 3. Start Lando
lando start

# 4. Sync latest database from Pantheon Dev
lando pull-db

# 5. (Optional) Sync latest uploads/media
lando pull-files
```

**During Development:**
```bash
# Edit files in your IDE (VS Code, PhpStorm, etc.)
# Files are in: wp-content/themes/ and wp-content/plugins/

# Test your changes
# Browser: https://wordpress-pantheon.lndo.site

# Check for issues
lando wp core verify-checksums
lando security-check
```

**End of Day:**
```bash
# 1. Commit your changes
git add .
git commit -m "Feature: Description of your changes"

# 2. Push to your branch
git push origin your-branch-name

# 3. Stop Lando (saves resources)
lando stop
```

**Next Morning:**
```bash
# Just start where you left off
lando start
# Your database and files are still there!
```

### 1. Daily Development (Old Format)
```bash
# Start your day
lando start
lando pull-db        # Sync latest data
lando pull-files     # Sync latest uploads

# Make your changes...

# Test your changes
lando wp core verify-checksums
lando security-check

# Commit and push
git add .
git commit -m "Your changes"
git push origin your-branch
```

### 2. Database Workflow

**⚠️ Important: Data Flow Direction**

```
Production/Test → Dev → Local (PULL - Safe ✅)
Local → Dev (PUSH - Use Caution ⚠️)
```

**Best Practice:**
- Always pull from Pantheon to local
- Only push to Dev environment for testing
- Use Pantheon dashboard for Test/Live deployments

### 3. Deployment Workflow

```bash
# 1. Develop locally
lando start
# Make changes...

# 2. Commit to git
git add .
git commit -m "Feature: Add new functionality"
git push origin main

# 3. CI/CD automatically deploys to Pantheon Dev

# 4. Test on Dev environment
# Visit: https://dev-yoursite.pantheonsite.io

# 5. Deploy to Test (via Pantheon Dashboard or CI/CD)
terminus env:deploy yoursite.test

# 6. Deploy to Live (via Pantheon Dashboard)
terminus env:deploy yoursite.live
```

## 🌍 Environments

| Environment | URL | Purpose | Auto-Deploy |
|-------------|-----|---------|-------------|
| Local | https://wordpress-pantheon.lndo.site | Development | N/A |
| Dev | https://dev-yoursite.pantheonsite.io | Development | Yes (on git push) |
| Test | https://test-yoursite.pantheonsite.io | Staging | Manual |
| Live | https://live-yoursite.pantheonsite.io | Production | Manual |

## 🔐 CI/CD Setup

### GitHub Actions
1. Go to: **Settings → Secrets and variables → Actions**
2. Add these secrets:
   - `PANTHEON_SSH_KEY` - Your SSH private key
   - `TERMINUS_TOKEN` - Your Terminus machine token
   - `PANTHEON_SITE_NAME` - Your site name
   - `PANTHEON_SITE_ID` - Your site UUID

### GitLab CI
1. Go to: **Settings → CI/CD → Variables**
2. Add the same variables as above (mark as masked)

### Bitbucket Pipelines
1. Go to: **Repository settings → Pipelines → Repository variables**
2. Add the same variables (mark as secured)

See [SECURITY.md](SECURITY.md) for detailed setup instructions.

## 🐛 Troubleshooting

### Common Team Issues

#### **Windows**: "Script not found" or "$'\r': command not found" errors

**Cause**: Windows Git converted Unix line endings (LF) to Windows line endings (CRLF) when you cloned the repository. Linux containers can't execute shell scripts with CRLF line endings.

**Symptoms**:
```
/bin/sh: 1: /app/scripts/pull-db.sh: not found
/app/scripts/pull-db.sh: line 2: $'\r': command not found
```

**Fix** (choose one):

**Option 1 - If you haven't cloned yet (BEST)**:
```powershell
# Configure Git BEFORE cloning
git config --global core.autocrlf input
git clone <repo-url>
```

**Option 2 - Already cloned? Re-normalize files**:
```powershell
# Configure Git
git config core.autocrlf input

# Re-checkout files with correct line endings
git rm --cached -r .
git reset --hard HEAD

# Verify scripts work
lando pull-db
```

**Why this happens**: Windows Git's default `core.autocrlf=true` converts line endings to CRLF on checkout. The `.gitattributes` file in this repo prevents this, but only if Git is configured to respect it.

#### "Terminus keeps asking for my machine token"

**Cause**: The `TERMINUS_TOKEN` in your `.env` file is missing, invalid, has Windows line endings (CRLF), or not being loaded correctly.

**Symptoms**:
```
? Enter a Pantheon machine token [hidden]
ERROR ==> POST request to authorize/machine-token failed with code 400
```

**Fix**:
1. **Check your `.env` file exists and has the token**:
   ```bash
   # Verify .env file exists
   cat .env | grep TERMINUS_TOKEN

   # Should show: TERMINUS_TOKEN=your-actual-token-here
   ```

2. **Windows Users: Fix line endings** (MOST COMMON ISSUE):
   ```powershell
   # Remove Windows carriage returns (CRLF → LF)
   (Get-Content .env -Raw) -replace "`r`n", "`n" | Set-Content .env -NoNewline

   # Verify it's fixed - should NOT see "13" at the end
   (Get-Content .env -Raw).Split("`n") | ForEach-Object {
       if ($_ -match "TERMINUS_TOKEN") {
           $_.ToCharArray() | ForEach-Object { [int][char]$_ }
       }
   }
   ```

   **Why this happens**: Windows text editors add carriage return characters (`\r`) that break the token. Your token becomes `abc123\r` instead of `abc123`, making it invalid.

3. **Get a new machine token if needed**:
   - Visit: https://dashboard.pantheon.io/personal-settings/machine-tokens
   - Click "Create Token"
   - Copy the token
   - Update `.env` with: `TERMINUS_TOKEN=your-new-token`

4. **Verify token format**:
   - Token should be a long alphanumeric string
   - No quotes or spaces around the token
   - No extra characters or line breaks
   - Example: `TERMINUS_TOKEN=abc123xyz789def456...`

5. **Re-run setup**:
   ```bash
   sudo ./quickstart.sh
   ```

**Why this happens**: The quickstart script and `lando pull` command read `TERMINUS_TOKEN` from your `.env` file. Windows line endings (CRLF) add invisible carriage return characters that break authentication. The script now automatically strips these, but it's best to fix your `.env` file.

**Prevention**:
- Use an editor that supports Unix line endings (VS Code, Notepad++, etc.)
- Configure Git to preserve line endings: `git config --global core.autocrlf input`
- Or use the PowerShell command above to fix existing files

#### "I see a 404 error when I visit the site"

**Cause**: WordPress isn't installed yet or Composer is still running.

**Fix**:
```bash
# Check if WordPress core is installed
Test-Path ".\wordpress\index.php"  # Windows
ls wordpress/index.php              # macOS/Linux

# If false, install dependencies
lando composer install --no-dev

# Pull database
lando pull-db

# Restart
lando restart
```

#### "Composer installation is taking forever"

**Cause**: `php_codesniffer` is a large package (1000+ files) and slow to extract in Docker.

**Fix**: Install without dev dependencies (you don't need code standards to run the site):
```bash
# Cancel the current install (Ctrl+C)
lando composer install --no-dev

# Later, install dev tools when you have time
lando composer install
```

#### "The site works but I can't log in"

**Cause**: You need to pull the database from Pantheon.

**Fix**:
```bash
lando pull-db
# Use your Pantheon Dev credentials to log in
```

#### "I got a merge conflict in .env"

**Cause**: `.env` shouldn't be in git!

**Fix**:
```bash
# .env should already be in .gitignore
# If you accidentally committed it:
git rm --cached .env
git commit -m "Remove .env from git"

# Each team member has their own .env
# Copy from .env.example and configure with your own token
```

#### "Docker says port is already in use"

**Cause**: Another container or service is using port 80/443.

**Fix**:
```bash
# Stop other Lando projects
lando poweroff

# Or restart Docker Desktop
```

#### "I updated the .lando.yml but nothing changed"

**Cause**: Lando needs to rebuild when config changes.

**Fix**:
```bash
lando rebuild -y
```

### Lando won't start
```bash
# Rebuild Lando
lando rebuild -y

# Or destroy and start fresh
lando destroy
lando start
```

### Database sync fails
```bash
# Verify Terminus authentication
lando terminus auth:whoami

# Re-authenticate if needed
lando terminus auth:login --machine-token=YOUR_TOKEN
```

### SSL Certificate errors
```bash
# Rebuild Lando certificates
lando rebuild -y
```

### "Table doesn't exist" errors
```bash
# Re-pull the database
lando pull-db
```

### Permission errors
```bash
# Fix file permissions
lando ssh
chown -R www-data:www-data /app/wp-content/
```

### Still Having Issues?

**Check these first:**
1. ✅ Is Docker Desktop running?
2. ✅ Did you run the quickstart script as Administrator/sudo?
3. ✅ Did you pull the latest code? (`git pull origin main`)
4. ✅ Try: `lando rebuild -y`

**Ask the team** - Someone else probably hit the same issue!

## 📚 Documentation

### Project Documentation
- [PERFORMANCE.md](PERFORMANCE.md) - Performance optimization guide and troubleshooting
- [SECURITY.md](SECURITY.md) - Security best practices

### External Documentation
- [Lando Documentation](https://docs.lando.dev/)
- [Pantheon Documentation](https://pantheon.io/docs)
- [Terminus Documentation](https://pantheon.io/docs/terminus)
- [WordPress Documentation](https://wordpress.org/documentation/)
- [WP-CLI Commands](https://developer.wordpress.org/cli/commands/)

## 🔒 Security

See [SECURITY.md](SECURITY.md) for comprehensive security best practices.

Key points:
- Never commit `.env` files
- Use strong passwords and 2FA
- Keep WordPress, plugins, and themes updated
- Run `lando security-check` regularly
- Review [Pantheon's Security Documentation](https://pantheon.io/security)

## 🆘 Getting Help

### Pantheon Support
- Dashboard: https://dashboard.pantheon.io/support
- Docs: https://pantheon.io/docs
- Community: https://discuss.pantheon.io/

### Lando Support
- Docs: https://docs.lando.dev/
- GitHub: https://github.com/lando/lando/issues
- Slack: https://launchpass.com/devwithlando

### WordPress Support
- Forums: https://wordpress.org/support/
- Stack Exchange: https://wordpress.stackexchange.com/

## 📝 License

This project setup is MIT licensed. WordPress core is GPLv2 licensed.

## 🙏 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

**Happy Coding! 🎉**
