import os
import sys
import datetime
import requests
from dotenv import load_dotenv

# Try to import log_message from send_sms, define locally if it fails
try:
    from send_sms import log_message
except ImportError:
    # Get log file path from environment or use default
    LOG_FILE = os.getenv("LOG_FILE", "sync.log")

    def log_message(message):
        """Log a message with a timestamp to the log file."""
        timestamp = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        log_entry = f"{timestamp} - Telegram - {message}" # Changed prefix to Telegram
        print(log_entry)
        try:
            with open(LOG_FILE, "a") as log_file:
                log_file.write(log_entry + "\n")
        except Exception as e:
            print(f"Error writing to log file: {str(e)}")

# Load environment variables if not already loaded (e.g., if run directly)
if not os.getenv("BOT_TOKEN"):
    load_dotenv()

def send_telegram_message(message):
    """
    Send a message using the Telegram Bot API.

    Args:
        message (str): The message content to send.

    Returns:
        bool: True if the message was sent successfully, False otherwise.
    """
    bot_token = os.getenv("BOT_TOKEN")
    chat_id = os.getenv("CHAT_ID")

    if not bot_token or not chat_id:
        log_message("Error: Telegram BOT_TOKEN or CHAT_ID not found in environment variables.")
        return False

    url = f'https://api.telegram.org/bot{bot_token}/sendMessage'
    payload = {
        'chat_id': chat_id,
        'text': message,
        'parse_mode': 'Markdown' # Optional: Allows Markdown formatting
    }

    try:
        response = requests.post(url, data=payload, timeout=10) # Added timeout
        response.raise_for_status() # Raise an exception for bad status codes (4xx or 5xx)

        # Check response content for success indication (Telegram API specific)
        response_data = response.json()
        if response_data.get("ok"):
            log_message(f"Telegram message sent successfully to chat ID {chat_id}.")
            return True
        else:
            error_description = response_data.get("description", "Unknown error")
            log_message(f"Error sending Telegram message: {error_description}")
            return False

    except requests.exceptions.RequestException as e:
        log_message(f"Error sending Telegram message (RequestException): {str(e)}")
        return False
    except Exception as e:
        log_message(f"An unexpected error occurred sending Telegram message: {str(e)}")
        return False

if __name__ == "__main__":
    # If run directly, send a test message
    if len(sys.argv) > 1:
        test_message = " ".join(sys.argv[1:]) # Join args in case message has spaces
    else:
        test_message = "Test message from send_telegram.py"

    log_message("Sending test Telegram message...")
    result = send_telegram_message(test_message)
    if result:
        log_message("Test Telegram message sent successfully.")
    else:
        log_message("Failed to send test Telegram message.")
