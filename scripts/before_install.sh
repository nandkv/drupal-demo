#!/bin/bash

# Exit on error
set -e

# Update system
dnf update -y --skip-broken

# Install base packages
dnf install -y --skip-broken \
    dnf-utils \
    httpd \
    git \
    unzip \
    wget

# Install PHP and extensions directly from AL2023 repositories
dnf install -y --skip-broken \
    php \
    php-cli \
    php-common \
    php-fpm \
    php-mysqlnd \
    php-zip \
    php-gd \
    php-mbstring \
    php-xml \
    php-json \
    php-bcmath \
    php-curl \
    php-opcache \
    php-intl \
    php-pecl-apcu

# Function to verify PHP installation
verify_php_installation() {
    if ! command -v php &> /dev/null; then
        echo "ERROR: PHP installation failed"
        exit 1
    fi
    
    echo "PHP version installed:"
    php -v
}

# Function to verify required PHP modules
verify_php_modules() {
    required_modules=("json" "mysqlnd" "gd" "xml" "mbstring" "curl" "opcache")
    missing_modules=()
    
    for module in "${required_modules[@]}"; do
        if ! php -m | grep -qi "^${module}"; then
            missing_modules+=("$module")
        fi
    done
    
    if [ ${#missing_modules[@]} -ne 0 ]; then
        echo "Warning: The following PHP modules are missing: ${missing_modules[*]}"
    fi
}

# Install Composer
if ! command -v composer &> /dev/null; then
    curl -sS https://getcomposer.org/installer | php
    mv composer.phar /usr/local/bin/composer
    chmod +x /usr/local/bin/composer
fi

# Configure PHP
cp /etc/php.ini /etc/php.ini.bak
cat > /etc/php.d/99-custom.ini << 'EOF'
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
cat > /etc/php-fpm.d/www.conf << 'EOF'
[www]
user = apache
group = apache
listen = /run/php-fpm/www.sock
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
    SetHandler "proxy:unix:/run/php-fpm/www.sock|fcgi://localhost"
</FilesMatch>

# PHP-FPM status and ping paths
<LocationMatch "^/(php-status|php-ping)$">
    Require local
</LocationMatch>
EOF

# Create necessary directories
mkdir -p /run/php-fpm
chown apache:apache /run/php-fpm

# Create session and upload directories
mkdir -p /var/lib/php/session
mkdir -p /var/lib/php/upload
chown apache:apache /var/lib/php/session
chown apache:apache /var/lib/php/upload
chmod 700 /var/lib/php/session
chmod 700 /var/lib/php/upload

# Start and enable services
systemctl start php-fpm || echo "Warning: Could not start PHP-FPM"
systemctl enable php-fpm || echo "Warning: Could not enable PHP-FPM"
systemctl start httpd || echo "Warning: Could not start Apache"
systemctl enable httpd || echo "Warning: Could not enable Apache"

# Verify PHP installation and modules
verify_php_installation
verify_php_modules

# Debug information
echo "=== Installation Complete ==="
echo "PHP Version:"
php -v
echo -e "\nPHP Modules:"
php -m
echo -e "\nComposer Version:"
composer --version
echo -e "\nPHP-FPM Status:"
systemctl status php-fpm || true
echo -e "\nApache Status:"
systemctl status httpd || true
echo -e "\nPHP-FPM Socket:"
ls -l /run/php-fpm/www.sock || echo "Warning: PHP-FPM socket not found"
echo -e "\nPHP Configuration:"
php -i | grep "Loaded Configuration File" || echo "Warning: Could not determine PHP configuration file"

# Final check for critical services
if ! systemctl is-active --quiet php-fpm; then
    echo "WARNING: PHP-FPM is not running!"
fi

if ! systemctl is-active --quiet httpd; then
    echo "WARNING: Apache is not running!"
fi

# Check installed PHP version meets requirements
PHP_VERSION=$(php -r 'echo PHP_VERSION;')
if ! echo "$PHP_VERSION" | grep -q "^8"; then
    echo "WARNING: Installed PHP version ($PHP_VERSION) might not be compatible. Required: PHP 8.x"
fi

echo "Installation process completed with error handling enabled"
