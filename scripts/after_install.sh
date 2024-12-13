#!/bin/bash

# Exit on error and unset variables
set -eu

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

# Initialize logging
touch $LOG_FILE
chmod 644 $LOG_FILE
log_message "Starting deployment on Amazon Linux 2023"

# Verify and extract application
if [ ! -f "${DEPLOYMENT_ROOT}/application.zip" ]; then
    log_message "ERROR: Deployment archive not found"
    exit 1
fi

unzip -q -o "${DEPLOYMENT_ROOT}/application.zip" -d $TEMP_DIR || {
    log_message "ERROR: Failed to extract archive"
    exit 1
}

# Verify essential files
for item in "web" "vendor" "composer.json"; do
    if [ ! -e "$TEMP_DIR/$item" ]; then
        log_message "ERROR: $item not found in deployment package"
        rm -rf $TEMP_DIR
        exit 1
    fi
done

# Backup settings if exists
if [ -f "$WEB_ROOT/sites/default/settings.php" ]; then
    cp "$WEB_ROOT/sites/default/settings.php" "/tmp/settings.php.backup"
fi

# Deploy files
rm -rf $WEB_ROOT/* $APP_ROOT/composer.* $APP_ROOT/vendor
mv $TEMP_DIR/web/* $WEB_ROOT/
mv $TEMP_DIR/vendor $APP_ROOT/
mv $TEMP_DIR/composer.* $APP_ROOT/
rm -rf $TEMP_DIR

# Restore or create settings
if [ -f "/tmp/settings.php.backup" ]; then
    mkdir -p "$WEB_ROOT/sites/default"
    mv "/tmp/settings.php.backup" "$WEB_ROOT/sites/default/settings.php"
elif [ -f "$WEB_ROOT/sites/default/default.settings.php" ]; then
    cp "$WEB_ROOT/sites/default/default.settings.php" "$WEB_ROOT/sites/default/settings.php"
fi

# Set up Drupal directories
mkdir -p $WEB_ROOT/sites/default/{files,private}

# AL2023 specific permissions
chown -R apache:apache $WEB_ROOT $APP_ROOT/vendor
find $WEB_ROOT -type d -exec chmod 755 {} \;
find $WEB_ROOT -type f -exec chmod 644 {} \;
chmod 775 $WEB_ROOT/sites/default/{files,private}
chmod 644 $WEB_ROOT/sites/default/settings.php
chmod 644 $APP_ROOT/composer.*

# Install dependencies with AL2023 specific settings
cd $APP_ROOT
if [ -f "composer.json" ]; then
    log_message "Installing Composer dependencies..."
    # Set environment variables for Composer
    export COMPOSER_ALLOW_SUPERUSER=1
    export COMPOSER_NO_INTERACTION=1
    export COMPOSER_MEMORY_LIMIT=-1
    
    # Run composer install with specific settings
    composer install \
        --no-dev \
        --no-interaction \
        --optimize-autoloader \
        --no-progress \
        --prefer-dist \
        --no-plugins || {
        log_message "ERROR: Composer installation failed"
        exit 1
    }
fi

# SELinux context handling
if command -v semanage >/dev/null 2>&1; then
    log_message "Setting SELinux context..."
    
    # Function to safely set SELinux context
    set_selinux_context() {
        local path=$1
        local context=$2
        
        # Check if context already exists
        if semanage fcontext -l | grep -q "^${path} "; then
            log_message "SELinux context already exists for ${path}, skipping..."
            return 0
        fi
        
        # Add new context if it doesn't exist
        semanage fcontext -a -t "$context" "$path" || {
            log_message "Warning: Failed to set context $context for $path"
            return 1
        }
    }
    
    # Set contexts safely
    set_selinux_context "$WEB_ROOT(/.*)?" "httpd_sys_content_t"
    set_selinux_context "$WEB_ROOT/sites/default/files(/.*)?" "httpd_sys_rw_content_t"
    set_selinux_context "$WEB_ROOT/sites/default/private(/.*)?" "httpd_sys_rw_content_t"
    
    # Restore contexts
    restorecon -Rv $WEB_ROOT || log_message "Warning: Failed to restore SELinux contexts"
fi

# Clear PHP opcache
echo '<?php opcache_reset();' | sudo -u apache php

# Get PHP-FPM service name and verify services
PHP_FPM_SERVICE=$(get_php_fpm_service)
log_message "Detected PHP-FPM service: $PHP_FPM_SERVICE"

# Restart services with error handling
for service in "$PHP_FPM_SERVICE" "httpd"; do
    log_message "Restarting $service..."
    if ! systemctl restart "$service"; then
        log_message "ERROR: Failed to restart $service"
        systemctl status "$service"
        exit 1
    fi
    
    # Verify service is running
    if ! systemctl is-active --quiet "$service"; then
        log_message "ERROR: $service failed to start"
        systemctl status "$service"
        exit 1
    fi
    log_message "$service restarted successfully"
done

# Clear Drupal cache if drush is available
if [ -f "$APP_ROOT/vendor/bin/drush" ]; then
    cd $WEB_ROOT
    log_message "Rebuilding Drupal cache..."
    if ! ../vendor/bin/drush cache:rebuild; then
        log_message "WARNING: Drupal cache rebuild failed"
    fi
fi

# Final verification
log_message "Verifying PHP-FPM service status..."
systemctl status "$PHP_FPM_SERVICE" || true
log_message "Verifying Apache service status..."
systemctl status httpd || true

log_message "Deployment completed successfully on Amazon Linux 2023"
