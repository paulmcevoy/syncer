#!/bin/bash
#
# Installation Script for Drive Monitor
#
# This script sets up the drive monitor service for the current user.

# Configuration
SCRIPT_DIR="$PWD"
SERVICE_NAME="drive-monitor"
SERVICE_FILE="$SCRIPT_DIR/$SERVICE_NAME.service"
MONITOR_SCRIPT="$SCRIPT_DIR/drive_monitor.sh"
LOGGER_SCRIPT="$SCRIPT_DIR/drive_logger.py"
LOG_FILE="$SCRIPT_DIR/sync.log"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
VENV_DIR="$SCRIPT_DIR/.venv"
REQUIREMENTS_FILE="$SCRIPT_DIR/requirements.txt"

# Function to display status messages
echo_status() {
    echo "===> $1"
}

# Check if Python virtual environment exists
if [ -d "$VENV_DIR" ]; then
    echo_status "Virtual environment already exists, skipping Python setup"
else
    # Set up Python virtual environment
    echo_status "Setting up Python virtual environment"
    
    # Create new virtual environment
    echo_status "Creating new virtual environment"
    python3 -m venv "$VENV_DIR"
    
    # Activate virtual environment and install requirements
    echo_status "Installing dependencies from requirements.txt"
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip
    if [ -f "$REQUIREMENTS_FILE" ]; then
        pip install -r "$REQUIREMENTS_FILE"
    else
        echo_status "WARNING: requirements.txt not found at $REQUIREMENTS_FILE"
    fi
    deactivate
fi

# Make scripts executable
echo_status "Making scripts executable"
chmod +x "$MONITOR_SCRIPT" "$LOGGER_SCRIPT"

# Create initial log file if it doesn't exist
echo_status "Creating initial log file"
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
    echo "$(date "+%Y-%m-%d %H:%M:%S"): Drive monitor service installed" > "$LOG_FILE"
else
    echo "$(date "+%Y-%m-%d %H:%M:%S"): Drive monitor service reinstalled" >> "$LOG_FILE"
fi

# Create systemd user directory if it doesn't exist
echo_status "Setting up systemd user directory"
mkdir -p "$SYSTEMD_USER_DIR"

# Update and install service file to systemd user directory
echo_status "Updating service file with current working directory"
# Read the service file, replace <MAKE_PWD> with current directory, and write to systemd user directory
sed "s|<MAKE_PWD>|$PWD|g" "$SERVICE_FILE" > "$SYSTEMD_USER_DIR/$SERVICE_NAME.service"
echo_status "Service file installed with path: $PWD"

# Reload systemd user daemon
echo_status "Reloading systemd user daemon"
systemctl --user daemon-reload

# Completely stop and disable the service if it exists
echo_status "Stopping and disabling any existing service"
systemctl --user stop "$SERVICE_NAME.service" 2>/dev/null
systemctl --user disable "$SERVICE_NAME.service" 2>/dev/null
sleep 2  # Give it time to fully stop

# Kill any running instances of the drive_monitor.sh script (but not this install script)
echo_status "Killing any running instances of drive_monitor.sh"
ps aux | grep "[d]rive_monitor.sh" | grep -v "install_drive_monitor.sh" | awk '{print $2}' | xargs -r kill 2>/dev/null
sleep 1

# Clean up any existing PID files
echo_status "Cleaning up any existing PID files"
PID_FILE="$SCRIPT_DIR/drive_monitor.pid"
if [ -f "$PID_FILE" ]; then
    echo_status "Removing stale PID file: $PID_FILE"
    rm -f "$PID_FILE"
fi

# Also check for any old PID file in /tmp
OLD_PID_FILE="/tmp/drive_monitor.pid"
if [ -f "$OLD_PID_FILE" ]; then
    echo_status "Removing old PID file: $OLD_PID_FILE"
    rm -f "$OLD_PID_FILE"
fi
# Reload systemd to ensure it picks up any changes
echo_status "Reloading systemd"
systemctl --user daemon-reload

# Final steps: Enable and restart the service
echo_status "FINAL STEP: Enabling the drive-monitor.service"
systemctl --user enable "$SERVICE_NAME.service"

echo_status "FINAL STEP: Restarting the drive-monitor.service"
systemctl --user restart "$SERVICE_NAME.service"

# Wait a moment and check status
sleep 2
echo_status "Service status:"
systemctl --user status "$SERVICE_NAME.service"

echo_status "Installation complete!"
echo_status "You can check the service status with: systemctl --user status $SERVICE_NAME.service"
echo_status "You can view logs with: cat $LOG_FILE"
echo_status "You can view logs with: cat $LOG_FILE"