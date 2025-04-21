# Syncer - USB Drive Sync Tool

This tool automatically syncs files from a source directory to a USB drive when it's mounted.

## Components

1. **udev rule**: Detects when the USB drive with UUID "3735-3139" is connected
2. **systemd service**: Runs the sync script when triggered by udev
3. **syncer.sh**: Shell script that sets up the environment and runs the Python script
4. **syncer.py**: Python script that performs the actual file synchronization

## Recent Fixes

The following issues have been fixed:

1. **Timing Issues**: Added retry logic to wait for the drive to be fully mounted
   - The Python script now tries multiple methods to detect the mount
   - Added a retry loop with configurable attempts and delay
   - Increased the timeout in the systemd service

2. **Permission Issues**: Fixed permission problems in the shell script
   - Added directory creation with proper permissions
   - Added explicit chmod commands to ensure proper access

3. **Environment Setup**: Improved environment handling
   - Updated systemd service to properly wait for the mount
   - Added more logging to help diagnose issues

## Testing

To test the changes without physically disconnecting and reconnecting the drive:

1. Make sure your drive is mounted at `/media/paul/SD512`
2. Run the test script:
   ```
   ./test_trigger.sh
   ```

This will simulate the udev trigger and show you the output and logs.

## Troubleshooting

If you still encounter issues:

1. Check the logs:
   - `/home/paul/syncer/output.log` - Main script output
   - `/tmp/udev-debug.log` - Debug output from the shell script
   - `/home/paul/syncer/logs/my-mount-script.log` - Python script logs
   - `/home/paul/sync.log` - Sync operation logs

2. Verify the drive is properly mounted:
   ```
   mountpoint /media/paul/SD512
   ```

3. Check the systemd service status:
   ```
   systemctl --user status syncer.service
   ```

4. Manually run the script to test:
   ```
   /home/paul/syncer/syncer.sh
   ```

## Modifying the udev Rule

If you need to modify the udev rule, you'll need to:

1. Edit the rule file (likely in `/etc/udev/rules.d/`)
2. Reload the udev rules:
   ```
   sudo udevadm control --reload-rules
   ```
3. Trigger a test event:
   ```
   sudo udevadm trigger
   ```

The current udev rule should look something like:
```
ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_UUID}=="3735-3139", \
  RUN+="/bin/su paul -c 'sleep 5; XDG_RUNTIME_DIR=/run/user/$(id -u paul) /usr/bin/systemctl --user start syncer.service'"
```

Consider increasing the sleep time from 2 to 5 seconds to give more time for the mount to complete.