.PHONY: help start stop restart pull-db pull-files pull sync-db backup clear-cache security logs shell

##############################################################################
# WordPress Pantheon Development Makefile
# Quick reference for common development tasks
##############################################################################

# Default target - show help
.DEFAULT_GOAL := help

help: ## Show this help message
	@echo "WordPress + Pantheon Development Commands"
	@echo "=========================================="
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Environment Management
start: ## Start the local development environment
	@echo "🚀 Starting Lando..."
	lando start

stop: ## Stop the local development environment
	@echo "🛑 Stopping Lando..."
	lando stop

restart: ## Restart the local development environment
	@echo "🔄 Restarting Lando..."
	lando restart

rebuild: ## Rebuild the local environment from scratch
	@echo "🔨 Rebuilding Lando..."
	lando rebuild -y

destroy: ## Destroy the local environment (removes database!)
	@echo "⚠️  This will destroy your local environment and database!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		lando destroy -y; \
	fi

# Data Sync Operations
pull-db: ## Pull database from Pantheon Dev
	@echo "📥 Pulling database from Pantheon Dev..."
	lando pull-db

pull-files: ## Pull files from Pantheon Dev
	@echo "📥 Pulling files from Pantheon Dev..."
	lando pull-files

pull: pull-db pull-files ## Pull both database and files from Pantheon Dev

sync-db: ## Sync database (creates backup on Pantheon first)
	@echo "🔄 Syncing database from Pantheon Dev..."
	lando sync-db

push-db: ## Push database to Pantheon Dev (⚠️ USE WITH CAUTION)
	@echo "⚠️  WARNING: This will overwrite the Pantheon Dev database!"
	@read -p "Are you sure? Type 'yes' to continue: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		lando push-db; \
	else \
		echo "Cancelled."; \
	fi

# Backup Operations
backup: ## Create local database backup
	@echo "💾 Creating local database backup..."
	lando backup-db
	@echo "✓ Backup saved to backups/"

backup-pantheon: ## Create backup on Pantheon Dev
	@echo "💾 Creating backup on Pantheon Dev..."
	lando terminus backup:create ${PANTHEON_SITE}.dev
	@echo "✓ Backup created on Pantheon"

# Cache Management
clear-cache: ## Clear all caches (WordPress + Redis)
	@echo "🧹 Clearing all caches..."
	lando clear-cache

# WordPress Operations
wp: ## Run WP-CLI command (usage: make wp cmd="plugin list")
	@lando wp $(cmd)

wp-update: ## Update WordPress core, plugins, and themes
	@echo "⬆️  Updating WordPress core, plugins, and themes..."
	lando wp core update
	lando wp plugin update --all
	lando wp theme update --all
	@echo "✓ Updates complete!"

wp-export: ## Export database to backups/
	@echo "📤 Exporting database..."
	@mkdir -p backups
	lando wp db export backups/export-$$(date +%Y%m%d-%H%M%S).sql
	@echo "✓ Database exported to backups/"

# Security & Quality
security: ## Run security checks
	@echo "🔒 Running security checks..."
	lando security-check

phpcs: ## Run PHP CodeSniffer
	@echo "🔍 Running PHP CodeSniffer..."
	lando composer phpcs

phpcbf: ## Fix PHP coding standards automatically
	@echo "🔧 Fixing PHP coding standards..."
	lando composer phpcbf

test: security phpcs ## Run all tests (security + code standards)

# Development Tools
logs: ## Show Lando logs
	lando logs -f

shell: ## Open shell in app container
	lando ssh

db-shell: ## Open MySQL shell
	lando mysql

redis-cli: ## Open Redis CLI
	lando redis-cli -h cache

pma: ## Open PhpMyAdmin in browser
	@echo "🌐 Opening PhpMyAdmin..."
	@echo "URL: https://pma.wordpress-pantheon.lndo.site"
	@which open > /dev/null && open https://pma.wordpress-pantheon.lndo.site || xdg-open https://pma.wordpress-pantheon.lndo.site || echo "Please visit: https://pma.wordpress-pantheon.lndo.site"

site: ## Open site in browser
	@echo "🌐 Opening site..."
	@which open > /dev/null && open https://wordpress-pantheon.lndo.site || xdg-open https://wordpress-pantheon.lndo.site || echo "Please visit: https://wordpress-pantheon.lndo.site"

# Setup & Configuration
setup: ## Initial setup (run after cloning)
	@echo "⚙️  Running initial setup..."
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "✓ Created .env file"; \
		echo "⚠️  Please edit .env and add your Pantheon credentials"; \
	else \
		echo "✓ .env file already exists"; \
	fi
	@echo ""
	@echo "Next steps:"
	@echo "1. Edit .env and add your Pantheon credentials"
	@echo "2. Update .lando.yml with your site details"
	@echo "3. Run 'make start' to start the environment"
	@echo "4. Run 'make pull' to sync data from Pantheon"

info: ## Show environment information
	@echo "Environment Information"
	@echo "======================"
	@echo ""
	@lando info

terminus: ## Run Terminus command (usage: make terminus cmd="env:list mysite")
	@lando terminus $(cmd)

# Git Operations
git-status: ## Show git status
	@git status

git-log: ## Show recent git commits
	@git log --oneline -10

# Clean up
clean: ## Clean up temporary files and caches
	@echo "🧹 Cleaning up..."
	@rm -rf backups/*.sql
	@rm -rf wp-content/cache/*
	@rm -rf tmp/*
	@echo "✓ Cleanup complete"

# Installation
install: setup start pull ## Complete installation (setup + start + pull data)
	@echo ""
	@echo "🎉 Installation complete!"
	@echo "Visit your site at: https://wordpress-pantheon.lndo.site"
