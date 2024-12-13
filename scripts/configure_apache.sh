#!/bin/bash
# Configure Apache
cat > /etc/httpd/conf.d/custom.conf << 'EOF'
<Directory "/var/www/html">
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
    DirectoryIndex index.php index.html
</Directory>
EOF

# Set permissions
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html
find /var/www/html -type f -exec chmod 644 {} \;

# Restart Apache
systemctl restart httpd
