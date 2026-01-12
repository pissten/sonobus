#!/bin/bash

# Enable debug mode to see all commands
set -x

# Determine script directory to find config.env
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
CONFIG_FILE="$DIR/config.env"
SETUP_FILE="$HOME/.config/sonobus/headless.settings"

echo "=== Sonobus Startup Debug ==="
echo "Reading config from: $CONFIG_FILE"

# Load Configuration from env file if it exists
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    echo "Loaded Configuration:"
    echo "  USER: '$SONOBUS_USER'"
    echo "  GROUP: '$SONOBUS_GROUP'"
    echo "  PASS: '$SONOBUS_PASSWORD'"
    echo "  SERVER: '$SONOBUS_SERVER'"
else
    echo "WARNING: Config file not found! Using defaults."
    # Defaults
    SONOBUS_USER="RPi-Node"
    SONOBUS_GROUP="MyGroup"
    SONOBUS_PASSWORD=""
    SONOBUS_SERVER=""
fi

# Build command line
# Use --option=value format for robustness
CMD="/usr/local/bin/sonobus"
ARGS=("--headless")

if [ -f "$SETUP_FILE" ]; then
    ARGS+=("--load-setup=$SETUP_FILE")
else
    # Fallback/Override Settings
    ARGS+=("--username=$SONOBUS_USER")
    
    if [ -n "$SONOBUS_GROUP" ]; then
        ARGS+=("--group=$SONOBUS_GROUP")
    fi
    
    if [ -n "$SONOBUS_PASSWORD" ]; then
        ARGS+=("--group-password=$SONOBUS_PASSWORD")
    fi
    
    if [ -n "$SONOBUS_SERVER" ]; then
        ARGS+=("--connectionserver=$SONOBUS_SERVER")
    fi
fi

# Run
echo "Starting Sonobus: $CMD ${ARGS[*]}"
exec "$CMD" "${ARGS[@]}"
