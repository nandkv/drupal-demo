#!/bin/bash

# Set variables
TEMP_DIR=$(mktemp -d)
DEPLOYMENT_ROOT="/opt/codedeploy-agent/deployment-root/$DEPLOYMENT_GROUP_ID/$DEPLOYMENT_ID/deployment-archive"
WEB_ROOT="/var/www/html"
APP_ROOT="/var/www"

# Extract application
unzip -q -o "${DEPLOYMENT_ROOT}/application.zip" -d $TEMP_DIR

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

# Restore settings
if [ -f "/tmp/settings.php.backup" ]; then
    mkdir -p "$WEB_ROOT/sites/default"
    mv "/tmp/settings.php.backup" "$WEB_ROOT/sites/default/settings.php"
fi

# Set up Drupal directories and permissions
mkdir -p $WEB_ROOT/sites/default/{files,private}
chown -R apache:apache $WEB_ROOT $APP_ROOT/vendor
find $WEB_ROOT -type d -exec chmod 755 {} \;
find $WEB_ROOT -type f -exec chmod 644 {} \;
chmod 775 $WEB_ROOT/sites/default/{files,private}
chmod 644 $WEB_ROOT/sites/default/settings.php
chmod 644 $APP_ROOT/composer.*

# Install dependencies
cd $APP_ROOT
export COMPOSER_ALLOW_SUPERUSER=1
composer install --no-dev --optimize-autoloader

# Restart Apache
systemctl restart httpd

log_message "Deployment completed successfully on Amazon Linux 2023"
