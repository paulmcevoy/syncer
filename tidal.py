
import os
import sys
import subprocess
import datetime
import re
from dotenv import load_dotenv

# Conditionally import modules
try:
    import syncer
    SYNCER_AVAILABLE = True
except ImportError:
    SYNCER_AVAILABLE = False
    print("Warning: syncer module not available. Sync functionality will be disabled.")

try:
    from send_sms import send_sms
    SMS_AVAILABLE = True
except ImportError:
    SMS_AVAILABLE = False
    print("Warning: send_sms module not available. SMS notifications will be disabled.")

# Load environment variables if not already loaded
if not os.getenv("LOG_FILE"):
    load_dotenv()

# Get log file path from environment or use default
LOG_FILE = os.getenv("LOG_FILE", "tidal.log")

def log_message(message):
    """Log a message with a timestamp to the log file."""
    timestamp = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    log_entry = f"{timestamp} - TIDAL - {message}"
    print(log_entry)
    try:
        with open(LOG_FILE, "a") as log_file:
            log_file.write(log_entry + "\n")
    except Exception as e:
        print(f"Error writing to log file: {str(e)}")

def get_file_list(directory):
    """
    Get a list of all files in a directory and its subdirectories.
    
    Args:
        directory (str): The directory to scan
        
    Returns:
        list: A list of file paths
    """
    file_list = []
    for root, dirs, files in os.walk(directory):
        for file in files:
            file_list.append(os.path.join(root, file))
    return file_list

def count_file_types(before_files, after_files):
    """
    Count the number and types of new files by comparing before and after file lists.
    
    Args:
        before_files (list): List of files before the download
        after_files (list): List of files after the download
        
    Returns:
        dict: A dictionary containing file counts by type
    """
    # Find new files
    new_files = [f for f in after_files if f not in before_files]
    
    # Count file types
    flac_files = []
    lrc_files = []
    other_audio_files = []
    other_files = []
    
    for file in new_files:
        if file.lower().endswith('.flac'):
            flac_files.append(file)
        elif file.lower().endswith('.lrc'):
            lrc_files.append(file)
        elif any(file.lower().endswith(ext) for ext in ['.mp3', '.wav', '.aac', '.m4a', '.ogg']):
            other_audio_files.append(file)
        else:
            other_files.append(file)
    
    # Create a summary dictionary
    summary = {
        'total_new_files': len(new_files),
        'flac_files': len(flac_files),
        'lrc_files': len(lrc_files),
        'other_audio_files': len(other_audio_files),
        'other_files': len(other_files),
        'flac_file_list': flac_files,
        'lrc_file_list': lrc_files
    }
    
    return summary

