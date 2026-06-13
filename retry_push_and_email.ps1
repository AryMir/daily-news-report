$ErrorActionPreference = "Stop"
$ProjectDir = "C:\Antigravity\Daily_News_Project"
Set-Location -Path $ProjectDir
# Prevent Git from hanging on username/password prompts.
$env:GIT_TERMINAL_PROMPT = "0"
$Date = Get-Date -Format "yyyy-MM-dd"
$TempHtml = "$env:TEMP\daily_news_report_optimized.html"
$EmailScript = "C:\Antigravity\Daily_News_Project\send_news_email.ps1"
$BccFile = "C:\Antigravity\Daily_News_Project\bcc_list.txt"
$StatusDir = "C:\Antigravity\Daily_News_Project\status"
$EmailSentMarker = Join-Path $StatusDir "email-sent-$Date.ok"
if (-not (Test-Path $StatusDir)) {
    New-Item -ItemType Directory -Path $StatusDir -Force | Out-Null
}
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Daily News Manual Recovery: Push to GitHub and Send Email" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
# Safety check 1: make sure report file exists.
if (-not (Test-Path $TempHtml)) {
    Write-Host "ERROR: Expected HTML report was not found:" -ForegroundColor Red
    Write-Host $TempHtml -ForegroundColor Red
    Write-Host ""
    Write-Host "This recovery script does NOT recreate the news report." -ForegroundColor Yellow
    Write-Host "Please run the full daily automation if the report was never created." -ForegroundColor Yellow
    Write-Host ""
    pause
    exit 1
}
# Safety check 2: prevent duplicate email.
if (Test-Path $EmailSentMarker) {
    Write-Host "Today's email was already sent." -ForegroundColor Yellow
    Write-Host "No duplicate email will be sent." -ForegroundColor Yellow
    Write-Host ""
    pause
    exit 0
}
Write-Host "Using existing report file:" -ForegroundColor Green
Write-Host $TempHtml
Write-Host ""
Write-Host "Checking Git changes..." -ForegroundColor Cyan
git status --short
Write-Host ""
Write-Host "Committing any existing changes..." -ForegroundColor Cyan
git add .
$Changes = git status --porcelain
if ($Changes) {
    git commit -m "Manual retry daily news update for $Date"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: git commit failed. Email will NOT be sent." -ForegroundColor Red
        pause
        exit $LASTEXITCODE
    }
}
else {
    Write-Host "No new Git changes detected. Repository may already be committed." -ForegroundColor Yellow
}
Write-Host ""
Write-Host "Pushing to GitHub with retry logic..." -ForegroundColor Cyan
$PushSucceeded = $false
$MaxAttempts = 5
for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    Write-Host "GitHub push attempt $attempt of $MaxAttempts..." -ForegroundColor Cyan
    git push origin main
    if ($LASTEXITCODE -eq 0) {
        $PushSucceeded = $true
        Write-Host "GitHub push succeeded." -ForegroundColor Green
        break
    }
    Write-Host "GitHub push failed on attempt $attempt." -ForegroundColor Yellow
    if ($attempt -lt $MaxAttempts) {
        $WaitSeconds = 30 * $attempt
        Write-Host "Waiting $WaitSeconds seconds before retry..." -ForegroundColor Yellow
        Start-Sleep -Seconds $WaitSeconds
    }
}
if (-not $PushSucceeded) {
    Write-Host ""
    Write-Host "ERROR: GitHub push failed after $MaxAttempts attempts." -ForegroundColor Red
    Write-Host "Email will NOT be sent." -ForegroundColor Red
    Write-Host "The report was NOT recreated. You may try this recovery script again later." -ForegroundColor Yellow
    Write-Host ""
    pause
    exit 1
}
# Load optional BCC list from bcc_list.txt.
# First line YES enables BCC. First line NO disables BCC.
$BccList = @()
if (Test-Path $BccFile) {
    $BccLines = Get-Content $BccFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" -and -not $_.StartsWith("#") }
    if ($BccLines.Count -gt 0) {
        $BccSwitch = $BccLines[0].ToUpper()
        if ($BccSwitch -eq "YES") {
            $BccList = $BccLines | Select-Object -Skip 1
            Write-Host "BCC list is ENABLED. BCC recipients loaded: $($BccList.Count)" -ForegroundColor Yellow
        }
        else {
            Write-Host "BCC list is DISABLED by bcc_list.txt. Sending only to main recipient." -ForegroundColor Yellow
        }
    }
}
else {
    Write-Host "No bcc_list.txt found. Sending only to main recipient." -ForegroundColor Yellow
}
Write-Host ""
Write-Host "GitHub push confirmed. Sending email now..." -ForegroundColor Cyan
& $EmailScript -HtmlFilePath $TempHtml -BccEmails $BccList
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Email script failed after successful GitHub push." -ForegroundColor Red
    pause
    exit $LASTEXITCODE
}
New-Item -ItemType File -Path $EmailSentMarker -Force | Out-Null
Write-Host ""
Write-Host "Manual recovery complete! Website pushed and email sent." -ForegroundColor Green
Write-Host "Duplicate email protection marker created:" -ForegroundColor Green
Write-Host $EmailSentMarker
Write-Host ""
pause
