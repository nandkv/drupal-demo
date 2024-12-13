#!/bin/bash
# Stop and remove any existing application files
systemctl stop httpd
rm -rf /var/www/html/*
