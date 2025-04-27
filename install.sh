#!/bin/bash

# Main installation script for the syncer system

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
VENV_DIR="${SCRIPT_DIR}/.venv"

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    print_error "Python 3 is required but not installed. Please install Python 3 and try again."
    exit 1
fi

# Check if pip is installed
if ! command -v pip3 &> /dev/null; then
    print_error "pip3 is required but not installed. Please install pip3 and try again."
    exit 1
fi

# Check if rsync is installed
if ! command -v rsync &> /dev/null; then
    print_warning "rsync is required but not installed. Please install rsync before using the sync functionality."
fi

# --- .env File Validation ---
ENV_FILE="${SCRIPT_DIR}/.env"
print_message "Checking for pre-configured .env file at ${ENV_FILE}..."
if [ ! -f "$ENV_FILE" ]; then
    print_error ".env file not found."
    print_error "Please copy .env.example to .env and configure it with your paths"
    print_error "(SOURCE_DIR, DEST_DIR, MOUNT_POINT, LOG_FILE) before running this script."
    exit 1
fi

print_message "Loading and validating configuration from ${ENV_FILE}..."
# Temporarily disable unbound variable errors just for sourcing
set +u
# Source the .env file - use '.' to source in the current shell
. "$ENV_FILE"
# Re-enable unbound variable errors if it was set before
# (This part is tricky, maybe better to just check variables directly)
set -u # Assuming we want errors for unbound variables generally

# Validate required variables
REQUIRED_VARS=("SOURCE_DIR" "DEST_DIR" "MOUNT_POINT" "LOG_FILE")
MISSING_VARS=()
for var in "${REQUIRED_VARS[@]}"; do
    # Use indirect expansion to check if the variable is set and non-empty
    if [ -z "${!var}" ]; then
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -ne 0 ]; then
    print_error "The following required variables are not set or are empty in ${ENV_FILE}:"
    for var in "${MISSING_VARS[@]}"; do
        print_error "  - ${var}"
    done
    print_error "Please configure these variables in ${ENV_FILE} and try again."
    exit 1
fi
print_message ".env file found and required variables are set."
# --- End .env File Validation ---


# Function to create .env file template (No longer needed as .env must exist)
# create_env_file() { ... } # Removed

# Create and activate virtual environment
create_virtual_environment() {
    # Check if virtual environment already exists

    # Set default log file in the current directory
    LOG_FILE="${SCRIPT_DIR}/sync.log"

    # Check if .env already exists
    if [ -f "${SCRIPT_DIR}/.env" ]; then
        print_warning "An .env file already exists. Creating .env.new instead."
        ENV_FILE="${SCRIPT_DIR}/.env.new"
    else
        ENV_FILE="${SCRIPT_DIR}/.env"
    fi

    # Copy the example file
    cp "${SCRIPT_DIR}/.env.example" "$ENV_FILE"

    # Update the log file path
    sed -i "s|LOG_FILE=.*|LOG_FILE=$LOG_FILE|g" "$ENV_FILE"

    print_message "Environment file template created at: $ENV_FILE"
    print_message "Please edit this file to set your configuration values before using the system."

    # If we created .env.new, provide instructions
    if [ "$ENV_FILE" = "${SCRIPT_DIR}/.env.new" ]; then
        print_message "To use the new configuration, rename .env.new to .env after editing:"
        print_message "  mv .env.new .env"
    fi
}

# Create and activate virtual environment
create_virtual_environment() {
    # Check if virtual environment already exists
    if [ -d "${VENV_DIR}" ] && [ -f "${VENV_DIR}/bin/activate" ]; then
        print_message "Using existing virtual environment at: ${VENV_DIR}"
    else
        print_message "Creating virtual environment..."
        python3 -m venv "${VENV_DIR}"

        if [ ! -d "${VENV_DIR}" ]; then
            print_error "Failed to create virtual environment."
            exit 1
        fi

        print_message "Virtual environment created at: ${VENV_DIR}"
    fi

    # Create activation script for convenience
    cat > "${SCRIPT_DIR}/activate_venv.sh" << EOF
#!/bin/bash
source "${VENV_DIR}/bin/activate"
echo "Virtual environment activated. Run 'deactivate' to exit."
EOF
    chmod +x "${SCRIPT_DIR}/activate_venv.sh"
    print_message "Created activation script: ./activate_venv.sh"

    # Activate the virtual environment for the installation process
    print_message "Activating virtual environment..."
    source "${VENV_DIR}/bin/activate"
}

# Install core module
install_core() {
    print_message "Installing core module..."
    pip install python-dotenv
    touch "${SCRIPT_DIR}/sync.log"
    chmod +x "${SCRIPT_DIR}/syncer.py"
    print_message "Core module installed successfully."
}

# Install SMS module (REMOVED)
# install_sms() { ... }

