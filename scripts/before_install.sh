#!/bin/bash
# Update system
dnf update -y

# Install PHP 8.1 and required extensions
dnf install -y php-8.1 php-cli php-common php-mysqlnd php-zip \
    php-gd php-mbstring php-xml php-json php-bcmath \
    php-curl php-fpm httpd

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

# Configure PHP-FPM
systemctl start php-fpm
systemctl enable php-fpm

# Configure Apache to use PHP-FPM
cat > /etc/httpd/conf.d/php-fpm.conf << 'EOF'
<FilesMatch \.php$>
    SetHandler "proxy:unix:/run/php-fpm/www.sock|fcgi://localhost"
</FilesMatch>
EOF

# Start and enable Apache
systemctl start httpd
systemctl enable httpd

# Debug information
echo "PHP Version:"
php -v
echo "PHP Modules:"
php -m
echo "Composer Version:"
composer --version
echo "PHP-FPM Status:"
systemctl status php-fpm
echo "Apache Status:"
systemctl status httpd

