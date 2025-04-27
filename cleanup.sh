    #!/bin/bash

# Cleanup script for the syncer system
# This script removes all files generated during the installation process

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_message "Starting cleanup process..."
print_message "This will remove all files generated during installation."
read -p "Are you sure you want to continue? (y/n, default: n): " CONFIRM
CONFIRM=${CONFIRM:-n}

if [ "$CONFIRM" != "y" ]; then
    print_message "Cleanup cancelled."
    exit 0
fi

# Remove virtual environment
if [ -d "${SCRIPT_DIR}/.venv" ]; then
    print_message "Removing virtual environment..."
    rm -rf "${SCRIPT_DIR}/.venv"
fi

# Remove activation script
if [ -f "${SCRIPT_DIR}/activate_venv.sh" ]; then
    print_message "Removing activation script..."
    rm "${SCRIPT_DIR}/activate_venv.sh"
fi

# Remove log files
print_message "Removing log files..."
rm -f "${SCRIPT_DIR}/sync.log"
rm -f "${SCRIPT_DIR}/tidal.log"

# Remove environment files (KEEPING .env)
# if [ -f "${SCRIPT_DIR}/.env" ]; then
#     print_message "Removing .env file..."
#     rm "${SCRIPT_DIR}/.env"
# fi
print_message "Skipping removal of .env file to preserve configuration."

if [ -f "${SCRIPT_DIR}/.env.new" ]; then
    print_message "Removing .env.new file..."
    rm "${SCRIPT_DIR}/.env.new"
fi

# Remove wrapper scripts
print_message "Removing wrapper scripts..."
rm -f "${SCRIPT_DIR}/syncer_wrapper.sh"
rm -f "${SCRIPT_DIR}/tidal_wrapper.sh"
# rm -f "${SCRIPT_DIR}/send_sms_wrapper.sh" # Already removed
rm -f "${SCRIPT_DIR}/send_telegram_wrapper.sh"
rm -f "${SCRIPT_DIR}/systemd_sync_wrapper.sh"

# Remove downloads directory
if [ -d "${SCRIPT_DIR}/downloads" ]; then
    print_message "Removing downloads directory..."
    rm -rf "${SCRIPT_DIR}/downloads"
fi

# Remove __pycache__ directories
print_message "Removing Python cache files..."
find "${SCRIPT_DIR}" -type d -name "__pycache__" -exec rm -rf {} +
find "${SCRIPT_DIR}" -type f -name "*.pyc" -delete
find "${SCRIPT_DIR}" -type f -name "*.pyo" -delete
find "${SCRIPT_DIR}" -type f -name "*.pyd" -delete

# Remove systemd user units created by setup_mount_watcher.sh
USER_SYSTEMD_DIR="${HOME}/.config/systemd/user"
PATH_UNIT_FILE="${USER_SYSTEMD_DIR}/drive-mount-watcher.path"
SERVICE_UNIT_FILE="${USER_SYSTEMD_DIR}/drive-sync.service"

# Stop and disable the path unit first
if systemctl --user is-active --quiet drive-mount-watcher.path; then
    print_message "Stopping systemd path unit..."
    systemctl --user stop drive-mount-watcher.path
fi
if systemctl --user is-enabled --quiet drive-mount-watcher.path; then
    print_message "Disabling systemd path unit..."
    systemctl --user disable drive-mount-watcher.path
fi

# Stop the service unit just in case it's running independently (unlikely)
if systemctl --user is-active --quiet drive-sync.service; then
    print_message "Stopping systemd service unit..."
    systemctl --user stop drive-sync.service
fi

# Remove the unit files
if [ -f "$PATH_UNIT_FILE" ]; then
    print_message "Removing systemd path unit file..."
    rm "$PATH_UNIT_FILE"
fi
if [ -f "$SERVICE_UNIT_FILE" ]; then
    print_message "Removing systemd service unit file..."
    rm "$SERVICE_UNIT_FILE"
fi

# Reload systemd if files were removed
if [ ! -f "$PATH_UNIT_FILE" ] || [ ! -f "$SERVICE_UNIT_FILE" ]; then
     print_message "Reloading systemd user daemon..."
     systemctl --user daemon-reload
fi

# Reset shebangs in Python files
print_message "Resetting Python shebangs..."
sed -i "1s|^#!.*$|#!/usr/bin/env python3|" "${SCRIPT_DIR}/syncer.py"
sed -i "1s|^#!.*$|#!/usr/bin/env python3|" "${SCRIPT_DIR}/tidal.py"
# sed -i "1s|^#!.*$|#!/usr/bin/env python3|" "${SCRIPT_DIR}/send_sms.py" # Removed SMS shebang reset
# Assuming send_telegram.py might have been modified, reset it too if it exists
if [ -f "${SCRIPT_DIR}/send_telegram.py" ]; then
    sed -i "1s|^#!.*$|#!/usr/bin/env python3|" "${SCRIPT_DIR}/send_telegram.py"
fi

print_message "Cleanup completed successfully!"
print_message "The directory is now clean as if freshly cloned from git."