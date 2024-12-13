#!/bin/bash

# Exit on error
set -e

# Set variables
TEMP_DIR=$(mktemp -d)
DEPLOYMENT_ROOT="/opt/codedeploy-agent/deployment-root/$DEPLOYMENT_GROUP_ID/$DEPLOYMENT_ID/deployment-archive"
WEB_ROOT="/var/www/html"
APP_ROOT="/var/www"
LOG_FILE="/var/log/drupal_deploy.log"

# Function for logging
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

# Function to check directory structure
check_directory_structure() {
    local dir=$1
    if [ ! -d "$dir/web" ]; then
        log_message "ERROR: web directory not found in extracted files"
        exit 1
    fi
    if [ ! -d "$dir/vendor" ]; then
        log_message "ERROR: vendor directory not found in extracted files"
        exit 1
    fi
    if [ ! -f "$dir/composer.json" ]; then
        log_message "ERROR: composer.json not found in extracted files"
        exit 1
    fi
}

# Create log file
touch $LOG_FILE
chmod 644 $LOG_FILE

log_message "Starting deployment process"

# Verify deployment archive exists
if [ ! -f "${DEPLOYMENT_ROOT}/application.zip" ]; then
    log_message "ERROR: Deployment archive not found at ${DEPLOYMENT_ROOT}/application.zip"
    exit 1
fi

# Unzip the application to temp directory
log_message "Extracting application archive..."
unzip -q -o "${DEPLOYMENT_ROOT}/application.zip" -d $TEMP_DIR

# Debug: Show contents of temp directory
log_message "Extracted contents:"
ls -la $TEMP_DIR

# Verify directory structure
check_directory_structure $TEMP_DIR

# Backup current settings if they exist
if [ -f "$WEB_ROOT/sites/default/settings.php" ]; then
    log_message "Backing up existing settings.php..."
    cp "$WEB_ROOT/sites/default/settings.php" "/tmp/settings.php.backup"
fi

# Clean the destination directories
log_message "Cleaning destination directories..."
rm -rf $WEB_ROOT/*
rm -rf $APP_ROOT/composer.*
rm -rf $APP_ROOT/vendor

# Move files to their correct locations
log_message "Moving files to production locations..."
mv $TEMP_DIR/web/* $WEB_ROOT/
mv $TEMP_DIR/vendor $APP_ROOT/
mv $TEMP_DIR/composer.json $APP_ROOT/
mv $TEMP_DIR/composer.lock $APP_ROOT/ 2>/dev/null || true

# Restore settings if backup exists
if [ -f "/tmp/settings.php.backup" ]; then
    log_message "Restoring settings.php..."
    mkdir -p "$WEB_ROOT/sites/default"
    mv "/tmp/settings.php.backup" "$WEB_ROOT/sites/default/settings.php"
fi

# Clean up temp directory
log_message "Cleaning up temporary files..."
rm -rf $TEMP_DIR

# Set correct ownership and permissions
log_message "Setting file permissions..."
chown -R apache:apache $WEB_ROOT
chmod -R 755 $WEB_ROOT
chown -R apache:apache $APP_ROOT/vendor
chmod -R 755 $APP_ROOT/vendor
chown apache:apache $APP_ROOT/composer.*
chmod 644 $APP_ROOT/composer.*

# Debug: Show environment information
log_message "Environment Information:"
echo "PHP Version:"
php -v
echo "Current directory structure:"
ls -la $APP_ROOT
echo "Composer version:"
composer --version

# Install Drupal dependencies
cd $APP_ROOT
if [ -f "composer.json" ]; then
    log_message "Installing Composer dependencies..."
    COMPOSER_MEMORY_LIMIT=-1 composer install --no-dev --no-interaction --optimize-autoloader
fi

# Drupal specific setup
log_message "Setting up Drupal directories and permissions..."

# Create settings file if it doesn't exist
if [ ! -f "$WEB_ROOT/sites/default/settings.php" ]; then
    log_message "Creating settings.php..."
    cp $WEB_ROOT/sites/default/default.settings.php $WEB_ROOT/sites/default/settings.php
fi

# Set proper permissions for settings
chmod 644 $WEB_ROOT/sites/default/settings.php
chown apache:apache $WEB_ROOT/sites/default/settings.php

# Create and configure files directory
mkdir -p $WEB_ROOT/sites/default/files
chmod 775 $WEB_ROOT/sites/default/files
chown -R apache:apache $WEB_ROOT/sites/default/files

# Create and configure private files directory
mkdir -p $WEB_ROOT/sites/default/private
chmod 775 $WEB_ROOT/sites/default/private
chown -R apache:apache $WEB_ROOT/sites/default/private

# Set SELinux context if SELinux is enabled
if command -v semanage >/dev/null 2>&1; then
    log_message "Setting SELinux context..."
    semanage fcontext -a -t httpd_sys_content_t "$WEB_ROOT(/.*)?"
    semanage fcontext -a -t httpd_sys_rw_content_t "$WEB_ROOT/sites/default/files(/.*)?"
    semanage fcontext -a -t httpd_sys_rw_content_t "$WEB_ROOT/sites/default/private(/.*)?"
    restorecon -Rv $WEB_ROOT
fi

# Final permission adjustments
log_message "Setting final permissions..."
find $WEB_ROOT -type f -exec chmod 644 {} \;
find $WEB_ROOT -type d -exec chmod 755 {} \;
chmod 775 $WEB_ROOT/sites/default/files
chmod 775 $WEB_ROOT/sites/default/private

# Clear caches
if [ -f "$APP_ROOT/vendor/bin/drush" ]; then
    log_message "Clearing Drupal caches..."
    cd $WEB_ROOT
    ../vendor/bin/drush cache:rebuild
fi

# Function to get correct PHP-FPM service name
get_php_fpm_service() {
    if systemctl list-units --type=service | grep -q "php-fpm"; then
        echo "php-fpm"
    elif systemctl list-units --type=service | grep -q "php82-php-fpm"; then
        echo "php82-php-fpm"
    else
        log_message "ERROR: Could not determine PHP-FPM service name"
        exit 1
    fi
}


# Use the function when restarting services
PHP_FPM_SERVICE=$(get_php_fpm_service)
log_message "Restarting services..."
systemctl restart $PHP_FPM_SERVICE
systemctl restart httpd

# Final status check
log_message "Checking service status:"
echo "Apache status:"
systemctl status httpd
echo "PHP-FPM status:"
systemctl status $PHP_FPM_SERVICE

# Verify Drupal status if drush is available
if [ -f "$APP_ROOT/vendor/bin/drush" ]; then
    log_message "Checking Drupal status:"
    cd $WEB_ROOT
    ../vendor/bin/drush status
fi

log_message "Deployment completed successfully"
