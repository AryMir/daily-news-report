param(
    [string]$SourceFile = "",
    [string]$Date = (Get-Date -Format "yyyy-MM-dd"),
    [switch]$SendEmail,
    [switch]$ForceEmail,
    [switch]$Preview,
    [switch]$SelfOnly
)

$ErrorActionPreference = "Stop"

# Semi-Automatic Daily News Publisher
# Use this when ChatGPT creates the report text and this script handles the site machinery.
$ProjectDir = $PSScriptRoot
Set-Location -Path $ProjectDir

$ExistingStaged = @(git diff --cached --name-only)
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect Git index.' }
if (-not $Preview -and $ExistingStaged.Count -gt 0) { throw 'Existing staged changes require review before publishing.' }


function Assert-CurrentReport {
    param([string]$Text, [string]$ReportDate)
    $Title = [regex]::Match($Text, '(?m)^# Daily News Report \| (.+?)\s*$')
    $ParsedDate = [datetime]::MinValue
    if (-not $Title.Success -or -not [datetime]::TryParse($Title.Groups[1].Value.Trim(), [Globalization.CultureInfo]::GetCultureInfo('en-US'), [Globalization.DateTimeStyles]::None, [ref]$ParsedDate) -or $ParsedDate.ToString('yyyy-MM-dd') -ne $ReportDate) {
        throw 'Report title date does not match the requested date.'
    }
    $FrontDate = [regex]::Match($Text, '(?m)^date:\s*["'']?(\d{4}-\d{2}-\d{2})')
    if ($FrontDate.Success -and $FrontDate.Groups[1].Value -ne $ReportDate) { throw 'Report front-matter date does not match.' }
    foreach ($Section in @('Executive Summary','U.S. National News','International News','Stock Market News','Technology Industry News','Artificial Intelligence News','Medicare & Medical News for Seniors','Sources Checked')) {
        if ($Text -notmatch ('(?m)^## ' + [regex]::Escape($Section) + '\s*$')) { throw "Missing required report section: $Section" }
    }
    if ($Text -notmatch '(?m)^## Weather for Henderson(?:, Nevada)?\s*$') { throw 'Henderson weather section is missing.' }
}

$EnvFilePath = Join-Path $ProjectDir ".env"
if (Test-Path $EnvFilePath) {
    Get-Content $EnvFilePath | Where-Object { $_ -match '=' } | ForEach-Object {
        $name, $value = $_ -split '=', 2
        Set-Item -Path "env:\$($name.Trim())" -Value $value.Trim().Trim('"').Trim("'")
    }
}

$RunMutex = New-Object System.Threading.Mutex($false, "Global\AntigravityDailyNewsRun")
if (-not $RunMutex.WaitOne(0)) {
    Write-Host "Another Daily News run is already in progress. Stopping this copy." -ForegroundColor Yellow
    exit 0
}

