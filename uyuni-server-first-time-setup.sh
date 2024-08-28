#!/bin/bash

# This script is meant to be run within the Uyuni server container on the first run.
# It sets up an Uyuni server using the mgr-setup script and creates the first organization and admin account.

# Abort on any error
set -e

# Skip if already setup
if [ -f /root/.MANAGER_SETUP_COMPLETE ]; then
    echo "Uyuni server is already set up."
    systemctl -q disable uyuni-server-first-time-setup.service
    exit 0
fi

# Run setup: https://github.com/uyuni-project/uyuni/blob/master/susemanager/bin/mgr-setup
echo "Running mgr-setup..."
/usr/lib/susemanager/bin/mgr-setup -s -n -l /var/log/susemanager_setup.log
echo "mgr-setup completed successfully!"

# Create first organization and admin account, if required environment variables are set
if [ -z "$MANAGER_USER" ] || [ -z "$MANAGER_PASS" ] || \
   [ -z "$MANAGER_ORG" ] || [ -z "$MANAGER_FIRSTNAME" ] || \
   [ -z "$MANAGER_LASTNAME" ] || [ -z "$MANAGER_ADMIN_EMAIL" ]
then
    echo "Skipping first organization and admin account creation due to missing environment variables."
else
    echo "Creating first organization and admin account..."
    sleep 3 # Give Uyuni some time to warm up...
    /usr/bin/spacecmd --nohistory --nossl -s localhost -u "$MANAGER_USER" -p "$MANAGER_PASS" -- org_createfirst \
        -n "$MANAGER_ORG" \
        -u "$MANAGER_USER" \
        -f "$MANAGER_FIRSTNAME" \
        -l "$MANAGER_LASTNAME" \
        -e "$MANAGER_ADMIN_EMAIL" \
        -p "$MANAGER_PASS"
    echo "First organization and admin account created successfully!"
fi

# Disable uyuni-server-first-time-setup.service
systemctl -q disable uyuni-server-first-time-setup.service

# End setup
echo "Uyuni server first time setup complete!"
exit 0
