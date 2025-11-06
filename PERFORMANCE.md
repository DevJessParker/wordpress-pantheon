# Performance Optimization Guide

This guide explains the performance optimizations in this WordPress + Pantheon development environment and how to achieve the fastest possible startup times.

## Expected Startup Times

### First Run (Initial Setup)
- **Expected Time**: 3-6 minutes
- **Why it takes time**:
  - Docker pulls base images (WordPress, MySQL, Redis, PhpMyAdmin)
  - System packages installed (vim, wget, WP-CLI)
  - Composer downloads and installs dependencies
  - WordPress core pulled from Pantheon
  - Database and files synced from Pantheon

### Subsequent Runs (After Initial Setup)
- **Expected Time**: 30-90 seconds
- **Why it's faster**:
  - Docker images cached locally
  - System packages already installed (skipped)
  - Composer dependencies cached (skipped if unchanged)
  - Containers reuse existing build layers

### Quick Start Mode
- **Expected Time**: < 10 seconds
- **How to use**: `sudo ./quickstart.sh --quick-start`
- **When to use**: When you know containers are healthy and just need to start them

## Built-in Optimizations

This setup includes several performance optimizations that run automatically:

### 1. Smart Container Orchestration
The quickstart script intelligently detects what needs to be done:
- **No changes**: Instant startup using existing running containers
- **Containers stopped**: Fast restart without rebuild (~30 seconds)
- **Config changed**: Full rebuild only when `.lando.yml` changes
- **First run**: Full build with progress indicators

### 2. Conditional Package Installation
System packages are only installed if missing:
```yaml
# Before: Always runs (60-120 seconds every rebuild)
- apt-get update -y
- apt-get install -y vim wget

# After: Only runs if packages missing (0 seconds when cached)
- if ! command -v vim >/dev/null 2>&1; then
    apt-get update -y && apt-get install -y vim wget
  fi
```

### 3. WP-CLI Caching
WP-CLI is only downloaded once and reused:
```yaml
# Only downloads if /usr/local/bin/wp doesn't exist
- if [ ! -f "/usr/local/bin/wp" ]; then
    curl -fsSL -o /usr/local/bin/wp https://...
  fi
```

### 4. Composer Dependency Caching
Composer dependencies are cached between rebuilds:
- `vendor/` directory persists in Docker volumes
- `COMPOSER_CACHE_DIR` set to preserve downloaded packages
- `--optimize-autoloader` flag for faster autoloading
- Dependencies only reinstalled if `composer.json` changes or vendor/ is missing

### 5. Build State Tracking
The `.lando-build-info` file tracks:
- Last successful build timestamp
- Hash of `.lando.yml` configuration
- Container state (running/stopped/missing)
- Enables intelligent decisions about when rebuilds are needed

## Command-Line Options

### Force Rebuild
```bash
sudo ./quickstart.sh --force
```
Forces a complete rebuild even if containers are healthy. Use when:
- Containers are corrupted
- You want to ensure a clean state
- Testing configuration changes

### Quick Start
```bash
sudo ./quickstart.sh --quick-start
```
Skips all health checks and assumes containers are healthy. Use when:
- You just stopped the environment and want to restart quickly
- You know containers are in good state
- You want absolute fastest startup time

### Skip Lando Installation
```bash
sudo ./quickstart.sh --skip-lando-install
```
Skips Lando installation checks. Use when:
- Lando is already installed
- You want to save 10-20 seconds during setup

## Troubleshooting Slow Startups

### If First Run Takes > 10 Minutes

**Common Causes:**
1. **Slow Internet Connection**
   - Docker images are large (500MB - 2GB total)
   - Composer packages can be 50-200MB
   - **Solution**: Use a faster internet connection or be patient

2. **Docker Desktop Resource Constraints**
   - Limited CPU or memory allocated to Docker
   - **Solution**:
     - Open Docker Desktop → Settings → Resources
     - Increase CPUs to 4+ and Memory to 4GB+
     - Restart Docker Desktop

3. **Slow Disk I/O**
   - Especially on older HDDs or heavily loaded SSDs
   - **Solution**:
     - Close other applications
     - Consider using SSD if on HDD
     - Check disk health

4. **Many Composer Dependencies**
   - Large WordPress projects with many plugins
   - **Solution**:
     - First run will be slow, subsequent runs cached
     - Consider using `composer install --prefer-dist` (already default)

### If Subsequent Runs Take > 2 Minutes

**This is abnormal.** Something is wrong:

1. **Containers Being Rebuilt Unnecessarily**
   - Check if `.lando.yml` is being modified
   - Check if `.lando-build-info` is being deleted
   - **Solution**: Don't modify `.lando.yml` between runs

