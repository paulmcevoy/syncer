#!/usr/bin/env python3

import os
import subprocess
import datetime
import sys
import argparse
from dotenv import load_dotenv  # Import dotenv to load environment variables
from send_sms import send_sms  # Import the send_sms function

# Load environment variables from .env file
load_dotenv()

# Configuration variables sourced from environment variables
SOURCE_DIR = os.getenv("SOURCE_DIR")
print(f"SOURCE_DIR: {SOURCE_DIR}")

DEST_DIR = os.getenv("DEST_DIR")
print(f"DEST_DIR: {DEST_DIR}")

MOUNT_POINT = os.getenv("MOUNT_POINT")
print(f"MOUNT_POINT: {MOUNT_POINT}")

LOG_FILE = "sync.log"

def log_message(message):
    """Log a message with a timestamp to the log file."""
    timestamp = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    log_entry = f"{timestamp} - {message}"
    print(log_entry)
    with open(LOG_FILE, "a") as log_file:
        log_file.write(log_entry + "\n")

def sync_directories(is_initial_sync=True):
    """Sync directories using rsync."""
    if is_initial_sync:
        log_message(f"Starting INITIAL sync from {SOURCE_DIR} to {DEST_DIR}")
    else:
        log_message(f"Starting RESYNC from {SOURCE_DIR} to {DEST_DIR}")
    
    rsync_command = [
        "rsync", "-avz", "--delete", "--stats",
        f"{SOURCE_DIR}/", f"{DEST_DIR}/"
    ]

    try:
        # Capture rsync output to a string
        result = subprocess.run(rsync_command, capture_output=True, text=True)
        
        # Append rsync output to the log file
        with open(LOG_FILE, "a") as log_file:
            log_file.write("\n--- RSYNC OUTPUT START ---\n")
            log_file.write(result.stdout)
            if result.stderr:
                log_file.write("\n--- RSYNC STDERR ---\n")
                log_file.write(result.stderr)
            log_file.write("\n--- RSYNC OUTPUT END ---\n\n")
        
        if result.returncode == 0:
            log_message("Sync completed successfully")
            
            # Parse stats directly from the output
            files_count = created_count = deleted_count = "unknown"
            for line in result.stdout.splitlines():
                if line.startswith("Number of files:"):
                    files_count = line.split(":")[1].strip().split()[0]
                elif line.startswith("Number of created files:"):
                    created_count = line.split(":")[1].strip().split()[0]
                elif line.startswith("Number of deleted files:"):
                    deleted_count = line.split(":")[1].strip().split()[0]
            
            # Check if there were any changes
            has_changes = (created_count != "0" and created_count != "unknown") or (deleted_count != "0" and deleted_count != "unknown")
            
            msg = f"Sync completed: {files_count} files processed, {created_count} created, {deleted_count} deleted."
            log_message(msg)
            
            # Only send SMS if it's an initial sync or if there were changes
            if is_initial_sync or has_changes:
                if is_initial_sync:
                    sms_msg = f"INITIAL {msg}"
                else:
                    sms_msg = f"RESYNC {msg}"
                
                send_sms(message=sms_msg, to=os.environ.get("TO_PHONE_NUMBER"), mgs=os.environ.get("MGS"))
                log_message(f"SMS notification sent: {sms_msg}")
            else:
                log_message("No changes detected in resync, SMS notification skipped")
        else:
            log_message(f"Error: Sync failed with exit code {result.returncode}")
            log_message("Check sync.log for details")
    except Exception as e:
        log_message(f"Error: {str(e)}")

def main():
    """Main function to execute the script."""
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='Sync directories using rsync')
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--initial', action='store_true', help='Initial sync when drive is first mounted')
    group.add_argument('--resync', action='store_true', help='Resync after drive has been mounted for a while')
    parser.add_argument('--message', help='Optional message to log')
    args = parser.parse_args()
    
    # Determine if this is an initial sync or a resync
    is_initial_sync = not args.resync  # Default to initial sync if not specified as resync
    
    # Ensure the log file exists
    try:
        open(LOG_FILE, "a").close()
    except Exception as e:
        print(f"Error: Cannot create log file at {LOG_FILE}. {str(e)}")
        sys.exit(1)

    if args.message:
        log_message(args.message)
    
    log_message(f"Script started - {'INITIAL SYNC' if is_initial_sync else 'RESYNC'}")
            
    # Check if the destination directory exists
    if os.path.isdir(DEST_DIR):
        sync_directories(is_initial_sync)
        return
    else:
        # Try to create the destination directory
        try:
            os.makedirs(DEST_DIR, exist_ok=True)
            log_message(f"Created destination directory {DEST_DIR}")
            sync_directories(is_initial_sync)
            return
        except Exception as e:
            log_message(f"Error: Could not create destination directory {DEST_DIR}. {str(e)}")

if __name__ == "__main__":
    main()