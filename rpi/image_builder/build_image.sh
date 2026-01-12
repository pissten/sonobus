#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo)"
  exit 1
fi

IMAGE_FILE="$1"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
BINARY="${SCRIPT_DIR}/artifacts/sonobus_arm64"
MOUNT_POINT="/mnt/rpi_image"

if [ -z "$IMAGE_FILE" ]; then
    echo "Usage: sudo ./build_image.sh <raspios.img>"
    exit 1
fi

if [ ! -f "$BINARY" ]; then
    echo "Error: Binary not found at $BINARY"
    echo "Please run ./build_binary.sh first!"
    exit 1
fi

echo "=== Injecting Sonobus into $IMAGE_FILE ==="

# Check for required tools
if ! command -v parted &> /dev/null; then
    echo "Error: 'parted' is not installed. Please install it (sudo apt install parted)."
    exit 1
fi
if ! command -v resize2fs &> /dev/null; then
    echo "Error: 'resize2fs' is not installed."
    exit 1
fi

# Expand Image Size
echo "Expanding image size by 1GB..."
truncate -s +1G "$IMAGE_FILE"

# Resize Partition 2 to fill space
echo "Resizing partition 2..."
# 'resizepart 2 100%' tells parted to extend partition 2 to the end of the file
parted -s "$IMAGE_FILE" resizepart 2 100%

# Create mount point
mkdir -p "$MOUNT_POINT"

# Setup loop device
echo "Setting up loop device..."
LOOP_DEV=$(losetup -fP --show "$IMAGE_FILE")
echo "Loop device: $LOOP_DEV"

# Typically Partition 2 is RootFS (Partition 1 is boot)
ROOT_PART="${LOOP_DEV}p2"

# Resize Filesystem
echo "Resizing filesystem on $ROOT_PART..."
e2fsck -f -p "$ROOT_PART" || true # Auto-repair if needed, ignore exit code
resize2fs "$ROOT_PART"

echo "Mounting $ROOT_PART to $MOUNT_POINT..."
mount "$ROOT_PART" "$MOUNT_POINT"

# Install Files
echo "Installing files..."
INSTALL_DIR="$MOUNT_POINT/opt/sonobus/rpi"
BIN_DIR="$MOUNT_POINT/usr/local/bin"

mkdir -p "$INSTALL_DIR"
mkdir -p "$BIN_DIR"

# Copy Binary
cp "$BINARY" "$BIN_DIR/sonobus"
chmod +x "$BIN_DIR/sonobus"

# Copy Config Scripts
cp "${REPO_ROOT}/rpi/start_sonobus.sh" "$INSTALL_DIR/"
cp "${REPO_ROOT}/rpi/web_config.py" "$INSTALL_DIR/"
cp "${REPO_ROOT}/rpi/config.env" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/start_sonobus.sh"

# Install Services
echo "Configuring Services..."
SERVICE_DIR="$MOUNT_POINT/etc/systemd/system"

cp "${REPO_ROOT}/rpi/sonobus.service" "$SERVICE_DIR/"
cp "${REPO_ROOT}/rpi/sonobus-web.service" "$SERVICE_DIR/"

# Enable Services (Symlinks)
WANTS_DIR="$SERVICE_DIR/multi-user.target.wants"
mkdir -p "$WANTS_DIR"

ln -sf "../sonobus.service" "$WANTS_DIR/sonobus.service"
ln -sf "../sonobus-web.service" "$WANTS_DIR/sonobus-web.service"

# Install Dependencies via QEMU Chroot
echo "Installing runtime dependencies (using qemu-static)..."
if [ -f "/usr/bin/qemu-aarch64-static" ]; then
    cp /usr/bin/qemu-aarch64-static "$MOUNT_POINT/usr/bin/"
    
    # We need networking in chroot for apt
    cp /etc/resolv.conf "$MOUNT_POINT/etc/resolv.conf"
    
    # Run apt-get in chroot
    chroot "$MOUNT_POINT" /bin/bash -c "apt-get update && apt-get install -y libjack-jackd2-0 libopus0 libasound2 libfreetype6 libcurl4 libx11-6 libxext6 libxinerama1 libxrandr2 libxcursor1 libgl1"
    
    # Cleanup
    rm "$MOUNT_POINT/usr/bin/qemu-aarch64-static"
    # Don't delete resolv.conf, let it remain or overwrite? Usually safe to leave or restore original if it was a link. 
    # Valid RPi OS has a symlink usually. Let's try to restore if possible, but for now copying ensures network works.
else
    echo "WARNING: /usr/bin/qemu-aarch64-static not found. Skipping dependency install."
    echo "You might need to run 'sudo apt install -y libjack-jackd2-0 libopus0 ...' manually on the Pi."
fi

# Cleanup
echo "Unmounting..."
umount "$MOUNT_POINT"
losetup -d "$LOOP_DEV"

echo "SUCCESS! Image is ready to flash."
echo "Sonobus will start automatically on boot."
echo "Web Config: http://<raspberry-pi-ip>:8080"
