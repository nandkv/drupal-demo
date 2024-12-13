#!/bin/bash

# Exit on any error
set -e

# Update system with skip-broken flag
dnf update -y --skip-broken

# Install EPEL and REMI repositories
dnf install -y --skip-broken dnf-utils
dnf install -y --skip-broken https://rpms.remirepo.net/enterprise/remi-release-8.rpm

# Reset and enable PHP 8.2 module
dnf module reset php -y
dnf module enable php:remi-8.2 -y

# Install PHP 8.2 and required extensions with skip-broken flag
dnf install -y --skip-broken \
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
    unzip || {
        echo "Warning: Some packages might not have been installed. Continuing anyway..."
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
        echo "Attempting to install missing modules..."
        for module in "${missing_modules[@]}"; do
            dnf install -y --skip-broken "php82-php-${module}" || echo "Warning: Could not install php82-php-${module}"
        done
    fi
}

# Configure PHP alternatives
alternatives --set php /usr/bin/php82 || echo "Warning: Could not set PHP alternative"
alternatives --set php-cli /usr/bin/php82 || echo "Warning: Could not set PHP-CLI alternative"

# Verify PHP version
echo "Checking PHP version..."
php -v

# Install Composer
if ! command -v composer &> /dev/null; then
    curl -sS https://getcomposer.org/installer | php
    mv composer.phar /usr/local/bin/composer
    chmod +x /usr/local/bin/composer
fi

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

# Configure PHP-FPM with error handling
cat > /etc/opt/remi/php82/php-fpm.d/www.conf << 'EOF' || echo "Warning: Could not create PHP-FPM configuration"
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
cat > /etc/httpd/conf.d/php-fpm.conf << 'EOF' || echo "Warning: Could not create Apache PHP-FPM configuration"
<FilesMatch \.php$>
    SetHandler "proxy:unix:/var/opt/remi/php82/run/php-fpm/www.sock|fcgi://localhost"
</FilesMatch>

# PHP-FPM status and ping paths
<LocationMatch "^/(php-status|php-ping)$">
    Require local
</LocationMatch>
EOF

# Start and enable services with error handling
systemctl start php82-php-fpm || echo "Warning: Could not start PHP-FPM"
systemctl enable php82-php-fpm || echo "Warning: Could not enable PHP-FPM"
systemctl start httpd || echo "Warning: Could not start Apache"
systemctl enable httpd || echo "Warning: Could not enable Apache"

# Create directories with error handling
mkdir -p /var/opt/remi/php82/lib/php/session || echo "Warning: Could not create session directory"
mkdir -p /var/opt/remi/php82/lib/php/upload || echo "Warning: Could not create upload directory"
chown apache:apache /var/opt/remi/php82/lib/php/session || echo "Warning: Could not set session directory ownership"
chown apache:apache /var/opt/remi/php82/lib/php/upload || echo "Warning: Could not set upload directory ownership"
chmod 700 /var/opt/remi/php82/lib/php/session || echo "Warning: Could not set session directory permissions"
chmod 700 /var/opt/remi/php82/lib/php/upload || echo "Warning: Could not set upload directory permissions"

# Verify PHP modules
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
systemctl status php82-php-fpm || true
echo -e "\nApache Status:"
systemctl status httpd || true
echo -e "\nPHP-FPM Socket:"
ls -l /var/opt/remi/php82/run/php-fpm/www.sock || echo "Warning: PHP-FPM socket not found"
echo -e "\nPHP Configuration:"
php -i | grep "Loaded Configuration File" || echo "Warning: Could not determine PHP configuration file"

# Final check for critical services
if ! systemctl is-active --quiet php82-php-fpm; then
    echo "WARNING: PHP-FPM is not running!"
fi

if ! systemctl is-active --quiet httpd; then
    echo "WARNING: Apache is not running!"
fi

echo "Installation process completed with error handling enabled"