# Install Tidal module
install_tidal() {
    print_message "Installing Tidal module..."
    pip install tidal-dl-ng
    chmod +x "${SCRIPT_DIR}/tidal.py"
    print_message "Tidal module installed successfully."
}

# Install drive monitor (No longer needed - replaced by setup_mount_watcher.sh)
# install_drive_monitor() { ... } # Removed

# Create wrapper scripts that use the virtual environment
create_wrapper_scripts() {
    print_message "Creating wrapper scripts..."

    # Create wrappers for each Python script
    WRAPPER_SCRIPTS=("syncer.py")
    [ -f "${SCRIPT_DIR}/tidal.py" ] && WRAPPER_SCRIPTS+=("tidal.py")
    # [ -f "${SCRIPT_DIR}/send_sms.py" ] && WRAPPER_SCRIPTS+=("send_sms.py") # Removed SMS
    [ -f "${SCRIPT_DIR}/send_telegram.py" ] && WRAPPER_SCRIPTS+=("send_telegram.py")

    for script in "${WRAPPER_SCRIPTS[@]}"; do
        if [ -f "${SCRIPT_DIR}/${script}" ]; then
            # Create a wrapper script
            wrapper="${SCRIPT_DIR}/${script%.py}_wrapper.sh"
            cat > "$wrapper" << EOF
#!/bin/bash
# Wrapper script for ${script}
"${VENV_DIR}/bin/python" "${SCRIPT_DIR}/${script}" "\$@"
EOF
            chmod +x "$wrapper"

            # Update the original script shebang
            sed -i "1s|#!/usr/bin/env python3|#!${VENV_DIR}/bin/python|" "${SCRIPT_DIR}/${script}"
        fi
    done

    # Update drive_monitor.sh to use the virtual environment Python
    if [ -f "${SCRIPT_DIR}/drive_monitor.sh" ]; then
        sed -i "s|python3 \"\$SYNCER_SCRIPT\"|\"${VENV_DIR}/bin/python\" \"\$SYNCER_SCRIPT\"|g" "${SCRIPT_DIR}/drive_monitor.sh"
    fi

    print_message "Wrapper scripts created successfully."
}

# Main installation process
print_message "Starting installation..."
print_message "This script will install the syncer system with selected components."

# Prompt for component selection
read -p "Install core module? (y/n, default: y): " INSTALL_CORE
INSTALL_CORE=${INSTALL_CORE:-y}

if [ "$INSTALL_CORE" = "y" ]; then
    # read -p "Install SMS module? (y/n, default: n): " INSTALL_SMS # Removed SMS prompt
    # INSTALL_SMS=${INSTALL_SMS:-n} # Removed SMS prompt

    read -p "Install Tidal module? (y/n, default: n): " INSTALL_TIDAL
    INSTALL_TIDAL=${INSTALL_TIDAL:-n}

    # Prompt for notification method (Simplified: Telegram or None)
    NOTIFICATION_METHOD="none" # Default to none
    read -p "Enable Telegram notifications? (y/n, default: n): " ENABLE_TELEGRAM
    if [ "${ENABLE_TELEGRAM:-n}" = "y" ]; then
        NOTIFICATION_METHOD="telegram"
    fi

    # Add notification preference to .env file
    # Check if NOTIFICATION_METHOD is already in .env, if so, update it, otherwise append it
    if grep -q "^NOTIFICATION_METHOD=" "$ENV_FILE"; then
        print_message "Updating NOTIFICATION_METHOD in $ENV_FILE..."
        # Use a temporary file for sed compatibility across systems
        sed "s|^NOTIFICATION_METHOD=.*|NOTIFICATION_METHOD=${NOTIFICATION_METHOD}|" "$ENV_FILE" > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"
    else
        print_message "Adding NOTIFICATION_METHOD to $ENV_FILE..."
        echo "" >> "$ENV_FILE" # Add a newline for separation
        echo "# Notification method: telegram, or none" >> "$ENV_FILE" # Updated comment
        echo "NOTIFICATION_METHOD=${NOTIFICATION_METHOD}" >> "$ENV_FILE"
    fi


    # Drive monitor setup is now standard, no need to ask

    # Create requirements.txt based on selections
    echo "python-dotenv" > requirements.txt
    echo "requests" >> requirements.txt # Needed for Telegram

    # if [ "$INSTALL_SMS" = "y" ]; then # Removed SMS dependency
    #     echo "twilio" >> requirements.txt
    # fi

    if [ "$INSTALL_TIDAL" = "y" ]; then
        echo "tidal-dl-ng" >> requirements.txt
    fi

    # Create and activate virtual environment
    create_virtual_environment

    # Install Python dependencies
    print_message "Installing Python dependencies..."
    pip install -r requirements.txt

    # Install selected components
    install_core

    # if [ "$INSTALL_SMS" = "y" ]; then # Removed SMS install call
    #     install_sms
    # fi
    # No specific install function needed for telegram, just ensure requests is installed via requirements.txt
    # and ensure send_telegram.py is executable
    if [ -f "${SCRIPT_DIR}/send_telegram.py" ]; then
         chmod +x "${SCRIPT_DIR}/send_telegram.py"
    fi

    if [ "$INSTALL_TIDAL" = "y" ]; then
        install_tidal
    fi

    # Drive monitor setup is now handled by setup_mount_watcher.sh below

    # Create .env file template (No longer needed, user must provide .env)
    # create_env_file # Removed

    # print_message "NOTE: You must edit the .env file..." # Removed

    # Create wrapper scripts that use the virtual environment
    create_wrapper_scripts

    # --- Setup Systemd Path Watcher ---
    print_message "Setting up systemd path watcher for drive monitoring..."

    # Define systemd paths
    USER_SYSTEMD_DIR="${HOME}/.config/systemd/user"
    PATH_UNIT_FILE="${USER_SYSTEMD_DIR}/drive-mount-watcher.path"
    SERVICE_UNIT_FILE="${USER_SYSTEMD_DIR}/drive-sync.service"
    PYTHON_BIN="${VENV_DIR}/bin/python"
    SYNC_SCRIPT="${SCRIPT_DIR}/syncer.py"
    SYSTEMD_WRAPPER_SCRIPT="${SCRIPT_DIR}/systemd_sync_wrapper.sh" # New wrapper script path

    # Create user systemd directory if it doesn't exist
    print_message "Ensuring user systemd directory exists: ${USER_SYSTEMD_DIR}"
    mkdir -p "$USER_SYSTEMD_DIR"

    # Create path unit file
    print_message "Creating path unit file: ${PATH_UNIT_FILE}"
    cat > "$PATH_UNIT_FILE" << EOF
