#!/bin/bash
# Install EPEL and REMI repositories
yum install -y epel-release
yum install -y https://rpms.remirepo.net/enterprise/remi-release-7.rpm

# Enable REMI PHP 8.1 repository
yum-config-manager --enable remi-php81

# Install PHP 8.1 and required extensions
yum install -y php php-cli php-common php-mysqlnd php-zip php-gd php-mbstring php-xml php-json

# Verify PHP version
php -v

# Install Composer
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
chmod +x /usr/local/bin/composer

# Verify Composer version
composer --version

# Restart Apache
systemctl restart httpd

