# Raspberry Pi Headless Setup for Sonobus

This directory contains helper scripts to run Sonobus in headless mode on a Raspberry Pi (or other Linux devices) as a systemd service.

## Prerequisites

1. Build and install Sonobus normally (see `../linux/BUILDING.md` and `../linux/install.sh`).
   - Ensure the `sonobus` binary is in `/usr/local/bin/` (or adjust the scripts).
2. Ensure your audio system (ALSA/Jack/Pulse) is configured correctly on the Pi.

## Installation

1. Run the install script as root:
   ```bash
   sudo ./install_service.sh
   ```
   This will:
   - Create `/opt/sonobus/rpi` and copy the startup script there.
   - Install the systemd service to `/etc/systemd/system/sonobus.service`.
   - Enable the service to start on boot.

## Configuration

Edit `/opt/sonobus/rpi/start_sonobus.sh` to set your preferences.

**Method A: Using Command Line Args (Simple)**
Edit variables `USERNAME`, `GROUP_NAME`, etc. in the script.

**Method B: Using a Settings File (Advanced)**
1. Run Sonobus with GUI on a desktop (or the Pi if you have a monitor).
2. Configure Audio settings (Input/Output devices, Sample Rate, etc.) and Connection preferences.
3. Use "File -> Save Setup..." to save a `.settings` file.
4. Copy this file to the Pi (e.g., `~/.config/sonobus/headless.settings`).
5. Point the `SETUP_FILE` variable in `start_sonobus.sh` to this path.
   *Note: Ensure the audio device names in the settings file match what the Pi sees.*

## Usage

- Start manually: `sudo systemctl start sonobus`
- Stop: `sudo systemctl stop sonobus`
- Check status: `sudo systemctl status sonobus`
- View logs: `journalctl -u sonobus -f`

## Remote Management (Web Interface)

Sonobus RPi Headless now includes a simple Web Configurator!

**Accessing the Configurator:**
1. Open a browser and go to: `http://<IP-OF-PI>:8080`
2. You can change:
   - Display Username
   - Group Name
   - Group Password
   - Connection Server
3. Click **Save and Restart**. The Raspberry Pi will update its config and restart the Sonobus audio service automatically.

**Manual SSH Management (Advanced):**
If you prefer SSH, you can simply edit `/opt/sonobus/rpi/config.env` and run `sudo systemctl restart sonobus`.

---

## Automatic Image Creation (Image Builder)

Instead of setting up the Pi manually, you can create a pre-configured `.img` file that you can flash to any SD card.

### Prerequisites
- Docker (with Buildx support)
- A Linux host (for mounting the image)
- `qemu-user-static` (install via `sudo apt install qemu-user-static`)
- A fresh Raspberry Pi OS Lite image (`.img` file)

### Step 1: Build Sonobus for ARM64
Run the builder script to compile Sonobus for Raspberry Pi using Docker:
```bash
cd rpi/image_builder
./build_binary.sh
```
This produces a `sonobus_arm64` binary in `rpi/image_builder/artifacts/`.

### Step 2: Inject into Image
Run the image builder script with your Raspberry Pi OS image:
```bash
sudo ./build_image.sh /path/to/2023-05-03-raspios-bullseye-arm64-lite.img
```
This will:
1. Mount the image.
2. Install the compiled Sonobus binary.
3. Install the systemd services and config scripts.
4. Enable auto-start on boot.

### Step 3: Flash
Flash the modified `.img` file to your SD card using *Raspberry Pi Imager* or `dd`.
When the Pi boots, Sonobus will start automatically.


