#!/bin/bash

# Script to install the drive monitor service as a user service (no sudo required)

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
SERVICE_FILE="${SCRIPT_DIR}/drive-monitor.service"
MONITOR_SCRIPT="${SCRIPT_DIR}/drive_monitor.sh"
VENV_DIR="${SCRIPT_DIR}/.venv"

# Check if virtual environment exists
if [ ! -d "${VENV_DIR}" ]; then
    print_warning "Virtual environment not found at ${VENV_DIR}"
    print_warning "The drive monitor may not work correctly without the virtual environment."
    read -p "Continue anyway? (y/n, default: n): " CONTINUE
    CONTINUE=${CONTINUE:-n}
    
    if [ "$CONTINUE" != "y" ]; then
        print_message "Installation cancelled. Please run the main installation script first."
        exit 1
    fi
fi

# Check if the service file exists
if [ ! -f "$SERVICE_FILE" ]; then
    print_error "Service file not found: $SERVICE_FILE"
    exit 1
fi

# Check if the monitor script exists
if [ ! -f "$MONITOR_SCRIPT" ]; then
    print_error "Monitor script not found: $MONITOR_SCRIPT"
    exit 1
fi

# Make sure the monitor script is executable
chmod +x "$MONITOR_SCRIPT"
print_message "Made monitor script executable"

# Create user systemd directory if it doesn't exist
USER_SYSTEMD_DIR="${HOME}/.config/systemd/user"
mkdir -p "$USER_SYSTEMD_DIR"
print_message "Created user systemd directory: $USER_SYSTEMD_DIR"

# Create a temporary service file with the correct paths
TMP_SERVICE_FILE=$(mktemp)

# Replace the placeholder INSTALL_DIR with the actual script directory
cat "$SERVICE_FILE" | \
    sed "s|INSTALL_DIR|$SCRIPT_DIR|g" \
    > "$TMP_SERVICE_FILE"

# Add environment path if not present
if ! grep -q "Environment=" "$TMP_SERVICE_FILE"; then
    # Find the [Service] section and add the Environment line after it
    sed -i '/\[Service\]/a Environment="PATH='"$VENV_DIR"'/bin:$PATH"' "$TMP_SERVICE_FILE"
fi

# Remove the [Install] section and WantedBy=multi-user.target
# Replace with user-specific target
sed -i 's|WantedBy=multi-user.target|WantedBy=default.target|g' "$TMP_SERVICE_FILE"

# Copy the service file to the user systemd directory
cp "$TMP_SERVICE_FILE" "${USER_SYSTEMD_DIR}/drive-monitor.service"
rm "$TMP_SERVICE_FILE"
print_message "Installed service file to ${USER_SYSTEMD_DIR}/drive-monitor.service"

# Reload systemd to recognize the new service
systemctl --user daemon-reload
print_message "Reloaded user systemd daemon"

# Enable the service to start on login
systemctl --user enable drive-monitor.service
print_message "Enabled drive-monitor service to start on login"

# Enable lingering to allow the service to run without being logged in
loginctl enable-linger "$(whoami)"
print_message "Enabled lingering to allow service to run without being logged in"

# Start the service
systemctl --user start drive-monitor.service
print_message "Started drive-monitor service"

# Check the status
if systemctl --user is-active --quiet drive-monitor.service; then
    print_message "Drive monitor service is running"
else
    print_warning "Drive monitor service failed to start. Check status with: systemctl --user status drive-monitor.service"
fi

print_message "Installation complete!"
print_message "You can check the service status with: systemctl --user status drive-monitor.service"
print_message "You can view logs with: journalctl --user -u drive-monitor.service"