def download_tidal(tidal_url):
    """
    Download content from Tidal using tidal-dl-ng and count the actual files downloaded.
    
    Args:
        tidal_url (str): The Tidal URL to download from
        
    Returns:
        tuple: (success, summary) where success is a boolean and summary is a dictionary
    """
    log_message(f"Starting Tidal download for URL: {tidal_url}")
    
    try:
        # Get the download directory from environment or use a relative default
        script_dir = os.path.dirname(os.path.abspath(__file__))
        default_download_dir = os.path.join(script_dir, "downloads")
        download_dir = os.getenv("TIDAL_DOWNLOAD_DIR", default_download_dir)
        
        # Create the download directory if it doesn't exist
        if not os.path.exists(download_dir):
            os.makedirs(download_dir, exist_ok=True)
            
        log_message(f"Using download directory: {download_dir}")
        
        # Get list of files before download
        log_message("Scanning files before download...")
        before_files = get_file_list(download_dir)
        log_message(f"Found {len(before_files)} files before download")
        
        # Execute the tidal-dl-ng command
        command = ["tidal-dl-ng", "dl", tidal_url]
        log_message(f"Executing command: {' '.join(command)}")
        
        result = subprocess.run(command, capture_output=True, text=True)
        
        # Log the command output
        with open(LOG_FILE, "a") as log_file:
            log_file.write("\n--- TIDAL-DL-NG OUTPUT START ---\n")
            log_file.write(result.stdout)
            if result.stderr:
                log_file.write("\n--- TIDAL-DL-NG STDERR ---\n")
                log_file.write(result.stderr)
            log_file.write("\n--- TIDAL-DL-NG OUTPUT END ---\n\n")
        
        # Get list of files after download
        log_message("Scanning files after download...")
        after_files = get_file_list(download_dir)
        log_message(f"Found {len(after_files)} files after download")
        
        # Count the actual files downloaded
        summary = count_file_types(before_files, after_files)
        
        # Log the summary in the exact format requested
        log_message(f"Download summary: {summary['total_new_files']} new files")
        
        # Use the exact format requested
        log_message(f"{summary.get('flac_files', 0)} .flac files (audio tracks)")
        log_message(f"{summary.get('lrc_files', 0)} .lrc files (lyrics files)")
        
        # Log additional details if any
        if summary.get('other_audio_files', 0) > 0:
            log_message(f"{summary.get('other_audio_files', 0)} other audio files")
        if summary.get('other_files', 0) > 0:
            log_message(f"{summary.get('other_files', 0)} other files")
        
        return result.returncode == 0, summary
    except Exception as e:
        log_message(f"Error during Tidal download: {str(e)}")
        return False, {'total_new_files': 0, 'flac_files': 0, 'lrc_files': 0}

def main():
    """Main function to execute the script."""
    # Check if URL is provided
    if len(sys.argv) < 2:
        log_message("Error: No Tidal URL provided")
        log_message("Usage: python tidal.py <tidal_url>")
        sys.exit(1)
    
    # Get the URL from command line arguments
    tidal_url = sys.argv[1]
    
    try:
        # Download from Tidal
        success, summary = download_tidal(tidal_url)
        
        # Prepare SMS message with the exact format
        sms_message = (
            f"Tidal download: {summary.get('flac_files', 0)} .flac files (audio tracks), "
            f"{summary.get('lrc_files', 0)} .lrc files (lyrics files)"
        )
        
        # Send SMS notification if available
        if SMS_AVAILABLE:
            log_message("Sending SMS notification")
            send_sms(
                message=sms_message,
                to=os.environ.get("TO_PHONE_NUMBER"),
                mgs=os.environ.get("MGS")
            )
            log_message("SMS notification sent")
        else:
            log_message("SMS notifications not available, skipping")
        
        # Log completion
        if success:
            log_message("Tidal download process completed successfully")
            
            # Run syncer if available and at least one file was downloaded
            if SYNCER_AVAILABLE and summary['total_new_files'] > 0:
                log_message(f"Files downloaded: {summary['total_new_files']}. Running Syncer...")
                
                # Call the run_sync function with resync mode (not initial sync)
                sync_result = syncer.run_sync(
                    is_initial_sync=False,
                    custom_message=f"Sync triggered by Tidal after downloading {summary['flac_files']} audio files and {summary['lrc_files']} lyrics files"
                )
                
                if sync_result:
                    log_message("Sync completed successfully")
                else:
                    log_message("Sync failed or destination directory not found")
            elif summary['total_new_files'] > 0:
                log_message("Files downloaded but syncer not available, skipping sync")
            else:
                log_message("No files downloaded, skipping sync operation")
        else:
            log_message(f"Tidal download process failed")
            sys.exit(1)
            
    except Exception as e:
        error_message = f"Error: {str(e)}"
        log_message(error_message)
        
        # Send SMS notification about the error if available
        if SMS_AVAILABLE:
            send_sms(
                message=f"Tidal download failed: {str(e)}",
                to=os.environ.get("TO_PHONE_NUMBER"),
                mgs=os.environ.get("MGS")
            )
            log_message("Error notification SMS sent")
        
        sys.exit(1)

if __name__ == "__main__":
    main()