# Gmail API Setup for Daily News Report

This project sends the report as true HTML email through the Gmail API using OAuth. A normal Google Cloud API key is not enough for sending Gmail, because Gmail compose/send access must be authorized by the mailbox owner.

## One-Time Google Cloud Setup

1. Open Google Cloud Console and select the project you want to use.
2. Enable the Gmail API for that project.
3. Go to Google Auth Platform / OAuth consent screen.
4. Configure the consent screen. For a personal Gmail account, use External and add your own Gmail address as a test user. For Google Workspace, Internal may be available.
5. Create OAuth credentials:
   - Application type: Desktop app
   - Name: Daily News Report Sender
6. Download the OAuth client JSON.
7. Rename it to `credentials.json`.
8. Place it in this folder:
   `C:\Codex\Daily News Report\credentials.json`

## Install Dependencies

Run:

```powershell
npm install
```

## Create a True HTML Draft

Run:

```powershell
$env:GMAIL_TO = "arymir@gmail.com"
$env:GMAIL_BCC = ""
npm run gmail:draft
```

The first run opens a browser authorization flow. Sign in as the Gmail account that should send the report and approve the Gmail send scope.

## Send After the Draft Looks Right

Run:

```powershell
$env:GMAIL_TO = "arymir@gmail.com"
$env:GMAIL_BCC = "person1@example.com,person2@example.com"
npm run gmail:send
```

Keep `credentials.json`, generated tokens, and `.env` files private.
