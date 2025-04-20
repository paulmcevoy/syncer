import os
from twilio.rest import Client


def send_sms(message="Hello!", to="+1234567890", mgs=""):

    account_sid = os.environ.get("TWILIO_ACCOUNT_SID")
    auth_token = os.environ.get("TWILIO_AUTH_TOKEN")

    client = Client(account_sid, auth_token)

    message = client.messages.create(
        body=message,
        messaging_service_sid=mgs,
        to=to,
    )

    print(message.body)