[Unit]
Description=Watch for drive mount at ${MOUNT_POINT}
Documentation=man:systemd.path(5)

[Path]
PathExists=${MOUNT_POINT}
Unit=drive-sync.service

[Install]
WantedBy=default.target
EOF

    # Create the systemd sync wrapper script
    print_message "Creating systemd sync wrapper script: ${SYSTEMD_WRAPPER_SCRIPT}"
    # Note: We use \$ within the heredoc for variables that should be evaluated
    # when the WRAPPER script runs, not when install.sh runs.
    cat > "$SYSTEMD_WRAPPER_SCRIPT" << EOF
#!/bin/bash
# Wrapper script called by drive-sync.service.
# Reads .env, prevents immediate run after install, and executes syncer.py.

# Determine the script's own directory to find .env
WRAPPER_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="\$WRAPPER_DIR/.env"
SERVICE_FILE="${USER_SYSTEMD_DIR}/drive-sync.service" # Systemd service file path (remains constant)

# Default values in case .env sourcing fails
LOG_FILE_PATH="\$WRAPPER_DIR/sync.log"
SCRIPT_DIR_PATH="\$WRAPPER_DIR"
SYNC_SCRIPT_PATH="\$WRAPPER_DIR/syncer.py"
VENV_DIR_PATH="\$WRAPPER_DIR/.venv"

# Function to log messages (similar to syncer.py but in bash)
log_message() {
    local message="\$1"
    local timestamp=\$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="\${timestamp} - SYSTEMD_WRAPPER - \${message}"
    echo "\$log_entry" # Also print to service logs/journald
    # Append to the main log file if possible
    if [ -n "\$LOG_FILE_PATH" ] && [ -w "\$(dirname "\$LOG_FILE_PATH")" ]; then
         echo "\$log_entry" >> "\$LOG_FILE_PATH"
    else
         echo "\${timestamp} - SYSTEMD_WRAPPER - WARNING: Could not write to log file \$LOG_FILE_PATH"
    fi
}

# Source .env file if it exists
if [ -f "\$ENV_FILE" ]; then
    log_message "Sourcing environment variables from \$ENV_FILE"
    # Use 'set -a' to export all variables sourced from .env for the python script
    set -a
    source "\$ENV_FILE"
    set +a
    # Update paths based on sourced SCRIPT_DIR if available
    if [ -n "\$SCRIPT_DIR" ]; then
        SCRIPT_DIR_PATH="\$SCRIPT_DIR"
        LOG_FILE_PATH="\${LOG_FILE:-\$SCRIPT_DIR_PATH/sync.log}" # Use LOG_FILE from .env or default
        SYNC_SCRIPT_PATH="\$SCRIPT_DIR_PATH/syncer.py"
        VENV_DIR_PATH="\$SCRIPT_DIR_PATH/.venv"
    fi
else
    log_message "WARNING: .env file not found at \$ENV_FILE. Using default paths."
