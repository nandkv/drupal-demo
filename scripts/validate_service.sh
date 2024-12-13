#!/bin/bash
# Wait for Apache to start
sleep 10

# Check if Apache is running
if ! systemctl is-active httpd > /dev/null 2>&1; then
    echo "Apache is not running"
    exit 1
fi

# Check if we can get a response from the server
HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost)

if [ "$HTTP_RESPONSE" -ne 200 ] && [ "$HTTP_RESPONSE" -ne 302 ] && [ "$HTTP_RESPONSE" -ne 301 ]; then
    echo "Application is not responding properly, got HTTP response code $HTTP_RESPONSE"
    exit 1
fi

echo "Application validation successful"
exit 0
