
import os
import subprocess
import datetime
import sys
import argparse
from dotenv import load_dotenv

# Conditionally import SMS module if available (REMOVED)
# (SMS related code removed here)

# Conditionally import Telegram module if available
try:
    from send_telegram import send_telegram_message
    TELEGRAM_AVAILABLE = True
except ImportError:
    TELEGRAM_AVAILABLE = False

# Load environment variables if not already loaded
if not os.getenv("SOURCE_DIR"):
    load_dotenv()

# Configuration variables sourced from environment variables
SOURCE_DIR = os.getenv("SOURCE_DIR")
DEST_DIR = os.getenv("DEST_DIR")
MOUNT_POINT = os.getenv("MOUNT_POINT")
LOG_FILE = os.getenv("LOG_FILE", "sync.log")  # Default to local directory
NOTIFICATION_METHOD = os.getenv("NOTIFICATION_METHOD", "none").lower() # Get notification preference, default to none

# Only print these when running as a standalone script
if __name__ == "__main__":
    print(f"SOURCE_DIR: {SOURCE_DIR}")
    print(f"DEST_DIR: {DEST_DIR}")
    print(f"MOUNT_POINT: {MOUNT_POINT}")
    print(f"LOG_FILE: {LOG_FILE}") # Corrected indentation
    print(f"NOTIFICATION_METHOD: {NOTIFICATION_METHOD}") # Corrected indentation

def log_message(message):
    """Log a message with a timestamp to the log file.""" # Corrected indentation
    timestamp = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S') # Corrected indentation
    log_entry = f"{timestamp} - SYNCER - {message}"
    print(log_entry)
    try:
        with open(LOG_FILE, "a") as log_file:
            log_file.write(log_entry + "\n")
    except Exception as e:
        print(f"Error writing to log file: {str(e)}")

def sync_directories(is_initial_sync=True):
    """Sync directories using rsync."""
    if is_initial_sync:
        log_mes = f"Starting INITIAL sync from {SOURCE_DIR} to {DEST_DIR}"
        log_message(log_mes)
        # Send initial sync notification (simple message)
        send_notification(log_mes) # Use the new function
    else:
        log_message(f"Starting RESYNC from {SOURCE_DIR} to {DEST_DIR}")

    rsync_command = [
        "rsync", "-avz", "--delete", "--stats",
        f"{SOURCE_DIR}/", f"{DEST_DIR}/"
    ]

    try:
        # Capture rsync output to a string
        result = subprocess.run(rsync_command, capture_output=True, text=True)
        
        # Filter the rsync output to only show audio files and exclude LRC files
        filtered_output = []
        for line in result.stdout.splitlines():
            # Skip lines containing .lrc files
            if ".lrc" in line.lower():
                continue
                
            # Include lines with audio file extensions or summary lines
            if any(ext in line.lower() for ext in [".flac", ".mp3", ".wav", ".aac", ".m4a", ".ogg"]) or \
               any(text in line for text in ["Number of files", "Number of created files", "Number of deleted files", "Total file size"]):
                filtered_output.append(line)
        
        # Append filtered rsync output to the log file
        with open(LOG_FILE, "a") as log_file:
            log_file.write("\n--- RSYNC OUTPUT START (FILTERED FOR AUDIO FILES) ---\n")
            log_file.write("\n".join(filtered_output))
            if result.stderr:
                log_file.write("\n--- RSYNC STDERR ---\n")
                log_file.write(result.stderr)
            log_file.write("\n--- RSYNC OUTPUT END ---\n\n")
        
        if result.returncode == 0:
            log_message("Sync completed successfully")
            
            # Parse stats directly from the output
            files_count = created_count = deleted_count = "unknown"
            created_audio_count = 0
            created_lrc_count = 0
            created_dir_count = 0
            
            # First pass to get the basic counts
            for line in result.stdout.splitlines():
                if line.startswith("Number of files:"):
                    files_count = line.split(":")[1].strip().split()[0]
                elif line.startswith("Number of created files:"):
                    created_info = line.split(":")[1].strip()
                    created_count = created_info.split()[0]
                    # Check if there's a breakdown of file types
                    if "reg:" in created_info and "dir:" in created_info:
                        reg_part = created_info.split("reg:")[1].split(",")[0].strip()
                        dir_part = created_info.split("dir:")[1].strip()
                        created_dir_count = int(dir_part)
                elif line.startswith("Number of deleted files:"):
                    deleted_count = line.split(":")[1].strip().split()[0]
            
            # Second pass to count audio files vs lrc files
            for line in result.stdout.splitlines():
                if ".flac" in line.lower() or ".mp3" in line.lower() or ".wav" in line.lower() or ".aac" in line.lower() or ".m4a" in line.lower() or ".ogg" in line.lower():
                    if not line.startswith("deleting "):
                        created_audio_count += 1
                elif ".lrc" in line.lower() and not line.startswith("deleting "):
                    created_lrc_count += 1
            
            # Check if there were any changes
            has_changes = (created_count != "0" and created_count != "unknown") or (deleted_count != "0" and deleted_count != "unknown")
            
            # Create a detailed message
            msg = f"Sync completed: {files_count} files processed, {created_count} created, {deleted_count} deleted."
            
            # Add detailed breakdown if files were created
            if created_count != "0" and created_count != "unknown":
                log_message(msg)
                
                # Add a more detailed breakdown in the requested format
                breakdown_msg = (
                    f"File breakdown:\n"
                    f"- {created_audio_count} .flac files (audio tracks)\n"
                    f"- {created_lrc_count} .lrc files (lyrics files)\n"
                    f"- {created_dir_count} directories\n"
                    f"= {int(created_count)} total created files/directories"
                )
                log_message(breakdown_msg)
            else:
                log_message(msg)
            
            # Send notification if it's an initial sync or if there were changes
            if is_initial_sync or has_changes: # Corrected indentation
                # Create a detailed message for notification
                if created_count != "0" and created_count != "unknown": # Corrected indentation
                    simple_msg = (
                        f"{created_audio_count} .flac files (audio tracks), "
                        f"{created_lrc_count} .lrc files (lyrics files)"
                    )
                else: # Corrected indentation
                    simple_msg = f"0 files created, {deleted_count} deleted"

                if is_initial_sync: # Corrected indentation
                    notification_msg = f"INITIAL Sync: {simple_msg}"
                else: # Corrected indentation
                    notification_msg = f"RESYNC: {simple_msg}"

                # Use the send_notification function
                send_notification(notification_msg) # Corrected indentation

            elif has_changes: # Corrected indentation
                log_message(f"Changes detected, but notifications are disabled or unavailable (Method: {NOTIFICATION_METHOD})")
            else: # Corrected indentation
                log_message("No changes detected in resync, notification skipped")

            return True # Corrected indentation
        else: # Corrected indentation
            log_message(f"Error: Sync failed with exit code {result.returncode}")
            log_message("Check sync.log for details")
            return False # Corrected indentation
    except Exception as e:
        log_message(f"Error: {str(e)}")
        return False # Corrected indentation

