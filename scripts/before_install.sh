#!/bin/bash

# Exit on any error
set -e

# Update system
dnf update -y

# Install EPEL and REMI repositories
dnf install -y dnf-utils
dnf install -y https://rpms.remirepo.net/enterprise/remi-release-8.rpm

# Reset and enable PHP 8.2 module
dnf module reset php -y
dnf module enable php:remi-8.2 -y

# Install PHP 8.2 and required extensions
dnf install -y \
    php82 \
    php82-php-cli \
    php82-php-common \
    php82-php-mysqlnd \
    php82-php-zip \
    php82-php-gd \
    php82-php-mbstring \
    php82-php-xml \
    php82-php-json \
    php82-php-bcmath \
    php82-php-curl \
    php82-php-fpm \
    php82-php-opcache \
    php82-php-intl \
    php82-php-pecl-apcu \
    httpd \
    git \
    unzip

# Configure PHP alternatives
alternatives --set php /usr/bin/php82
alternatives --set php-cli /usr/bin/php82

# Verify PHP version
echo "Checking PHP version..."
php -v

# Install Composer
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
chmod +x /usr/local/bin/composer

# Verify Composer version
echo "Checking Composer version..."
composer --version

# Configure PHP
cp /etc/opt/remi/php82/php.ini /etc/opt/remi/php82/php.ini.bak
cat > /etc/opt/remi/php82/php.d/99-custom.ini << 'EOF'
memory_limit = 256M
max_execution_time = 120
post_max_size = 64M
upload_max_filesize = 64M
date.timezone = UTC
opcache.enable=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=4000
opcache.revalidate_freq=60
opcache.fast_shutdown=1
realpath_cache_size = 4096K
realpath_cache_ttl = 600
EOF

# Configure PHP-FPM
cat > /etc/opt/remi/php82/php-fpm.d/www.conf << 'EOF'
[www]
user = apache
group = apache
listen = /var/opt/remi/php82/run/php-fpm/www.sock
listen.owner = apache
listen.group = apache
listen.mode = 0660
pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 35
pm.max_requests = 500
pm.process_idle_timeout = 10s
EOF

# Configure Apache to use PHP-FPM
cat > /etc/httpd/conf.d/php-fpm.conf << 'EOF'
<FilesMatch \.php$>
    SetHandler "proxy:unix:/var/opt/remi/php82/run/php-fpm/www.sock|fcgi://localhost"
</FilesMatch>

# PHP-FPM status and ping paths
<LocationMatch "^/(php-status|php-ping)$">
    Require local
</LocationMatch>
EOF

# Start and enable PHP-FPM
systemctl start php82-php-fpm
systemctl enable php82-php-fpm

# Start and enable Apache
systemctl start httpd
systemctl enable httpd

# Create directory for session and uploads if they don't exist
mkdir -p /var/opt/remi/php82/lib/php/session
mkdir -p /var/opt/remi/php82/lib/php/upload
chown apache:apache /var/opt/remi/php82/lib/php/session
chown apache:apache /var/opt/remi/php82/lib/php/upload
chmod 700 /var/opt/remi/php82/lib/php/session
chmod 700 /var/opt/remi/php82/lib/php/upload

# Debug information
echo "=== Installation Complete ==="
echo "PHP Version:"
php -v
echo -e "\nPHP Modules:"
php -m
echo -e "\nComposer Version:"
composer --version
echo -e "\nPHP-FPM Status:"
systemctl status php82-php-fpm
echo -e "\nApache Status:"
systemctl status httpd
echo -e "\nPHP-FPM Socket:"
ls -l /var/opt/remi/php82/run/php-fpm/www.sock
echo -e "\nPHP Configuration:"
php -i | grep "Loaded Configuration File"
