
import os
import sys
import datetime
from dotenv import load_dotenv

# Try to import Twilio, but don't fail if it's not installed
try:
    from twilio.rest import Client
    TWILIO_AVAILABLE = True
except ImportError:
    TWILIO_AVAILABLE = False

# Load environment variables if not already loaded
if not os.getenv("LOG_FILE"):
    load_dotenv()

# Get log file path from environment or use default
LOG_FILE = os.getenv("LOG_FILE", "sync.log")

def log_message(message):
    """Log a message with a timestamp to the log file."""
    timestamp = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    log_entry = f"{timestamp} - SMS - {message}"
    print(log_entry)
    try:
        with open(LOG_FILE, "a") as log_file:
            log_file.write(log_entry + "\n")
    except Exception as e:
        print(f"Error writing to log file: {str(e)}")

def send_sms(message, to, mgs):
    """
    Send an SMS message using Twilio.
    
    Args:
        message (str): The message to send
        to (str): The recipient's phone number
        mgs (str): The Twilio message service ID
        
    Returns:
        bool: True if the message was sent successfully, False otherwise
    """
    if not TWILIO_AVAILABLE:
        log_message("Error: Twilio library not installed. Cannot send SMS.")
        return False
        
    try:
        # Get Twilio credentials from environment variables
        account_sid = os.environ.get("TWILIO_ACCOUNT_SID")
        auth_token = os.environ.get("TWILIO_AUTH_TOKEN")
        
        if not account_sid or not auth_token:
            log_message("Error: Twilio credentials not found in environment variables.")
            return False
            
        if not to or not mgs:
            log_message("Error: Missing recipient phone number or message service ID.")
            return False
        
        # Initialize Twilio client
        client = Client(account_sid, auth_token)
        
        # Send the message
        message_obj = client.messages.create(
            body=message,
            messaging_service_sid=mgs,
            to=to
        )
        
        log_message(f"SMS sent to {to}: {message} (SID: {message_obj.sid})")
        return True
    except Exception as e:
        log_message(f"Error sending SMS: {str(e)}")
        return False

if __name__ == "__main__":
    # If run directly, send a test message
    if len(sys.argv) > 1:
        test_message = sys.argv[1]
    else:
        test_message = "Test message from send_sms.py"
    
    to_number = os.environ.get("TO_PHONE_NUMBER")
    message_service_id = os.environ.get("MGS")
    
    if to_number and message_service_id:
        log_message("Sending test SMS message...")
        result = send_sms(test_message, to_number, message_service_id)
        if result:
            log_message("Test SMS sent successfully.")
        else:
            log_message("Failed to send test SMS.")
    else:
        log_message("Error: TO_PHONE_NUMBER or MGS not set in environment variables.")