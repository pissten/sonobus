#!/bin/bash
set -e

# Setup directories
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
OUTPUT_DIR="${SCRIPT_DIR}/artifacts"

echo "=== Building Sonobus for ARM64 using Docker ==="
echo "Repo Root: $REPO_ROOT"
echo "Output Dir: $OUTPUT_DIR"

mkdir -p "$OUTPUT_DIR"

# Ensure we have buildx support
echo "Checking Docker Buildx..."
if ! docker buildx version > /dev/null 2>&1; then
    echo "Error: Docker Buildx not found. Please enable experimental features or install buildx."
    echo "You may also need to install qemu-user-static: sudo apt install qemu-user-static"
    exit 1
fi

# Build the image
echo "Building Docker image (sonobus-builder-arm64)..."
docker buildx build --platform linux/arm64 \
    -t sonobus-builder-arm64 \
    -f "${REPO_ROOT}/rpi/docker/Dockerfile.build_arm64" \
    --load \
    "${REPO_ROOT}"

# Extract binary
echo "Extracting compiled binary..."
CONTAINER_ID=$(docker create sonobus-builder-arm64)

# Try different paths as the build output location might vary (standard build vs my dockerfile paths)
# In the dockerfile we ran ./build.sh in /build/linux. 
# It usually finds the file in ../build/SonoBus or somesuch.
# Let's use 'find' inside the container manually or just blindly copy common paths.
# Actually, let's use a robust copy approach.

mkdir -p "$OUTPUT_DIR"
docker cp "${CONTAINER_ID}:/build/build/SonoBus_artefacts/Release/Standalone/sonobus" "${OUTPUT_DIR}/sonobus_arm64" 2>/dev/null || \
docker cp "${CONTAINER_ID}:/usr/local/bin/sonobus" "${OUTPUT_DIR}/sonobus_arm64" 2>/dev/null || \
docker cp "${CONTAINER_ID}:/build/build/sonobus" "${OUTPUT_DIR}/sonobus_arm64" 2>/dev/null

docker rm "${CONTAINER_ID}"

if [ -f "${OUTPUT_DIR}/sonobus_arm64" ]; then
    echo "SUCCESS: Binary saved to ${OUTPUT_DIR}/sonobus_arm64"
    chmod +x "${OUTPUT_DIR}/sonobus_arm64"
else
    echo "ERROR: Could not find 'sonobus' binary in container."
    exit 1
fi
