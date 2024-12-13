#!/bin/bash
# Create a temporary directory for unzipping
TEMP_DIR=$(mktemp -d)

# Unzip the application to the temp directory
unzip -o /opt/codedeploy-agent/deployment-root/$DEPLOYMENT_GROUP_ID/$DEPLOYMENT_ID/deployment-archive/application.zip -d $TEMP_DIR

# Clean the destination directories
rm -rf /var/www/html/*
rm -rf /var/www/composer.*

# Move the web directory contents to /var/www/html
mv $TEMP_DIR/web/* /var/www/html/

# Move the vendor directory to /var/www
mv $TEMP_DIR/vendor /var/www/

# Move composer files to /var/www
mv $TEMP_DIR/composer.json /var/www/
mv $TEMP_DIR/composer.lock /var/www/

# Clean up temp directory
rm -rf $TEMP_DIR

# Set initial permissions
chown -R apache:apache /var/www/html/
chmod -R 755 /var/www/html/
chown -R apache:apache /var/www/vendor/
chmod -R 755 /var/www/vendor/
chown apache:apache /var/www/composer.*
chmod 644 /var/www/composer.*

# Verify PHP version before running composer
echo "PHP Version:"
php -v

# Install Drupal dependencies if using Composer
cd /var/www  # Changed working directory to /var/www where composer.json is located
if [ -f "composer.json" ]; then
    echo "Running composer install..."
    COMPOSER_MEMORY_LIMIT=-1 composer install --no-dev
fi

# Create settings file if it doesn't exist
if [ ! -f "/var/www/html/sites/default/settings.php" ]; then
    cp /var/www/html/sites/default/default.settings.php /var/www/html/sites/default/settings.php
fi

# Set proper permissions for settings
chmod 644 /var/www/html/sites/default/settings.php
chown apache:apache /var/www/html/sites/default/settings.php

# Create files directory if it doesn't exist
mkdir -p /var/www/html/sites/default/files
chmod 775 /var/www/html/sites/default/files
chown -R apache:apache /var/www/html/sites/default/files

# Final permission check for files that need to be writable
find /var/www/html -type f -exec chmod 644 {} \;
find /var/www/html -type d -exec chmod 755 {} \;

# Restart Apache
systemctl restart httpd

echo "Deployment completed successfully"