2. **Docker Cache Issues**
   - Docker may not be caching layers properly
   - **Solution**:
     ```bash
     # Clean up Docker (WARNING: removes all unused Docker data)
     docker system prune -a --volumes

     # Then rebuild
     sudo ./quickstart.sh --force
     ```

3. **Composer Dependencies Reinstalling**
   - `vendor/` directory being deleted between runs
   - **Solution**: Check if `vendor/` exists and has `autoload.php`

4. **Docker Desktop Not Running Smoothly**
   - Background processes, updates, or resource issues
   - **Solution**:
     - Restart Docker Desktop completely
     - Check Docker Desktop logs for errors
     - Update Docker Desktop to latest version

### Performance Monitoring

Monitor what's taking time during startup:

```bash
# Time the startup
time sudo ./quickstart.sh --force

# Watch Docker container status
watch -n 1 'docker ps -a | grep wordpress-pantheon'

# Check Lando logs for slow operations
lando logs -f

# Monitor Docker resource usage
docker stats
```

## Advanced Optimizations

### 1. Pre-pull Docker Images
Speed up first run by pre-pulling images:
```bash
docker pull devwithlando/pantheon-appserver:7.4
docker pull mysql:8.0
docker pull redis:7
docker pull phpmyadmin/phpmyadmin
```

### 2. Use Docker BuildKit
Enable BuildKit for faster, more efficient builds:
```bash
# Add to ~/.bashrc or ~/.zshrc
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1
```

### 3. Optimize Composer
If you control `composer.json`, optimize dependencies:
```json
{
  "config": {
    "optimize-autoloader": true,
    "classmap-authoritative": true,
    "apcu-autoloader": true
  }
}
```

### 4. Reduce Services
If you don't need certain services, comment them out in `.lando.yml`:
```yaml
# services:
#   cache:
#     type: redis:7
#     portforward: true
#   pma:
#     type: phpmyadmin
```

**Caution**: Only do this if you know you don't need these services.

### 5. Use Faster DNS
Slow DNS can cause delays during package downloads:
```bash
# macOS
sudo networksetup -setdnsservers Wi-Fi 1.1.1.1 8.8.8.8

# Linux (edit /etc/resolv.conf)
nameserver 1.1.1.1
nameserver 8.8.8.8
```

## Performance Benchmarks

Typical performance on a modern machine (4-core CPU, 16GB RAM, SSD, 100Mbps internet):

| Operation | Expected Time | Notes |
|-----------|---------------|-------|
| First full setup | 3-4 minutes | Includes all downloads and builds |
| Force rebuild | 30-60 seconds | Most layers cached |
| Normal restart | 20-30 seconds | Just starting containers |
| Quick start | 5-10 seconds | No health checks |
| Stop | 5-10 seconds | Graceful shutdown |

## When to Rebuild vs. Restart

### Rebuild Required (use `--force`)
- Modified `.lando.yml` configuration
- Changed PHP version or service versions
- Corrupted containers
- Added new Composer dependencies
- System packages need updating

### Restart Sufficient (use `lando start`)
- Just stopped the environment
- Rebooted computer
- Docker Desktop restarted
- No configuration changes

### Neither Required (containers already running)
- Just want to access the site
- Run lando commands (wp, terminus, etc.)
- The script will detect this automatically

## Getting Help

If you're experiencing consistently slow performance (> 2 minutes for subsequent runs):

1. **Check Docker Desktop Health**
   - Look for warnings in Docker Desktop
   - Check CPU/Memory usage
   - Review Docker Desktop logs

2. **Check System Resources**
   ```bash
   # CPU usage
   top

   # Disk space
   df -h

   # Memory
   free -m  # Linux
   vm_stat  # macOS
   ```

3. **Clean Docker Cache**
   ```bash
   # Remove all stopped containers
   docker container prune

   # Remove unused images
   docker image prune

   # Remove unused volumes
   docker volume prune

   # Nuclear option (removes everything)
   docker system prune -a --volumes
   ```

4. **Reinstall Lando**
   - Sometimes Lando itself needs updating
   - Visit: https://docs.lando.dev/getting-started/installation.html

5. **Report Issue**
   - If issue persists, create a GitHub issue with:
     - System specs (CPU, RAM, OS version)
     - Docker Desktop version
     - Lando version
     - Time measurements for each step
     - Output of `lando logs`

---

**Remember**: The first run will always be slower (3-6 minutes). If subsequent runs take this long, something is wrong and needs troubleshooting.
