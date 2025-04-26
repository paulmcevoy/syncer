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

# Remove environment files
if [ -f "${SCRIPT_DIR}/.env" ]; then
    print_message "Removing .env file..."
    rm "${SCRIPT_DIR}/.env"
fi

if [ -f "${SCRIPT_DIR}/.env.new" ]; then
    print_message "Removing .env.new file..."
    rm "${SCRIPT_DIR}/.env.new"
fi

# Remove wrapper scripts
print_message "Removing wrapper scripts..."
rm -f "${SCRIPT_DIR}/syncer_wrapper.sh"
rm -f "${SCRIPT_DIR}/tidal_wrapper.sh"
rm -f "${SCRIPT_DIR}/send_sms_wrapper.sh"

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

# Remove any systemd user service
USER_SYSTEMD_DIR="${HOME}/.config/systemd/user"
if [ -f "${USER_SYSTEMD_DIR}/drive-monitor.service" ]; then
    print_message "Removing systemd user service..."
    systemctl --user stop drive-monitor.service 2>/dev/null
    systemctl --user disable drive-monitor.service 2>/dev/null
    rm "${USER_SYSTEMD_DIR}/drive-monitor.service"
    systemctl --user daemon-reload
fi

# Reset shebangs in Python files
print_message "Resetting Python shebangs..."
sed -i "1s|^#!.*$|#!/usr/bin/env python3|" "${SCRIPT_DIR}/syncer.py"
sed -i "1s|^#!.*$|#!/usr/bin/env python3|" "${SCRIPT_DIR}/tidal.py"
sed -i "1s|^#!.*$|#!/usr/bin/env python3|" "${SCRIPT_DIR}/send_sms.py"

print_message "Cleanup completed successfully!"
print_message "The directory is now clean as if freshly cloned from git."