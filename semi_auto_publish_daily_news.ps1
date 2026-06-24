$ErrorActionPreference = "Stop"
# Semi-Automatic Daily News Publisher
# This script does NOT call Gemini.
# It publishes a manually-created Markdown report already saved in content\YYYY-MM-DD.md
$ProjectDir = "C:\Antigravity\Daily_News_Project"
Set-Location -Path $ProjectDir
$env:GIT_TERMINAL_PROMPT = "0"
$Date = Get-Date -Format "yyyy-MM-dd"
$ReportFile = ".\content\$Date.md"
$CalendarFile = ".\calendar_data.json"
$WeatherFile = ".\weather_data.json"
Write-Host ""
Write-Host "==============================================="
Write-Host " Semi-Automatic Daily News Publisher"
Write-Host " Date: $Date"
Write-Host "==============================================="
Write-Host ""
# Check today's Markdown report
if (-not (Test-Path $ReportFile)) {
    Write-Host "ERROR: Today's report file was not found." -ForegroundColor Red
    Write-Host ""
    Write-Host "Expected file:"
    Write-Host "  $ReportFile"
    Write-Host ""
    Write-Host "Please create or copy today's Markdown report into the content folder."
    Write-Host ""
    exit 1
}
Write-Host "Found today's report:"
Write-Host "  $ReportFile"
Write-Host ""
# Check calendar data
if (-not (Test-Path $CalendarFile)) {
    Write-Host "ERROR: calendar_data.json was not found." -ForegroundColor Red
    exit 1
}
Write-Host "Found calendar data:"
Write-Host "  $CalendarFile"
Write-Host ""
# Check weather data
if (-not (Test-Path $WeatherFile)) {
    Write-Host "ERROR: weather_data.json was not found." -ForegroundColor Red
    exit 1
}
Write-Host "Found weather data:"
Write-Host "  $WeatherFile"
Write-Host ""
# Refresh weather if possible
if (Test-Path ".\fetch_weather.js") {
    Write-Host "Refreshing weather_data.json..."
    node ".\fetch_weather.js"
    Write-Host "Weather refresh completed."
    Write-Host ""
} else {
    Write-Host "fetch_weather.js not found. Keeping existing weather_data.json."
    Write-Host ""
}
# Build website
if (-not (Test-Path ".\build.js")) {
    Write-Host "ERROR: build.js was not found." -ForegroundColor Red
    exit 1
}
Write-Host "Building website..."
node ".\build.js"
Write-Host "Website build completed."
Write-Host ""
# Show Git status
Write-Host "Git status after build:"
git status --short
Write-Host ""
# Check whether there are changes
$Changes = git status --porcelain
if ([string]::IsNullOrWhiteSpace($Changes)) {
    Write-Host "No changes found. Nothing to commit or push."
    Write-Host ""
    exit 0
}
# Commit and push
Write-Host "Staging changes..."
git add .
$CommitMessage = "Publish semi-automatic daily news report $Date"
Write-Host "Committing changes..."
git commit -m $CommitMessage
Write-Host "Pushing to GitHub..."
git push
Write-Host ""
Write-Host "==============================================="
Write-Host " Done."
Write-Host " GitHub has been updated."
Write-Host " Cloudflare should update the website automatically."
Write-Host "==============================================="
Write-Host ""
