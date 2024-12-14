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

# Install PHP 8.2 and required extensions
dnf install -y --skip-broken \
    php8.2 \
    php-dom \
    php-gd \
    php-simplexml \
    php-xml \
    php-opcache \
    php-mbstring \
    php-cli \
    php-common \
    php-mysqlnd \
    php-zip \
    php-json \
    php-bcmath \
    php-curl \
    php-intl \
    php-pecl-apcu

# Install Composer
if ! command -v composer &> /dev/null; then
    curl -sS https://getcomposer.org/installer | php
    mv composer.phar /usr/local/bin/composer
    chmod +x /usr/local/bin/composer
fi

# Start and enable Apache
systemctl start httpd
systemctl enable httpd
