$ErrorActionPreference = "Stop"
$ProjectDir = "C:\Antigravity\Daily_News_Project"
Set-Location -Path $ProjectDir
$RunMutex = New-Object System.Threading.Mutex($false, "Global\AntigravityDailyNewsRun")
if (-not $RunMutex.WaitOne(0)) {
    Write-Host "Another Daily News run is already in progress. Stopping this copy to prevent duplicate Gemini requests." -ForegroundColor Yellow
    exit 0
}
# Prevent scheduled task from hanging on GitHub username/password prompts.
$env:GIT_TERMINAL_PROMPT = "0"
$Date = Get-Date -Format "yyyy-MM-dd"
$TempHtml = "$env:TEMP\daily_news_report_optimized.html"
$EmailScript = "C:\Antigravity\Daily_News_Project\send_news_email.ps1"
$BccFile = "C:\Antigravity\Daily_News_Project\bcc_list.txt"
$StatusDir = "C:\Antigravity\Daily_News_Project\status"
if (-not (Test-Path $StatusDir)) {
    New-Item -ItemType Directory -Path $StatusDir -Force | Out-Null
}
$EmailSentMarker = Join-Path $StatusDir "email-sent-$Date.ok"
if (Test-Path $EmailSentMarker) {
    Write-Host "Today's email was already sent. Stopping to prevent duplicate email." -ForegroundColor Yellow
    exit 0
}
Write-Host "Running news fetch script..."
& .\master_news_automation_optimized.ps1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: News generation failed. Email will NOT be sent." -ForegroundColor Red
    exit $LASTEXITCODE
}
if (-not (Test-Path $TempHtml)) {
    Write-Host "ERROR: Expected HTML report was not created: $TempHtml" -ForegroundColor Red
    Write-Host "Email will NOT be sent." -ForegroundColor Red
    exit 1
}
Write-Host "Running static site build..."
node .\fetch_weather.js
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: fetch_weather.js failed. Email will NOT be sent." -ForegroundColor Red
    exit $LASTEXITCODE
}
node .\build.js
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: build.js failed. Email will NOT be sent." -ForegroundColor Red
    exit $LASTEXITCODE
}
Write-Host "Committing changes to GitHub repository..."
git add .
$Changes = git status --porcelain
if ($Changes) {
    git commit -m "Auto-update daily news for $Date"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: git commit failed. Email will NOT be sent." -ForegroundColor Red
        exit $LASTEXITCODE
    }
}
else {
    Write-Host "No Git changes detected. Website may already be up to date."
}
Write-Host "Pushing to GitHub with retry logic..."
$PushSucceeded = $false
$MaxAttempts = 5
for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    Write-Host "GitHub push attempt $attempt of $MaxAttempts..."
    git push origin main
    if ($LASTEXITCODE -eq 0) {
        $PushSucceeded = $true
        Write-Host "GitHub push succeeded." -ForegroundColor Green
        break
    }
    Write-Host "GitHub push failed on attempt $attempt." -ForegroundColor Yellow
    if ($attempt -lt $MaxAttempts) {
        $WaitSeconds = 30 * $attempt
        Write-Host "Waiting $WaitSeconds seconds before retry..."
        Start-Sleep -Seconds $WaitSeconds
    }
}
if (-not $PushSucceeded) {
    Write-Host "ERROR: GitHub push failed after $MaxAttempts attempts." -ForegroundColor Red
    Write-Host "Email will NOT be sent because the website may not be updated." -ForegroundColor Red
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
Write-Host "GitHub push confirmed. Sending email now..."
& $EmailScript -HtmlFilePath $TempHtml -BccEmails $BccList
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Email script failed after successful GitHub push." -ForegroundColor Red
    exit $LASTEXITCODE
}
New-Item -ItemType File -Path $EmailSentMarker -Force | Out-Null
$RunMutex.ReleaseMutex()
$RunMutex.Dispose()
Write-Host "Daily run complete! Website updated and email sent." -ForegroundColor Green


