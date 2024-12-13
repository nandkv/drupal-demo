#!/bin/bash

# Exit on error
set -e

# Update system
dnf update -y 

# Install base packages
dnf install -y dnf-utils httpd git unzip wget

dnf install -y php8.2 php-dom php-gd php-simplexml php-xml php-opcache php-mbstring

# Install PHP and extensions directly from AL2023 repositories
dnf install -y php-mysqlnd 

# Restart httpd
sudo service httpd restart

echo "Installation process completed"
