#!/bin/bash
# Set proper permissions
chown -R apache:apache /var/www/html/
chmod -R 755 /var/www/html/

# Install Drupal dependencies if using Composer
cd /var/www/html
if [ -f "composer.json" ]; then
    composer install --no-dev
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
