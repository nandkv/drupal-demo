#!/bin/bash
# Check if Apache is running and stop it
if systemctl is-active httpd > /dev/null 2>&1; then
    systemctl stop httpd
fi
