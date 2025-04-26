#!/bin/bash

# Drive Monitor Script
# This script monitors for drive connections and triggers syncs

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${SCRIPT_DIR}/.venv"
PYTHON_BIN="${VENV_DIR}/bin/python"

# Check if virtual environment exists
if [ ! -f "${PYTHON_BIN}" ]; then
    echo "Error: Virtual environment not found at ${VENV_DIR}"
    echo "Please run the installation script first."
    exit 1
fi

# Load environment variables from .env file
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "Error: .env file not found"
    exit 1
fi

# Configuration
SYNCER_SCRIPT="${SCRIPT_DIR}/syncer.py"
LOG_FILE="${LOG_FILE:-${SCRIPT_DIR}/sync.log}"
CHECK_INTERVAL=60  # Check every 60 seconds

# Function to log messages
log_message() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="$timestamp - DRIVE_MONITOR - $1"
    echo "$message"
    echo "$message" >> "$LOG_FILE"
}

# Function to check if drive is mounted
is_drive_mounted() {
    if [ -d "$MOUNT_POINT" ] && [ -d "$DEST_DIR" ]; then
        return 0  # True
    else
        return 1  # False
    fi
}

# Function to run the sync
run_sync() {
    local initial=$1
    local message="$2"
    
    if [ "$initial" = true ]; then
        log_message "Running initial sync..."
        "${PYTHON_BIN}" "$SYNCER_SCRIPT" --initial --message "$message"
    else
        log_message "Running resync..."
        "${PYTHON_BIN}" "$SYNCER_SCRIPT" --resync --message "$message"
    fi
}

# Main loop
log_message "Drive monitor started"

# Track if we've done an initial sync
INITIAL_SYNC_DONE=false

while true; do
    if is_drive_mounted; then
        if [ "$INITIAL_SYNC_DONE" = false ]; then
            log_message "Drive detected at $MOUNT_POINT"
            run_sync true "Drive detected and mounted"
            INITIAL_SYNC_DONE=true
            log_message "Initial sync completed. Monitoring for drive disconnection."
        fi
    else
        if [ "$INITIAL_SYNC_DONE" = true ]; then
            log_message "Drive disconnected from $MOUNT_POINT"
            INITIAL_SYNC_DONE=false
            log_message "Waiting for drive to be reconnected."
        fi
    fi
    
    # Wait before checking again
    sleep $CHECK_INTERVAL
done