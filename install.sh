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

# Function to create .env file template
create_env_file() {
    print_message "Creating .env file template..."
    
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

# Install SMS module
install_sms() {
    print_message "Installing SMS module..."
    pip install twilio
    chmod +x "${SCRIPT_DIR}/send_sms.py"
    print_message "SMS module installed successfully."
}

# Install Tidal module
install_tidal() {
    print_message "Installing Tidal module..."
    pip install tidal-dl-ng
    chmod +x "${SCRIPT_DIR}/tidal.py"
    print_message "Tidal module installed successfully."
}

# Install drive monitor
install_drive_monitor() {
    print_message "Installing drive monitor..."
    chmod +x "${SCRIPT_DIR}/drive_monitor.sh"
    chmod +x "${SCRIPT_DIR}/install_drive_monitor.sh"
    
    print_message "Installing drive monitor service as a user service (no sudo required)..."
    "${SCRIPT_DIR}/install_drive_monitor.sh"
}

# Create wrapper scripts that use the virtual environment
create_wrapper_scripts() {
    print_message "Creating wrapper scripts..."
    
    # Create wrappers for each Python script
    for script in syncer.py tidal.py send_sms.py; do
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
    read -p "Install SMS module? (y/n, default: n): " INSTALL_SMS
    INSTALL_SMS=${INSTALL_SMS:-n}
    
    read -p "Install Tidal module? (y/n, default: n): " INSTALL_TIDAL
    INSTALL_TIDAL=${INSTALL_TIDAL:-n}
    
    read -p "Install drive monitor? (y/n, default: n): " INSTALL_DRIVE_MONITOR
    INSTALL_DRIVE_MONITOR=${INSTALL_DRIVE_MONITOR:-n}
    
    # Create requirements.txt based on selections
    echo "python-dotenv" > requirements.txt
    
    if [ "$INSTALL_SMS" = "y" ]; then
        echo "twilio" >> requirements.txt
    fi
    
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
    
    if [ "$INSTALL_SMS" = "y" ]; then
        install_sms
    fi
    
    if [ "$INSTALL_TIDAL" = "y" ]; then
        install_tidal
    fi
    
    if [ "$INSTALL_DRIVE_MONITOR" = "y" ]; then
        install_drive_monitor
    fi
    
    # Create .env file template
    create_env_file
    
    print_message "NOTE: You must edit the .env file with your configuration before using the system."
    
    # Create wrapper scripts that use the virtual environment
    create_wrapper_scripts
    
    print_message "Installation completed successfully!"
    print_message "You can now use the system with the following commands:"
    print_message "  - Activate the virtual environment: source ./activate_venv.sh"
    print_message "  - Core sync: ./syncer.py [--initial|--resync]"
    
    if [ "$INSTALL_TIDAL" = "y" ]; then
        print_message "  - Tidal download: ./tidal.py <tidal_url>"
    fi
    
    if [ "$INSTALL_DRIVE_MONITOR" = "y" ]; then
        print_message "  - Drive monitor: ./drive_monitor.sh (or use the systemd service)"
    fi
else
    print_message "Installation cancelled."
fi