fi

# Construct the Python binary path using the determined SCRIPT_DIR
PYTHON_BIN="\$VENV_DIR_PATH/bin/python"

# --- Grace Period Check ---
# Check if the service file exists and is readable
if [ ! -r "\$SERVICE_FILE" ]; then
    log_message "ERROR: Cannot read service file \$SERVICE_FILE. Running sync anyway."
    # Fall through to execution block
else
    # Get the modification time of the service file (in seconds since epoch)
    SERVICE_FILE_MTIME=\$(stat -c %Y "\$SERVICE_FILE" 2>/dev/null || date +%s) # Use current time if stat fails
    CURRENT_TIME=\$(date +%s)
    # Define a grace period in seconds (e.g., 120 seconds = 2 minutes)
    GRACE_PERIOD=120

    TIME_DIFF=\$((CURRENT_TIME - SERVICE_FILE_MTIME))

    if [ \$TIME_DIFF -lt \$GRACE_PERIOD ]; then
        log_message "Service triggered within \$GRACE_PERIOD seconds of installation (\${TIME_DIFF}s ago). Skipping first automatic sync."
        exit 0 # Exit successfully without running the sync
    fi
fi
# --- End Grace Period Check ---

log_message "Grace period passed or check skipped. Proceeding with initial sync."

# Check if Python executable exists
if [ ! -x "\$PYTHON_BIN" ]; then
    log_message "ERROR: Python executable not found or not executable at \$PYTHON_BIN"
    exit 1
fi

# Check if sync script exists
if [ ! -f "\$SYNC_SCRIPT_PATH" ]; then
    log_message "ERROR: Sync script not found at \$SYNC_SCRIPT_PATH"
    exit 1
fi

# Ensure we run from the correct directory so relative paths in syncer.py work
cd "\$SCRIPT_DIR_PATH" || { log_message "ERROR: Failed to change directory to \$SCRIPT_DIR_PATH"; exit 1; }

log_message "Executing: \$PYTHON_BIN \$SYNC_SCRIPT_PATH --initial"
# Execute the python script, ensuring it inherits the sourced environment variables
exec "\$PYTHON_BIN" "\$SYNC_SCRIPT_PATH" --initial

EOF
    chmod +x "$SYSTEMD_WRAPPER_SCRIPT"

    # Create service unit file
    print_message "Creating service unit file: ${SERVICE_UNIT_FILE}"
    cat > "$SERVICE_UNIT_FILE" << EOF
[Unit]
Description=Sync files when drive is mounted at ${MOUNT_POINT}
After=drive-mount-watcher.path

[Service]
Type=oneshot
# Execute the wrapper script instead of syncer.py directly
ExecStart=${SYSTEMD_WRAPPER_SCRIPT}
# Ensure the script runs with the correct environment, including the venv
# The wrapper script now handles changing directory and executing python
# Environment="PATH=${VENV_DIR}/bin:\$PATH" # Keep PATH for safety, wrapper uses absolute paths
# Set the working directory to where the scripts are located
WorkingDirectory=${SCRIPT_DIR}
# Log output to journald
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF

    # Enable and Start Units
    print_message "Reloading systemd user daemon..."
    systemctl --user daemon-reload

    print_message "Enabling the path unit to start on login..."
    systemctl --user enable drive-mount-watcher.path

    print_message "Starting the path unit now..."
    systemctl --user start drive-mount-watcher.path

    print_message "Systemd drive mount watcher setup complete!"
    # --- End Systemd Path Watcher Setup ---

    print_message "Installation completed successfully!"
    print_message "Drive monitoring is active via systemd path units."
    print_message "You can now use the system. Key commands:"
    print_message "  - Activate the virtual environment: source ./activate_venv.sh"
    print_message "  - Manual Sync: ./syncer_wrapper.sh [--initial|--resync]"

    if [ "$INSTALL_TIDAL" = "y" ]; then
        print_message "  - Tidal Download: ./tidal_wrapper.sh <tidal_url>"
    fi

    # if [ "$NOTIFICATION_METHOD" = "sms" ] && [ -f "${SCRIPT_DIR}/send_sms_wrapper.sh" ]; then # Removed SMS test message
    #     print_message "  - Send Test SMS: ./send_sms_wrapper.sh \"Test message\""
    if [ "$NOTIFICATION_METHOD" = "telegram" ] && [ -f "${SCRIPT_DIR}/send_telegram_wrapper.sh" ]; then
         print_message "  - Send Test Telegram: ./send_telegram_wrapper.sh \"Test message\""
    fi
    print_message "  - Check systemd units: systemctl --user status drive-mount-watcher.path drive-sync.service"
    print_message "  - View sync logs: journalctl --user -u drive-sync.service (or check ${LOG_FILE})"
else
    print_message "Installation cancelled."
fi