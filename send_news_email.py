import smtplib
import os
import sys
import argparse
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

def send_html_email(html_file_path, recipient_email):
    # Retrieve credentials from environment variables
    # To use this with Gmail, you will need to generate an "App Password" in your Google Account security settings.
    # Set the environment variables before running:
    # set GMAIL_SENDER=your_email@gmail.com
    # set GMAIL_APP_PASSWORD=your_16_char_app_password
    
    sender_email = os.environ.get('GMAIL_SENDER')
    app_password = os.environ.get('GMAIL_APP_PASSWORD')

    if not sender_email or not app_password:
        print("Error: Please set GMAIL_SENDER and GMAIL_APP_PASSWORD environment variables.")
        print("Example (Windows):")
        print("  set GMAIL_SENDER=arymir@gmail.com")
        print("  set GMAIL_APP_PASSWORD=xxxx xxxx xxxx xxxx")
        sys.exit(1)

    # Read the HTML content
    try:
        with open(html_file_path, 'r', encoding='utf-8') as f:
            html_content = f.read()
    except FileNotFoundError:
        print(f"Error: Could not find HTML file at {html_file_path}")
        sys.exit(1)

    # Setup the MIME
    msg = MIMEMultipart('alternative')
    msg['From'] = sender_email
    msg['To'] = recipient_email
    msg['Subject'] = "Daily News Report"

    # Attach the HTML body to the email
    msg.attach(MIMEText(html_content, 'html'))

    print("Connecting to Gmail SMTP server...")
    try:
        # Create SMTP session for sending the mail
        server = smtplib.SMTP('smtp.gmail.com', 587)
        server.starttls() # Enable security
        
        print("Logging in...")
        server.login(sender_email, app_password)
        
        print(f"Sending email to {recipient_email}...")
        server.send_message(msg)
        
        server.quit()
        print("✅ Email sent successfully!")
        
    except Exception as e:
        print(f"❌ Failed to send email. Error: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Send an HTML email via Gmail SMTP.')
    parser.add_argument('html_file', help='Path to the HTML file you want to send')
    parser.add_argument('--to', default='arymir@gmail.com', help='Recipient email address')
    
    args = parser.parse_args()
    
    send_html_email(args.html_file, args.to)