# Define the path for the last notification log file relative to this script's location
LAST_NOTIFICATION_LOG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "last_notification.log")

def send_notification(message):
    """
    Send a notification using the configured method and save the message
    to last_notification.log, overwriting previous content.
    """
    # Write the message to the last notification log file (overwrite mode)
    try:
        with open(LAST_NOTIFICATION_LOG, "w", encoding='utf-8') as f: # Added encoding
            f.write(message)
        log_message(f"Last notification message saved to {LAST_NOTIFICATION_LOG}")
    except Exception as e:
        log_message(f"Error writing to {LAST_NOTIFICATION_LOG}: {str(e)}")
        # Continue with sending the notification even if saving fails

    # Proceed with sending the notification based on the configured method
    # if NOTIFICATION_METHOD == "sms": # Removed SMS block
    #     # (SMS sending logic removed here)
    #     pass
    if NOTIFICATION_METHOD == "telegram": # Changed from elif to if
        if TELEGRAM_AVAILABLE:
            try:
                success = send_telegram_message(message=message)
                if success:
                    log_message(f"Telegram notification sent: {message}")
                else:
                    log_message(f"Failed to send Telegram notification (check send_telegram logs).")
            except Exception as e:
                log_message(f"Error sending Telegram notification: {str(e)}")
        else:
            log_message("Telegram notification configured, but send_telegram module not available.")
    elif NOTIFICATION_METHOD != "none": # Corrected indentation
        log_message(f"Unknown notification method configured: {NOTIFICATION_METHOD}")
    # No action needed if NOTIFICATION_METHOD is "none"

def run_sync(is_initial_sync=True, custom_message=None):
    """ # Corrected indentation
    Run the sync operation programmatically.

    Args:
        is_initial_sync (bool): Whether this is an initial sync or a resync
        custom_message (str, optional): Optional message to log

    Returns:
        bool: True if sync was successful, False otherwise
    """
    # Ensure the log file exists
    try: # Corrected indentation
        open(LOG_FILE, "a").close()
    except Exception as e:
        print(f"Error: Cannot create log file at {LOG_FILE}. {str(e)}")
        return False

    if custom_message:
        log_message(custom_message)

    log_message(f"Sync operation started - {'INITIAL SYNC' if is_initial_sync else 'RESYNC'}")

    # Check if the destination directory exists
    if os.path.isdir(DEST_DIR):
        return sync_directories(is_initial_sync)
    else:
        log_message(f"Error: Destination directory not found: {DEST_DIR}")
        log_message("Is the drive connected?")
        return False

def main():
    """Main function to execute the script when run directly."""
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='Sync directories using rsync')
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--initial', action='store_true', help='Initial sync when drive is first mounted')
    group.add_argument('--resync', action='store_true', help='Resync after drive has been mounted for a while')
    parser.add_argument('--message', help='Optional message to log')
    
    # Check if being run as a script or imported
    if len(sys.argv) > 1:
        args = parser.parse_args()
        
        # Determine if this is an initial sync or a resync
        is_initial_sync = not args.resync  # Default to initial sync if not specified as resync
        
        # Run the sync with command line arguments
        run_sync(is_initial_sync, args.message)
    else:
        # Default behavior when called without arguments (e.g., from another script)
        run_sync(is_initial_sync=False, custom_message="Sync triggered by another script")

if __name__ == "__main__":
    main()