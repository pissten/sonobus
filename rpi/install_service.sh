#!/bin/bash

# check if we are root
if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root"
  exit 1
fi

INSTALL_DIR="/opt/sonobus/rpi"
BIN_DIR="/usr/local/bin"

# Ensure Sonobus is installed
if [ ! -f "$BIN_DIR/sonobus" ]; then
    echo "Warning: sonobus executable not found in $BIN_DIR. Make sure to install it first (../linux/install.sh)."
fi

# Copy scripts to install dir
mkdir -p "$INSTALL_DIR"
cp start_sonobus.sh "$INSTALL_DIR/"
cp web_config.py "$INSTALL_DIR/"
cp config.env "$INSTALL_DIR/"

# Make executable
chmod +x "$INSTALL_DIR/start_sonobus.sh"
chmod +x "$INSTALL_DIR/web_config.py"

# Install Services
cp sonobus.service /etc/systemd/system/sonobus.service
cp sonobus-web.service /etc/systemd/system/sonobus-web.service

systemctl daemon-reload
systemctl enable sonobus.service
systemctl enable sonobus-web.service

echo "Sonobus services installed and enabled."
echo "Web Configurator available at http://<IP>:8080"
echo "Start now with:"
echo "  systemctl start sonobus"
echo "  systemctl start sonobus-web"
