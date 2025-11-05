# Complete Setup Guide

This guide will walk you through setting up your local WordPress development environment with Pantheon integration.

## ⚡ Quickstart (Recommended)

**Want to skip manual setup?** Use our automated quickstart scripts!

### Windows Users
```powershell
# Navigate to the project directory
cd wordpress-pantheon

# Run the quickstart script
.\quickstart.ps1

# For help
.\quickstart.ps1 -Help
```

### macOS/Linux Users
```bash
# Navigate to the project directory
cd wordpress-pantheon

# Run the quickstart script
./quickstart.sh

# For help
./quickstart.sh --help
```

The quickstart script handles everything automatically:
- Checks for prerequisites
- Installs Lando (if needed)
- Configures your environment
- Authenticates with Pantheon
- Starts the development environment
- Pulls your database and files

**If the quickstart script works, you're done!** Skip to the [Next Steps](#-next-steps) section.

---

## 📋 Manual Setup Prerequisites

If you prefer manual setup or the quickstart script doesn't work:

### Prerequisites Checklist

Before starting, ensure you have:

- [ ] **Docker Desktop** installed and running ([Download](https://www.docker.com/products/docker-desktop))
- [ ] **Git** installed ([Download](https://git-scm.com/downloads))
- [ ] **Lando** installed ([Download](https://docs.lando.dev/getting-started/installation.html))
- [ ] **Pantheon account** with a WordPress site created
- [ ] **Terminus machine token** generated
- [ ] **Basic terminal/command line knowledge**

## 🚀 Step-by-Step Setup

### Step 1: Install Lando

**macOS:**
```bash
# Download and install from:
https://docs.lando.dev/getting-started/installation.html#macos
```

**Windows:**
```bash
# Download and install from:
https://docs.lando.dev/getting-started/installation.html#windows
```

**Linux:**
```bash
# Download and install from:
https://docs.lando.dev/getting-started/installation.html#linux
```

Verify installation:
```bash
lando version
```

### Step 2: Get Pantheon Credentials

1. **Log in to Pantheon Dashboard:**
   - Go to https://dashboard.pantheon.io

2. **Find Your Site Information:**
   - Navigate to your WordPress site
   - Note your **Site Name** (e.g., "my-awesome-site")
   - Find your **Site UUID** in Site Settings → About

3. **Generate Machine Token:**
   - Click your username → Account → Machine Tokens
   - Or visit: https://dashboard.pantheon.io/users/#account/tokens
   - Click "Create Token"
   - Give it a name (e.g., "Local Development")
   - Save the token somewhere secure

4. **Get SSH Key:**
   ```bash
   # If you don't have an SSH key, generate one:
   ssh-keygen -t rsa -b 4096 -C "your-email@example.com"

   # Add your SSH key to Pantheon:
   # Dashboard → Account → SSH Keys → Add Key
   cat ~/.ssh/id_rsa.pub
   ```

### Step 3: Clone and Configure

```bash
# 1. Clone the repository
git clone <your-repo-url>
cd wordpress-pantheon

# 2. Run setup (creates .env file)
make setup
# Or manually:
cp .env.example .env

# 3. Edit .env file
nano .env  # or use your preferred editor
```

**Fill in these values in `.env`:**
```bash
PANTHEON_SITE=your-site-name
PANTHEON_SITE_ID=your-site-uuid
TERMINUS_TOKEN=your-machine-token
```

### Step 4: Configure Lando

Edit `.lando.yml` and update these lines:
```yaml
config:
  site: your-site-name
  id: your-site-uuid
```

**Find these values:**
- **Site Name**: Visible in Pantheon dashboard URL
  - Example: `dashboard.pantheon.io/sites/YOUR-SITE-NAME`
- **Site UUID**: Settings → About → Site ID
  - Example: `12345678-1234-1234-1234-123456789abc`

### Step 5: Start Your Environment

```bash
# Start Lando
make start
# Or:
lando start
```

**This will:**
- Build Docker containers
- Install WordPress
- Set up MySQL database
- Configure Redis cache
- Install PhpMyAdmin
- Set up SSL certificates

**First start takes 5-10 minutes.**

### Step 6: Authenticate with Terminus

```bash
# Login to Terminus
lando terminus auth:login --machine-token=YOUR_TOKEN

# Verify authentication
lando terminus auth:whoami
```

### Step 7: Pull Data from Pantheon

```bash
# Pull database from Pantheon Dev
make pull-db
# Or:
lando pull-db

# Pull uploaded files
make pull-files
# Or:
lando pull-files

# Or pull both at once
make pull
```

### Step 8: Access Your Site

Open your browser and visit:
- **WordPress Site**: https://wordpress-pantheon.lndo.site
- **PhpMyAdmin**: https://pma.wordpress-pantheon.lndo.site

**Login credentials:** Same as your Pantheon site

## 🎯 Quick Start Commands

```bash
# Start development
make start

# Pull latest data
make pull

# Open site in browser
make site

# Open PhpMyAdmin
make pma

# View all commands
make help
```

## ⚙️ CI/CD Setup (Optional)

If you want automatic deployments:

### GitHub Actions

1. Go to your GitHub repository
2. Navigate to: **Settings → Secrets and variables → Actions**
3. Add these secrets:

| Secret Name | Value | Where to Find |
|------------|-------|---------------|
| `TERMINUS_TOKEN` | Your machine token | Pantheon Dashboard → Account → Machine Tokens |
| `PANTHEON_SITE_NAME` | Your site name | Pantheon Dashboard (e.g., "my-site") |
| `PANTHEON_SITE_ID` | Your site UUID | Pantheon Settings → About → Site ID |
| `PANTHEON_SSH_KEY` | Your private SSH key | `cat ~/.ssh/id_rsa` |

4. Push to `main` branch to trigger deployment

### GitLab CI

1. Go to: **Settings → CI/CD → Variables**
2. Add the same secrets as above
3. Mark each as "Masked" and "Protected"

### Bitbucket Pipelines

1. Go to: **Repository settings → Pipelines → Repository variables**
2. Add the same secrets as above
3. Mark as "Secured"

## 🔍 Verify Setup

Run these commands to verify everything is working:

```bash
# Check Lando status
lando info

# Check WordPress
lando wp --info

# Check Terminus
lando terminus auth:whoami

# Run security check
make security

# Check database connection
lando mysql -e "SHOW DATABASES;"
```

## 🐛 Common Issues

### Issue: Lando won't start

**Solution:**
```bash
# Check Docker is running
docker ps

# Rebuild Lando
lando rebuild -y

# Or start fresh
lando destroy
lando start
```

### Issue: Can't connect to Pantheon

**Solution:**
```bash
# Re-authenticate
lando terminus auth:login --machine-token=YOUR_TOKEN

# Check SSH key
ssh-add -l

# Add SSH key if needed
ssh-add ~/.ssh/id_rsa
```

### Issue: Database pull fails

**Solution:**
```bash
# Check Terminus authentication
lando terminus auth:whoami

# Wake Pantheon environment
lando terminus env:wake your-site.dev

# Try again
lando pull-db
```

### Issue: SSL certificate errors

**Solution:**
```bash
# Rebuild Lando to regenerate certificates
lando rebuild -y

# Trust the certificate (macOS)
lando info
# Find the cert location and trust it in Keychain Access
```

### Issue: Port conflicts

**Solution:**
```bash
# Check what's using port 80/443
lsof -i :80
lsof -i :443

# Stop conflicting services
sudo apachectl stop
# Or change ports in .lando.yml
```

## 📚 Next Steps

Now that you're set up:

1. **Read the documentation:**
   - [README.md](README.md) - Overview and commands
   - [SECURITY.md](SECURITY.md) - Security best practices

2. **Learn the workflow:**
   - [Development Workflow](README.md#-development-workflow)
   - [Deployment Process](README.md#-deployment-workflow)

3. **Explore available commands:**
   ```bash
   make help
   lando
   ```

4. **Start developing:**
   - Edit themes in `wp-content/themes/`
   - Add plugins to `wp-content/plugins/`
   - Commit changes to git
   - Push to deploy

## 🆘 Getting Help

If you're stuck:

1. **Check the docs:**
   - [Lando Docs](https://docs.lando.dev/)
   - [Pantheon Docs](https://pantheon.io/docs)
   - [Terminus Docs](https://pantheon.io/docs/terminus)

2. **Search for errors:**
   - Check Lando logs: `lando logs`
   - Check WordPress debug log: `wp-content/debug.log`

3. **Ask for help:**
   - Lando Slack: https://launchpass.com/devwithlando
   - Pantheon Support: https://dashboard.pantheon.io/support
   - WordPress Forums: https://wordpress.org/support/

4. **File an issue:**
   - GitHub Issues (this repo)
   - Include logs and error messages

## ✅ Setup Complete!

You're all set! Start developing with:

```bash
make start
make site
```

Happy coding! 🎉
