#!/bin/bash

# This script is meant to be run on the container host.
# It installs a custom certificate into the Uyuni server container.

# Arguments and defaults
PODMAN="${PODMAN:-podman}"
SERVER_CERT_PATH="$1"
SERVER_KEY_PATH="$2"
ROOT_CA_PATH="$3"
INTERMEDIATE_CA_PATH="$4"
CONTAINER_NAME="${5:-uyuni-server}"

# Warn if not running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Warning: Not running as root. Uyuni server container may not be accessible."
fi

# Validate arguments
if [ -z "$SERVER_CERT_PATH" ] || [ -z "$SERVER_KEY_PATH" ] || [ -z "$ROOT_CA_PATH" ]; then
    echo "Usage: $0 <server-cert-path> <server-key-path> <root-ca-path> [intermediate-ca-path] [container-name]"
    exit 1
fi

# Validate paths
if [ ! -f "$SERVER_CERT_PATH" ] || [ ! -f "$SERVER_KEY_PATH" ] || [ ! -f "$ROOT_CA_PATH" ]; then
    echo "Error: One or more certificate files not found."
    exit 1
fi

# Validate certificate and key match (modulus check)
SERVER_CERT_MODULUS=$(openssl x509 -noout -modulus -in "$SERVER_CERT_PATH")
SERVER_KEY_MODULUS=$(openssl rsa -noout -modulus -in "$SERVER_KEY_PATH")
if [ "$SERVER_CERT_MODULUS" != "$SERVER_KEY_MODULUS" ]; then
    echo "Error: Server certificate and key do not match."
    exit 1
fi

# Validate CA chain
if [ -n "$INTERMEDIATE_CA_PATH" ]; then
    # Check server certificate against intermediate CA
    if ! openssl verify -CAfile "$INTERMEDIATE_CA_PATH" "$SERVER_CERT_PATH" &>/dev/null; then
        echo "Error: Server certificate and intermediate CA do not match."
        exit 1
    fi
    # Check intermediate CA against root CA
    if ! openssl verify -CAfile "$ROOT_CA_PATH" "$INTERMEDIATE_CA_PATH" &>/dev/null; then
        echo "Error: Intermediate CA and root CA do not match."
        exit 1
    fi
else
    # Check server certificate against root CA
    if ! openssl verify -CAfile "$ROOT_CA_PATH" "$SERVER_CERT_PATH" &>/dev/null; then
        echo "Error: Server certificate and root CA do not match."
        exit 1
    fi
fi

# Validate container exists
CONTAINER_INFO=$($PODMAN inspect "$CONTAINER_NAME" 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "Error: Container '$CONTAINER_NAME' not found. Is Uyuni installed?"
    exit 1
fi

# Check if container is running
if command -v jq &>/dev/null; then
    CONTAINER_RUNNING=$(echo "$CONTAINER_INFO" | jq -r '.[0].State.Running')
    if [ "$CONTAINER_RUNNING" != "true" ]; then
        echo "Error: Container '$CONTAINER_NAME' is not running."
        exit 1
    fi
else
    if ! echo "$CONTAINER_INFO" | grep -q '"Running": true'; then
        echo "Error: Container '$CONTAINER_NAME' is not running."
        exit 1
    fi
fi

# Copy certificate files to the container
echo "Copying certificate files to the container..."
$PODMAN cp "$SERVER_CERT_PATH" "$CONTAINER_NAME:/var/cache/private/server.crt" || { echo "Error: Failed to copy server certificate into the container!"; exit 1; }
$PODMAN cp "$SERVER_KEY_PATH" "$CONTAINER_NAME:/var/cache/private/server.key" || { echo "Error: Failed to copy server key into the container!"; exit 1; }
$PODMAN cp "$ROOT_CA_PATH" "$CONTAINER_NAME:/var/cache/private/ca.crt" || { echo "Error: Failed to copy CA chain into the container!"; exit 1; }
if [ -n "$INTERMEDIATE_CA_PATH" ]; then
    $PODMAN cp "$INTERMEDIATE_CA_PATH" "$CONTAINER_NAME:/var/cache/private/intermediate.crt" || { echo "Error: Failed to copy intermediate CA into the container!"; exit 1; }
fi

# Install new certificate with 'mgr-ssl-cert-setup' within the container
echo "Installing new certificate..."
if [ -n "$INTERMEDIATE_CA_PATH" ]; then
    $PODMAN exec -it "$CONTAINER_NAME" mgr-ssl-cert-setup \
        -vvvv \
        --root-ca-file "/var/cache/private/ca.crt" \
        --intermediate-ca-file "/var/cache/private/intermediate.crt" \
        --server-cert-file "/var/cache/private/server.crt" \
        --server-key-file "/var/cache/private/server.key"
else
    $PODMAN exec -it "$CONTAINER_NAME" mgr-ssl-cert-setup \
        -vvvv \
        --root-ca-file "/var/cache/private/ca.crt" \
        --server-cert-file "/var/cache/private/server.crt" \
        --server-key-file "/var/cache/private/server.key"
fi

# Check result and restart services within the container
if [ $? -eq 0 ]; then
    echo "Certificate installed successfully!"
    echo "Restarting services..."
    # Restart PostgreSQL and Uyuni services
    $PODMAN exec "$CONTAINER_NAME" spacewalk-service stop || { echo "Error: Failed to stop Uyuni services!"; exit 1; }
    $PODMAN exec "$CONTAINER_NAME" systemctl restart postgresql.service || { echo "Error: Failed to restart PostgreSQL service!"; exit 1; }
    $PODMAN exec "$CONTAINER_NAME" spacewalk-service start || { echo "Error: Failed to start Uyuni services!"; exit 1; }
    echo "Services restarted successfully!"
    # Clean up temporary files
    $PODMAN exec "$CONTAINER_NAME" rm -f /var/cache/private/server.crt /var/cache/private/server.key /var/cache/private/ca.crt /var/cache/private/intermediate.crt &>/dev/null
    # Exit successfully
    echo "Certificate installation complete!"
    exit 0
else
    echo "Error: Certificate installation failed!"
    exit 1
fi