try {
    $env:GIT_TERMINAL_PROMPT = "0"
    $LogDir = Join-Path $ProjectDir 'logs'
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    Start-Transcript -Path (Join-Path $LogDir ("publisher-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')) -Append | Out-Null
    $ContentDir = Join-Path $ProjectDir "content"
    $ReportFile = Join-Path $ContentDir "$Date.md"
    $CalendarFile = Join-Path $ProjectDir "calendar_data.json"
    $WeatherFile = Join-Path $ProjectDir "weather_data.json"
    $BccFile = Join-Path $ProjectDir "bcc_list.txt"
    $EmailScript = Join-Path $ProjectDir "send_news_email.ps1"
    $PublicReportFile = Join-Path $ProjectDir "public\$Date.html"
    $StatusDir = Join-Path $ProjectDir "status"
    $EmailSentMarker = Join-Path $StatusDir "email-sent-$Date.ok"
    $DeleteSourceAfterSuccess = $false

    if (-not (Test-Path $StatusDir)) {
        New-Item -ItemType Directory -Path $StatusDir -Force | Out-Null
    }
    if (-not (Test-Path $ContentDir)) {
        New-Item -ItemType Directory -Path $ContentDir -Force | Out-Null
    }

    Write-Host ""
    Write-Host "==============================================="
    Write-Host " Semi-Automatic Daily News Publisher"
    Write-Host " Date: $Date"
    Write-Host "==============================================="
    Write-Host ""

    if ([string]::IsNullOrWhiteSpace($SourceFile)) {
        $DownloadsDir = Join-Path $env:USERPROFILE "Downloads"
        $DatedDownload = Join-Path $DownloadsDir "$Date.md"
        if (Test-Path $DatedDownload) {
            $SourceFile = $DatedDownload
            Write-Host "No source file was provided. Found today's Markdown report in Downloads."
        }
        else {
            throw 'Today''s dated Downloads report is missing. Refusing to substitute another date.'
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($SourceFile)) {
        if (-not (Test-Path -LiteralPath $SourceFile)) {
            Write-Host "ERROR: The source Markdown file was not found:" -ForegroundColor Red
            Write-Host "  $SourceFile"
            exit 1
        }
        $ResolvedSource = Resolve-Path -LiteralPath $SourceFile
        $DownloadsPath = (Resolve-Path -LiteralPath (Join-Path $env:USERPROFILE "Downloads")).Path
        $DeleteSourceAfterSuccess = $ResolvedSource.Path.StartsWith($DownloadsPath, [System.StringComparison]::OrdinalIgnoreCase)
        Write-Host "Using ChatGPT-created report file:"
        Write-Host "  $ResolvedSource"
        if (Test-Path $ReportFile) {
            Write-Host "Replacing today's existing content report with the Downloads version."
        }
        Assert-CurrentReport -Text (Get-Content -LiteralPath $ResolvedSource -Raw -Encoding UTF8) -ReportDate $Date
        if ($ResolvedSource.Path -ne [IO.Path]::GetFullPath($ReportFile)) { Copy-Item -LiteralPath $ResolvedSource -Destination $ReportFile -Force }
        Write-Host "Copied report to:"
        Write-Host "  $ReportFile"
        Write-Host ""
    }

    if (-not (Test-Path $ReportFile)) {
        Write-Host "ERROR: Today's report file was not found." -ForegroundColor Red
        Write-Host "Expected file:"
        Write-Host "  $ReportFile"
        Write-Host ""
        Write-Host "Either save today's ChatGPT Markdown in Downloads, place it in content, or run:"
        Write-Host "  .\semi_auto_publish_daily_news.ps1 -SourceFile C:\path\to\report.md"
        exit 1
    }

    $ReportText = Get-Content -Path $ReportFile -Raw -Encoding UTF8
    Assert-CurrentReport -Text $ReportText -ReportDate $Date
    if ($ReportText -match "(?is)(cannot create a reliable current Daily News Report|without live web access|future date|date is in the future|must stop as per the instructions|I must stop)") {
        Write-Host "ERROR: The report appears to contain refusal text, so it will not be published." -ForegroundColor Red
        exit 1
    }

    if ($ReportText -notmatch "^\s*---") {
        Write-Host "Adding standard front matter to the Markdown report..."
        $FrontMatter = @"
---
title: "Daily News Report - $Date"
date: $Date
type: "news"
source: "chatgpt-manual"
---

"@
        Set-Content -Path $ReportFile -Value ($FrontMatter + $ReportText.TrimStart()) -Encoding UTF8
    }

    Write-Host "Refreshing calendar data into this project..."
    node (Join-Path $ProjectDir 'refresh_calendar.cjs')
    if ($LASTEXITCODE -ne 0) { throw 'Calendar refresh failed.' }
    if (-not (Test-Path $CalendarFile)) {
        Write-Host "ERROR: calendar_data.json was not found after refresh." -ForegroundColor Red
        exit 1
    }

    Write-Host "Refreshing weather_data.json..." -ForegroundColor Cyan
    node .\fetch_weather.js
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Weather refresh failed. Nothing will be committed or pushed." -ForegroundColor Red
        exit $LASTEXITCODE
    }
    if (-not (Test-Path $WeatherFile)) {
        Write-Host "ERROR: weather_data.json was not found after refresh." -ForegroundColor Red
        exit 1
    }
    Write-Host "Weather refresh completed." -ForegroundColor Green

    Write-Host "Building website..." -ForegroundColor Cyan
    node .\build.js
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Website build failed. Nothing will be committed or pushed." -ForegroundColor Red
        exit $LASTEXITCODE
    }
    if (-not (Test-Path $PublicReportFile)) {
        Write-Host "ERROR: Expected public report was not created: $PublicReportFile" -ForegroundColor Red
        exit 1
    }
    Write-Host "Website build completed." -ForegroundColor Green

    $PublicHtml = Get-Content -Path $PublicReportFile -Raw -Encoding UTF8
    $MainMatch = [regex]::Match($PublicHtml, '<main class="main-content">\s*(?<body>[\s\S]*?)\s*</main>', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if (-not $MainMatch.Success) {
        Write-Host "ERROR: Could not extract report content for email." -ForegroundColor Red
        exit 1
    }
    $PreviewDir = Join-Path $ProjectDir ".preview"
    New-Item -ItemType Directory -Path $PreviewDir -Force | Out-Null
    $EmailHtmlFile = Join-Path $PreviewDir "email-$Date.html"
    $EmailDate = [datetime]::ParseExact($Date, "yyyy-MM-dd", [Globalization.CultureInfo]::InvariantCulture).ToString("MMMM d, yyyy", [Globalization.CultureInfo]::GetCultureInfo("en-US"))
    $EmailBody = "<h1>Daily News Report | $EmailDate</h1>" + $MainMatch.Groups["body"].Value
    $EmailHtml = @"
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: 'Segoe UI', Arial, sans-serif; color: #111827; line-height: 1.55; font-size: 16px; }
    h1, h2, h3 { color: #113f8c; }
    h1 { font-size: 28px; margin-top: 0; }
    h2 { font-size: 22px; border-bottom: 1px solid #e5e7eb; padding-bottom: 6px; margin-top: 24px; }
    ul, ol { padding-left: 24px; }
    li { margin-bottom: 8px; }
    a { color: #2563eb; }
    table { width: 100%; border-collapse: collapse; margin: 16px 0; }
    th, td { border-bottom: 1px solid #e5e7eb; padding: 8px; text-align: left; vertical-align: top; }
    th { background: #f3f4f6; color: #4b5563; }
  </style>
</head>
<body>
$EmailBody
</body>
</html>
"@
    Set-Content -Path $EmailHtmlFile -Value $EmailHtml -Encoding UTF8
    if ($Preview) {
        Write-Host "PREVIEW COMPLETE: pages and email built. No Git commit, push, deployment, email, or sent marker."
        Write-Host "Email preview: $EmailHtmlFile"
        return
    }

    Write-Host "Staging publish changes..."
    git add -- $ReportFile $CalendarFile $WeatherFile ".\public"
    $StagedChanges = git diff --cached --name-only
    if (-not [string]::IsNullOrWhiteSpace($StagedChanges)) {
        $CommitMessage = "Publish semi-automatic daily news report $Date"
        Write-Host "Committing changes..."
        git commit -m $CommitMessage
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: Git commit failed. Nothing will be pushed." -ForegroundColor Red
            exit $LASTEXITCODE
        }
    }
    else {
        Write-Host "No publish-related Git changes found. Continuing to deploy current public folder."
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
        exit 1
    }

    Write-Host "Deploying updated website to Cloudflare..." -ForegroundColor Cyan
    npx --yes wrangler@4.106.0 deploy
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Cloudflare deploy failed. Email will NOT be sent because the live website may not be updated." -ForegroundColor Red
        Write-Host "If this is an authentication error, run 'npx wrangler login' in an interactive terminal or add CLOUDFLARE_API_TOKEN to .env." -ForegroundColor Yellow
        exit $LASTEXITCODE
    }
    Write-Host "Cloudflare deploy succeeded." -ForegroundColor Green

    if ($SendEmail) {
        if ((Test-Path $EmailSentMarker) -and -not $ForceEmail) {
            Write-Host "Today's email was already sent. Skipping email to prevent a duplicate." -ForegroundColor Yellow
            Write-Host "Use -ForceEmail if you intentionally want to resend it." -ForegroundColor Yellow
        }
        else {
            $BccList = @()
            if (Test-Path $BccFile) {
                $BccLines = Get-Content $BccFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" -and -not $_.StartsWith("#") }
                if (-not $SelfOnly -and $BccLines.Count -gt 0 -and $BccLines[0].ToUpper() -eq "YES") {
                    $BccList = $BccLines | Select-Object -Skip 1
                    Write-Host "BCC list is ENABLED. BCC recipients loaded: $($BccList.Count)" -ForegroundColor Yellow
                }
            }
            Write-Host "Cloudflare deploy confirmed. Sending email now..." -ForegroundColor Cyan
            & $EmailScript -HtmlFilePath $EmailHtmlFile -BccEmails $BccList
            if ($LASTEXITCODE -ne 0) {
                Write-Host "ERROR: Email script failed after successful deploy." -ForegroundColor Red
                exit $LASTEXITCODE
            }
            New-Item -ItemType File -Path $EmailSentMarker -Force | Out-Null
        }
    }
    else {
        Write-Host "Email was not requested. Use -SendEmail when you want this script to send it." -ForegroundColor Yellow
    }

    if ($DeleteSourceAfterSuccess -and (Test-Path -LiteralPath $ResolvedSource.Path)) {
        Remove-Item -LiteralPath $ResolvedSource.Path -Force
        Write-Host "Deleted the processed Markdown file from Downloads:" -ForegroundColor Green
        Write-Host "  $($ResolvedSource.Path)"
    }

    Write-Host ""
    Write-Host "==============================================="
    Write-Host " Done."
    Write-Host " Semi-automatic report is published."
    Write-Host "==============================================="
    Write-Host ""
}
finally {
    Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
    if ($RunMutex) {
        $RunMutex.ReleaseMutex()
        $RunMutex.Dispose()
    }
}



