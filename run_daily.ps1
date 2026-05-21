$ProjectDir = "C:\Antigravity\Daily_News_Project"
Set-Location -Path $ProjectDir

Write-Host "Running news fetch and email script..."
& .\master_news_automation_optimized.ps1

Write-Host "Running static site build..."
node .\fetch_weather.js
if ($LASTEXITCODE -ne 0) {
    Write-Error "fetch_weather.js failed."
    exit $LASTEXITCODE
}
node .\build.js

Write-Host "Committing and pushing to GitHub..."
git add .
$Date = Get-Date -Format "yyyy-MM-dd"
git commit -m "Auto-update daily news for $Date"
git push origin main

Write-Host "Daily run complete!"
