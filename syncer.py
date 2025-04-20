import os
import subprocess
import datetime
import sys
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

LOG_FILE = os.getenv("LOG_FILE")
print(f"LOG_FILE: {LOG_FILE}")

LOG_DIR = os.getenv("LOG_DIR")
print(f"LOG_DIR: {LOG_DIR}")

# Ensure the log directory exists
os.makedirs(LOG_DIR, exist_ok=True)
def log_message(message):
    """Log a message with a timestamp to the log file."""
    timestamp = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    log_entry = f"{timestamp} - {message}"
    print(log_entry)
    with open(LOG_FILE, "a") as log_file:
        log_file.write(log_entry + "\n")

def is_mounted():
    """Check if the drive is mounted at the specified mount point."""
    result = subprocess.run(["mountpoint", "-q", MOUNT_POINT], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return result.returncode == 0

def parse_rsync_stats(log_file):
    """Parse rsync stats from the log file."""
    files_count = created_count = deleted_count = "unknown"
    try:
        with open(log_file, "r") as f:
            for line in f:
                if line.startswith("Number of files:"):
                    files_count = line.split(":")[1].strip().split()[0]
                elif line.startswith("Number of created files:"):
                    created_count = line.split(":")[1].strip().split()[0]
                elif line.startswith("Number of deleted files:"):
                    deleted_count = line.split(":")[1].strip().split()[0]
    except FileNotFoundError:
        log_message(f"Error: Log file {log_file} not found.")
    return files_count, created_count, deleted_count

def sync_directories():
    """Sync directories using rsync."""
    timestamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
    rsync_log_file = os.path.join(LOG_DIR, f"rsync_sync_{timestamp}.log")
    stats_log_file = os.path.join(LOG_DIR, f"rsync_stats_{timestamp}.txt")

    log_message(f"Starting sync from {SOURCE_DIR} to {DEST_DIR}")
    log_message(f"Detailed rsync output will be saved to {rsync_log_file}")

    rsync_command = [
        "rsync", "-avz", "--delete", "--stats",
        f"{SOURCE_DIR}/", f"{DEST_DIR}/"
    ]

    try:
        with open(rsync_log_file, "w") as rsync_log, open(stats_log_file, "w") as stats_log:
            result = subprocess.run(rsync_command, stdout=rsync_log, stderr=subprocess.STDOUT)
            if result.returncode == 0:
                log_message("Sync completed successfully")
                log_message(f"Detailed rsync output saved to {rsync_log_file}")

                # Parse stats and log the summary
                files_count, created_count, deleted_count = parse_rsync_stats(rsync_log_file)
                msg = f"Sync completed: {files_count} files processed, {created_count} created, {deleted_count} deleted."
                send_sms(message=msg,to=os.environ.get("TO_PHONE_NUMBER"),mgs=os.environ.get("MGS"))

                log_message(msg)
            else:
                log_message(f"Error: Sync failed with exit code {result.returncode}")
                log_message(f"Check {rsync_log_file} for details")
    except Exception as e:
        log_message(f"Error: {str(e)}")
    finally:
        if os.path.exists(stats_log_file):
            os.remove(stats_log_file)

def main():
    """Main function to execute the script."""
    # Ensure the log file exists
    try:
        open(LOG_FILE, "a").close()
    except Exception as e:
        print(f"Error: Cannot create log file at {LOG_FILE}. {str(e)}")
        sys.exit(1)

    log_message("Script started")

    # Check if the drive is mounted
    if is_mounted():
        log_message(f"Drive detected at {MOUNT_POINT}")

        # Check if the destination directory exists
        if os.path.isdir(DEST_DIR):
            sync_directories()
        else:
            log_message(f"Error: Destination directory {DEST_DIR} not found")
            sys.exit(1)
    else:
        log_message(f"Drive not mounted at {MOUNT_POINT}. Exiting.")
        sys.exit(1)

if __name__ == "__main__":
    main()