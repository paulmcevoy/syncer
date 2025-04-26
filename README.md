# Syncer

A modular file synchronization system with optional Tidal music download integration and SMS notification capabilities. Designed to sync files only when necessary - when a drive is mounted or when new Tidal files are downloaded.

## Overview

This system provides a flexible way to synchronize files between directories, with optional components for downloading music from Tidal and sending SMS notifications. It's designed to be modular, allowing you to install only the components you need.

## Features

- **Core Synchronization**: Sync files between directories using rsync with filtered logs showing only audio files
- **Tidal Integration**: Download music from Tidal and automatically sync it
- **SMS Notifications**: Get notified only when changes occur during sync or when files are downloaded
- **Drive Monitoring**: Automatically detect and sync when drives are connected (one-time sync, no periodic resyncs)

## Requirements

- Python 3.6+
- pip3
- rsync
- Twilio account (for SMS notifications)
- Tidal account (for Tidal downloads)

## Installation

1. Clone this repository:
   ```
   git clone https://github.com/yourusername/syncer.git
   cd syncer
   ```

2. Run the installation script:
   ```
   ./install.sh
   ```

3. Follow the prompts to select which components to install and configure the system.

4. Activate the virtual environment when working with the system:
   ```
   source ./activate_venv.sh
   ```

5. To clean up all files generated during installation (for a fresh start):
   ```
   ./cleanup.sh
   ```

## Components

### Core Module (syncer.py)

The core synchronization module that handles file syncing using rsync.

Usage:
```
./syncer.py --initial  # Initial sync when drive is first mounted
./syncer.py --resync   # Resync after drive has been mounted for a while
```

### SMS Module (send_sms.py)

Handles SMS notifications about sync and download events.

Usage:
```
./send_sms.py "Test message"  # Send a test message
```

### Tidal Module (tidal.py)

Downloads music from Tidal and triggers syncs after successful downloads.

Usage:
```
./tidal.py <tidal_url>  # Download from Tidal URL
```

### Drive Monitor Options

You have two options for automatically triggering syncs when your drive is connected:

**1. Systemd Path Monitoring (Recommended):**

*   Uses systemd's built-in event detection (no polling).
*   Triggers sync immediately when the drive is mounted.
*   Requires no root permissions (uses user systemd units).
*   **Setup:** This is now done automatically during the `./install.sh` process. The install script creates and enables the necessary systemd units (`drive-mount-watcher.path` and `drive-sync.service`) after validating your `.env` file.

**2. Polling Script (Removed):**

*   Checks if the drive is mounted every 60 seconds (by default).
*   Less efficient and less responsive than path monitoring.
*   Can be run manually (`./drive_monitor.sh`) or via the old systemd service (which is now automatically installed if this component is selected during `install.sh`).
*   **Note:** It's recommended to use the systemd path monitoring approach instead. If you set up the path watcher, you don't need to run `drive_monitor.sh`.

## Virtual Environment

The system uses a Python virtual environment to isolate its dependencies from the system Python installation. The installation script creates this environment automatically in the `.venv` directory.

- To activate the virtual environment: `source ./activate_venv.sh` or `source .venv/bin/activate`
- To deactivate when finished: `deactivate`

All scripts are configured to use the Python interpreter from the virtual environment automatically.

If a virtual environment already exists, the installation script will use it instead of creating a new one.

## Configuration

The system is configured using environment variables in a `.env` file. The installation process creates a template `.env` file that you must edit before using the system.

### Required Configuration

You must set these values in your `.env` file:

```
SOURCE_DIR=/path/to/source                # Directory containing files to sync
DEST_DIR=/path/to/destination             # Directory to sync files to
MOUNT_POINT=/path/to/mount                # Mount point for external drive
```

### Optional Configuration

Depending on which components you installed, you may need to set additional variables:

- For SMS notifications:
  ```
  TO_PHONE_NUMBER=+1234567890              # Your phone number to receive SMS notifications
  MGS=your_twilio_message_service_id       # Twilio message service ID
  TWILIO_ACCOUNT_SID=your_twilio_account_sid  # Twilio account SID
  TWILIO_AUTH_TOKEN=your_twilio_auth_token    # Twilio auth token
  ```

- For Tidal downloads:
  ```
  TIDAL_QUALITY=LOSSLESS                   # Options: LOSSLESS, HIGH, LOW
  ```

A complete example configuration is provided in `.env.example`.

## Logs

All components log to a single log file specified in the `.env` file. Each log entry includes a timestamp and the component name.

## Systemd Integration

**Systemd Path Monitoring (Automatic Setup):**

The `./install.sh` script automatically creates user-level systemd units (`drive-mount-watcher.path` and `drive-sync.service`) during installation. These units will:

*   Monitor for the existence of the `MOUNT_POINT` specified in your `.env` file.
*   Automatically run `syncer.py --initial` when the drive is mounted.
*   Start automatically on user login.
*   Run without root privileges.
*   Log output via `journalctl --user -u drive-sync.service`.

**Legacy Method (Polling Service - Removed):**

The old polling script (`drive_monitor.sh`) and its associated systemd service have been removed in favor of the more efficient path monitoring method.

### Sync Behavior

The system is designed to sync files only in two specific situations:
1. When a drive is first mounted (detected by the drive monitor)
2. When the Tidal script successfully downloads new files

SMS notifications are only sent when:
- New files are downloaded from Tidal
- Changes are detected during a sync operation (files created or deleted)

This minimizes unnecessary sync operations and notifications.

### File Counting Explanation

The system now uses a more accurate approach to count downloaded files:

- **Tidal**: Scans the download directory before and after the download to count actual files created
  - Provides a detailed breakdown: "6 .flac files (audio tracks), 6 .lrc files (lyrics files)"
  - Counts files by examining their extensions, not by parsing command output
  - Uses SOURCE_DIR as the download directory if available
  - Falls back to TIDAL_DOWNLOAD_DIR if SOURCE_DIR is not set
  - Creates a local "downloads" directory as a last resort

- **Rsync**: Counts all files created during synchronization, including:
  - Audio files (FLAC, MP3, etc.)
  - Lyrics files (.lrc files)
  - Directories created

Both components now provide detailed breakdowns in the same format:
```
X .flac files (audio tracks)
Y .lrc files (lyrics files)
```

This makes it easier to understand exactly what files are being processed at each stage.

### Log Filtering

The rsync logs are filtered to show only relevant information:
- Audio files (FLAC, MP3, WAV, AAC, M4A, OGG) are included in the logs
- LRC (lyrics) files are excluded from the logs
- Summary information (file counts, sizes) is preserved

This makes the logs more focused on the important content being synchronized.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [Twilio](https://www.twilio.com/) for SMS API
- [tidal-dl-ng](https://github.com/yaronzz/Tidal-Media-Downloader) for Tidal downloading