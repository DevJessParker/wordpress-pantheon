# Quick Reference Card

## 🚀 Essential Commands

### Environment Management
```bash
make start          # Start Lando
make stop           # Stop Lando
make restart        # Restart Lando
make rebuild        # Rebuild from scratch
```

### Data Sync
```bash
make pull-db        # Pull database from Pantheon Dev
make pull-files     # Pull files from Pantheon Dev
make pull           # Pull both database and files
make push-db        # Push database to Pantheon (⚠️ CAUTION)
```

### Development
```bash
make site           # Open site in browser
make pma            # Open PhpMyAdmin
make shell          # SSH into container
make logs           # View logs
```

### WordPress
```bash
lando wp plugin list
lando wp theme list
lando wp user list
lando wp cache flush
lando wp db export backup.sql
```

### Security & Quality
```bash
make security       # Run security checks
make phpcs          # Check code standards
make test           # Run all tests
make backup         # Backup local database
```

## 🌐 URLs

- **Site**: https://wordpress-pantheon.lndo.site
- **Admin**: https://wordpress-pantheon.lndo.site/wp-admin
- **PhpMyAdmin**: https://pma.wordpress-pantheon.lndo.site

## 📊 Database

### Local Database
- **Host**: database
- **Database**: wordpress
- **User**: wordpress
- **Password**: wordpress
- **Port**: 3306

### Access Database
```bash
lando mysql                    # MySQL CLI
lando mysql -e "SHOW TABLES"   # Run query
```

## 🔧 Terminus Commands

```bash
lando terminus env:list your-site
lando terminus backup:create your-site.dev
lando terminus env:clear-cache your-site.dev
lando terminus env:wake your-site.dev
lando terminus wp your-site.dev -- plugin list
```

## 🐞 Debugging

```bash
# View logs
lando logs -f

# Check WordPress debug log
tail -f wp-content/debug.log

# Check Lando info
lando info

# SSH into container
lando ssh

# Check Redis
lando redis-cli -h cache
```

## 🔒 Security Quick Checks

```bash
# Run security scan
lando security-check

# Check for updates
lando wp core check-update
lando wp plugin list --update=available
lando wp theme list --update=available

# Update everything
lando wp core update
lando wp plugin update --all
lando wp theme update --all
```

## 🚨 Troubleshooting

### Site won't load
```bash
lando rebuild -y
```

### Database issues
```bash
lando pull-db
```

### Terminus auth fails
```bash
lando terminus auth:login --machine-token=YOUR_TOKEN
```

### SSL errors
```bash
lando rebuild -y
```

### Port conflicts
```bash
lando stop
# Stop conflicting services (Apache, etc.)
lando start
```

## 📂 Important Files

| File | Purpose |
|------|---------|
| `.env` | Local environment variables |
| `.lando.yml` | Lando configuration |
| `pantheon.yml` | Pantheon platform config |
| `composer.json` | PHP dependencies |
| `Makefile` | Command shortcuts |

## 🔑 Environment Variables

Required in `.env`:
```bash
PANTHEON_SITE=your-site-name
PANTHEON_SITE_ID=your-site-uuid
TERMINUS_TOKEN=your-machine-token
```

## 🔄 Typical Workflow

```bash
# 1. Start your day
make start
make pull           # Get latest data

# 2. Develop
# Make your changes...

# 3. Test
make test
lando security-check

# 4. Commit
git add .
git commit -m "Your changes"
git push

# 5. Deploy automatically via CI/CD
```

## 📱 Pantheon Environments

| Env | URL | Auto-Deploy |
|-----|-----|-------------|
| Dev | dev-yoursite.pantheonsite.io | Yes |
| Test | test-yoursite.pantheonsite.io | Manual |
| Live | live-yoursite.pantheonsite.io | Manual |

## 🆘 Need Help?

```bash
make help           # Show all commands
lando               # Show Lando commands
lando wp help       # WP-CLI help
```

## 📚 Documentation

- [README.md](README.md) - Full documentation
- [SETUP.md](SETUP.md) - Setup guide
- [SECURITY.md](SECURITY.md) - Security practices
- [CONTRIBUTING.md](CONTRIBUTING.md) - How to contribute

---

**Pro Tip**: Use `make help` to see all available commands!
