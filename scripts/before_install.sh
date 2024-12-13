#!/bin/bash
# Update system
yum update -y

# Install required repositories
yum install -y epel-release
yum install -y https://rpms.remirepo.net/enterprise/remi-release-7.rpm

# Install yum-utils for repository management
yum install -y yum-utils

# Enable Remi PHP 8.3 repository
yum-config-manager --enable remi-php83

# Install PHP 8.3 and required extensions
yum install -y php php-cli php-common php-mysqlnd php-zip php-gd php-mbstring php-xml php-json php-bcmath php-curl

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

# Debug information
echo "PHP Version:"
php -v
echo "PHP Modules:"
php -m
echo "Composer Version:"
composer --version
