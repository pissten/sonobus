FROM debian:bookworm-slim

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    libasound2-dev \
    libjack-jackd2-dev \
    libopus-dev \
    libx11-dev \
    libxext-dev \
    libxinerama-dev \
    libxrandr-dev \
    libxcursor-dev \
    libgl-dev \
    libfreetype6-dev \
    libcurl4-openssl-dev \
    pkg-config \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Set working directory for build
WORKDIR /build

# Copy source code
COPY . /build

# Build Sonobus Headless
# We only need the headless binary usually, but the standard build script is easier
WORKDIR /build/linux
# Inject set -e to make sure build fails if cmake fails
RUN sed -i '2i set -e' build.sh && ./build.sh debug

# Installation (Manual copy to /usr/local/bin)
# Find and install the binary (path varies by generator, usually SonoBus on Linux)
# We use -iname to match Sonobus, sonobus, etc.
RUN find ../build -iname sonobus -type f -exec cp {} /usr/local/bin/sonobus \; \
    && chmod +x /usr/local/bin/sonobus \
    && ls -l /usr/local/bin/sonobus

# Setup Runtime Directory
WORKDIR /opt/sonobus
RUN mkdir -p /opt/sonobus

# Copy RPi scripts (We reuse the logic from the RPi implementation by copying them)
# But we rename/place them where our web_runner expects them
COPY rpi/start_sonobus.sh /opt/sonobus/start_sonobus.sh
COPY rpi/docker/web_runner.py /opt/sonobus/web_runner.py

# Make executable
RUN chmod +x /opt/sonobus/start_sonobus.sh

# Environment defaults
ENV SONOBUS_USER=DockerUser
ENV SONOBUS_GROUP=DockerGroup

# Create a dummy config file so start_sonobus.sh doesn't fail
RUN touch /opt/sonobus/config.env

# Expose Web Interface Port
EXPOSE 8080

# Run the Python Controller
CMD ["python3", "/opt/sonobus/web_runner.py"]
