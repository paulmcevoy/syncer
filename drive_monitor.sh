#!/bin/bash
#
# Drive Monitor Script - Simplified Version
#
# This script monitors /proc/mounts for the presence of an external drive
# at the specified mount point and calls a Python script when detected.

# Configuration - Use absolute paths to avoid any path-related issues
SCRIPT_DIR="$PWD/syncer"
ENV_FILE="$SCRIPT_DIR/.env"
LOG_FILE="$SCRIPT_DIR/sync.log"
CHECK_INTERVAL=5  # seconds
RESYNC_INTERVAL=600  # 1 minute in seconds

# Function to log messages
log_message() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "$timestamp: $1" >> "$LOG_FILE"
    echo "$timestamp: $1"  # Also print to stdout for debugging
}

# Create log file if it doesn't exist
touch "$LOG_FILE"
log_message "Drive monitor starting"

# Read MOUNT_POINT from .env file
if [ -f "$ENV_FILE" ]; then
    # Extract MOUNT_POINT value from .env file
    MOUNT_POINT=$(grep "^MOUNT_POINT" "$ENV_FILE" | sed 's/MOUNT_POINT *= *//;s/^"//;s/"$//' | tr -d '"')
    if [ -z "$MOUNT_POINT" ]; then
        log_message "Error: MOUNT_POINT not found in $ENV_FILE"
        exit 1
    fi
    log_message "Using mount point: $MOUNT_POINT"
else
    log_message "Error: .env file not found at $ENV_FILE"
    exit 1
fi

PYTHON_EXEC="$SCRIPT_DIR/.venv/bin/python"
LOGGER_SCRIPT="$SCRIPT_DIR/syncer.py"

# Function to check if drive is mounted
is_drive_mounted() {
    grep -q " $MOUNT_POINT " /proc/mounts
    return $?
}

# Function to run the Python logger
run_logger() {
    local sync_type=$1  # "initial" or "resync"
    
    if [ "$sync_type" = "initial" ]; then
        log_message "Drive detected at $MOUNT_POINT, running INITIAL sync"
        sync_param="--initial"
    else
        log_message "Drive still mounted, running RESYNC"
        sync_param="--resync"
    fi
    
    if [ -x "$PYTHON_EXEC" ] && [ -f "$LOGGER_SCRIPT" ]; then
        "$PYTHON_EXEC" "$LOGGER_SCRIPT" $sync_param --message "External drive mounted at $MOUNT_POINT"
        if [ $? -eq 0 ]; then
            log_message "Logger script executed successfully"
        else
            log_message "ERROR: Logger script failed with exit code $?"
        fi
    else
        log_message "ERROR: Python executable or logger script not found"
        log_message "Python path: $PYTHON_EXEC"
        log_message "Logger script: $LOGGER_SCRIPT"
    fi
}

# Main monitoring loop
log_message "Drive monitor started"
drive_was_mounted=false
last_sync_time=0

# Handle termination signals
trap 'log_message "Drive monitor stopping"; exit 0' TERM INT

# Simple monitoring loop
while true; do
    current_time=$(date +%s)
    
    if is_drive_mounted; then
        if [ "$drive_was_mounted" = false ]; then
            # Initial sync when drive is first mounted
            run_logger "initial"
            last_sync_time=$(date +%s)
            drive_was_mounted=true
            log_message "Drive mounted, initial sync completed at $(date)"
        else
            # Check if it's time for a resync (1 minute since last sync)
            time_since_last_sync=$((current_time - last_sync_time))
            
            if [ $time_since_last_sync -ge $RESYNC_INTERVAL ]; then
                log_message "Drive still mounted after $time_since_last_sync seconds, running resync"
                run_logger "resync"
                last_sync_time=$(date +%s)
                log_message "Resync completed at $(date)"
            fi
        fi
    else
        if [ "$drive_was_mounted" = true ]; then
            log_message "Drive unmounted, resuming monitoring"
            drive_was_mounted=false
            last_sync_time=0
        fi
    fi
    
    sleep $CHECK_INTERVAL
done