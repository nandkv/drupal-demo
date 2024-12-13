#!/bin/bash
# Update system
yum update -y

# Install Amazon Linux Extras
yum install -y amazon-linux-extras

# Enable and install PHP 8.1
amazon-linux-extras enable php8.1
yum clean metadata
yum install -y php php-cli php-common php-mysqlnd php-zip php-gd php-mbstring php-xml php-json

# Verify PHP version
php -v

# Install specific version of Composer (2.2 LTS)
curl -sS https://getcomposer.org/installer | php -- --version=2.2.18
mv composer.phar /usr/local/bin/composer
chmod +x /usr/local/bin/composer

# Verify Composer version
composer --version

# Restart Apache
systemctl restart httpd
