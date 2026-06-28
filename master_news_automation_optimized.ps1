$EnvFilePath = "C:\Antigravity\Daily_News_Project\.env"
if (Test-Path $EnvFilePath) {
    Get-Content $EnvFilePath | Where-Object { $_ -match '=' } | ForEach-Object {
        $name, $value = $_ -split '=', 2
        Set-Item -Path "env:\$($name.Trim())" -Value $value.Trim().Trim('"').Trim("'")
    }
}
$ApiKey = $env:GEMINI_API_KEY

if (-not $ApiKey) {
    Write-Host "Error: GEMINI_API_KEY is missing from .env file!" -ForegroundColor Red
    exit 1
}
$PromptFile = "C:\Antigravity\Daily_News_Project\Daily News Report Optimized.txt"
$EmailScript = "C:\Antigravity\Daily_News_Project\send_news_email.ps1"
$TempHtml = "$env:TEMP\daily_news_report_optimized.html"
$LogFile = "C:\Antigravity\Daily_News_Project\daily_news_optimized_log.txt"
$LastSuccessfulModelFile = "C:\Antigravity\Daily_News_Project\last_successful_gemini_model.txt"
$Culture = [System.Globalization.CultureInfo]::GetCultureInfo("en-US")
$CurrentDate = Get-Date -Format "yyyy-MM-dd"
$CurrentDateLong = (Get-Date).ToString("dddd, MMMM d, yyyy", $Culture)
$ExpectedReportTitle = "Daily News Report | $CurrentDateLong"

# Add BCC email addresses here tomorrow (e.g., @("friend1@example.com", "friend2@example.com"))
# Testing mode / temporary: no BCC recipients
# $BccList = @()

# Original BCC list, temporarily disabled:
# $BccList = @()

# Load optional BCC list from bcc_list.txt
# First line must be YES to enable BCC sending.
# First line NO means send only to the main recipient.

$BccFile = "C:\Antigravity\Daily_News_Project\bcc_list.txt"
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

Start-Transcript -Path $LogFile -Append

Write-Host "Waiting 10 seconds for network to initialize..."
Start-Sleep -Seconds 10

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "   Antigravity Daily News Automator (Wife's Version)   " -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

# Ensure the prompt file exists
if (-not (Test-Path $PromptFile)) {
    Write-Host "Error: Could not find prompt file at $PromptFile" -ForegroundColor Red
    exit 1
}
Write-Host "Refreshing calendar_data.json from Next_Week_Schedule..." -ForegroundColor Cyan
Push-Location "C:\Antigravity\Next_Week_Schedule"
node .\generate_report.js > "$env:TEMP\calendar_report_for_daily_news.html"
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to refresh calendar_data.json." -ForegroundColor Red
    Pop-Location
    Stop-Transcript
    exit 1
}
Pop-Location
Write-Host "calendar_data.json refreshed successfully." -ForegroundColor Green
Write-Host "[Trace] Reading Optimized prompt file..."

$SystemPrompt = [string](Get-Content -Path $PromptFile -Raw -Encoding UTF8)
$SystemPrompt = @"
Current date context:
Today is exactly $CurrentDateLong ($CurrentDate) in the America/Los_Angeles timezone.
The report title must be exactly: $ExpectedReportTitle
Do not use any sample, archived, memorized, or prior-year news. If live current sources do not confirm the facts for $CurrentDateLong or the latest available market session, stop instead of writing a report.

$SystemPrompt
"@
Write-Host "[Trace] Building user prompt..."

# We use the same formatting rules as the original, just referencing the optimized system instructions!
$UserPrompt = @"
Based on the system instructions, perform a web search to gather news, markets, and Henderson NV weather for exactly $CurrentDateLong ($CurrentDate).

The title block must contain this exact h1 text:
$ExpectedReportTitle

Use current verified sources only. Do not use 2024, 2025, sample, archived, or memorized stories unless a current source specifically requires historical context. Structure the information exactly as requested in the instructions. Return raw HTML only. Do not return Markdown. Do not return a second version. Do not include conversational text, explanations, or markdown code blocks. The first character of the response must be "<".
"@
Write-Host "[Trace] Building JSON object..."

# Build the JSON payload for the Gemini API
$BodyObj = @{
    system_instruction = @{
        parts = @( @{ text = $SystemPrompt } )
    }
    contents           = @(
        @{
            role  = "user"
            parts = @( @{ text = $UserPrompt } )
        }
    )
    tools              = @(
        @{ googleSearch = @{} }
    )
}
Write-Host "[Trace] Converting to JSON..."
$Body = ConvertTo-Json -InputObject $BodyObj -Depth 10
Write-Host "[Trace] Setting up API call..."

$Headers = @{
    "Content-Type" = "application/json"
}

Write-Host "[Trace] Checking for active Gemini models..."
$ModelsUrl = "https://generativelanguage.googleapis.com/v1beta/models?key=$ApiKey"
# Ask Gemini which models are currently available to this API key.
# Then filter out non-text models and rank the best text models first.
$CandidateModels = @()
try {
    $ModelsResponse = Invoke-RestMethod -Uri $ModelsUrl -Method Get -TimeoutSec 30
    $CandidateModels = $ModelsResponse.models |
        Where-Object {
            ($_.supportedGenerationMethods -contains "generateContent") -and
            ($_.name -match "^models/gemini-") -and
            ($_.name -notmatch "image|imagen|embedding|tts|veo|lyria|robotics|computer|banana|aqa")
        } |
        ForEach-Object {
            $ModelName = $_.name -replace "^models/", ""
            $Score = 0
            # Prefer current lighter Flash models for this daily report.
            if ($ModelName -match "flash") { $Score += 100 }
            if ($ModelName -match "lite") { $Score += 80 }
            if ($ModelName -match "latest") { $Score += 60 }
            if ($ModelName -match "^gemini-3") { $Score += 50 }
            if ($ModelName -match "^gemini-2\.5") { $Score += 40 }
            if ($ModelName -match "^gemini-2\.0") { $Score += 10 }
            # Avoid heavier or less stable choices unless needed.
            if ($ModelName -match "pro") { $Score -= 50 }
            if ($ModelName -match "preview") { $Score -= 75 }
            if ($ModelName -match "001$") { $Score -= 20 }
            [PSCustomObject]@{
                Name  = $ModelName
                Score = $Score
            }
        } |
        Sort-Object Score -Descending |
        Select-Object -ExpandProperty Name
    # Put known-good practical choices first when available.
    $PreferredFirst = @(
        "gemini-3.5-flash",
        "gemini-3.1-flash-lite",
        "gemini-flash-lite-latest",
        "gemini-2.5-flash-lite",
        "gemini-2.0-flash-lite",
        "gemini-flash-latest",
        "gemini-2.5-flash",
        "gemini-2.0-flash"
    )
    $CandidateModels = @(
        $PreferredFirst | Where-Object { $CandidateModels -contains $_ }
        $CandidateModels | Where-Object { $PreferredFirst -notcontains $_ }
    ) | Select-Object -Unique
    if (Test-Path $LastSuccessfulModelFile) {
        $LastSuccessfulModel = (Get-Content -Path $LastSuccessfulModelFile -Raw -Encoding UTF8).Trim()
        if ($LastSuccessfulModel -and ($CandidateModels -contains $LastSuccessfulModel)) {
            $CandidateModels = @(
                $LastSuccessfulModel
                $CandidateModels | Where-Object { $_ -ne $LastSuccessfulModel }
            ) | Select-Object -Unique
            Write-Host "[Trace] Trying last successful Gemini model first: $LastSuccessfulModel" -ForegroundColor Cyan
        }
    }
    Write-Host "[Trace] Candidate Gemini models to try:" -ForegroundColor Cyan
    $CandidateModels | ForEach-Object { Write-Host " - $_" -ForegroundColor Cyan }
}
catch {
    Write-Host "[Warning] Failed to query models. Using emergency fallback list." -ForegroundColor Yellow
    $CandidateModels = @(
        "gemini-2.5-flash-lite",
        "gemini-2.0-flash-lite",
        "gemini-flash-lite-latest",
        "gemini-2.5-flash",
        "gemini-2.0-flash"
    )
}
if (-not $CandidateModels -or $CandidateModels.Count -eq 0) {
    Write-Host "Error: No usable Gemini text models were found." -ForegroundColor Red
    Stop-Transcript
    exit 1
}
$GeneratedText = $null
$SuccessfulModel = $null
$LastGeminiError = $null
foreach ($ActiveModel in $CandidateModels) {
    $Url = "https://generativelanguage.googleapis.com/v1beta/models/${ActiveModel}:generateContent?key=$ApiKey"
    Write-Host "Asking Gemini ($ActiveModel) to research and compile the optimized news... (this takes about 15-30 seconds)" -ForegroundColor Yellow
    try {
        $Response = Invoke-RestMethod -Uri $Url -Method Post -Headers $Headers -Body ([System.Text.Encoding]::UTF8.GetBytes($Body)) -TimeoutSec 90
        $GeneratedText = $Response.candidates[0].content.parts[0].text
        if ($GeneratedText -and $GeneratedText.Trim().Length -gt 100) {
            $SuccessfulModel = $ActiveModel
            Set-Content -Path $LastSuccessfulModelFile -Value $SuccessfulModel -Encoding UTF8
            Write-Host "Successfully generated news using Gemini model: $SuccessfulModel" -ForegroundColor Green
            break
        }
        else {
            $LastGeminiError = "Model $ActiveModel returned an empty or too-short response."
            Write-Host "[Warning] $LastGeminiError" -ForegroundColor Yellow
        }
    }
    catch {
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
            $LastGeminiError = $_.ErrorDetails.Message
        }
        else {
            $LastGeminiError = $_.Exception.Message
        }
        Write-Host "[Warning] Gemini model failed: $ActiveModel" -ForegroundColor Yellow
        Write-Host $LastGeminiError -ForegroundColor Yellow
        # Small pause before trying the next model.
        Start-Sleep -Seconds 5
    }
}
if (-not $SuccessfulModel) {
    Write-Host "Error: All Gemini models failed. News report was not generated." -ForegroundColor Red
    Write-Host "Last Gemini error:" -ForegroundColor Red
    Write-Host $LastGeminiError -ForegroundColor Red
    Stop-Transcript
    exit 1
}
# Strip markdown if Gemini accidentally included it
$GeneratedText = $GeneratedText -replace "^```html\s*", ""
$GeneratedText = $GeneratedText -replace "\s*```$", ""
$GeneratedText = $GeneratedText.Trim()
# HTML-only output mode
$HtmlContent = $GeneratedText.Trim()
# Safety checks: stop if Gemini returned conversational text or non-HTML content.
if ($HtmlContent -match "^\s*(I understand|Sure|Certainly|Here is|Okay|I will)") {
    Write-Host "ERROR: Gemini returned conversational text instead of HTML." -ForegroundColor Red
    throw "Invalid Gemini response. Stopping automation."
}
if ($HtmlContent -notmatch "<h1|<h2|<html|<body|Daily News Report") {
    Write-Host "ERROR: Gemini response does not look like a Daily News HTML report." -ForegroundColor Red
    throw "Invalid HTML report. Stopping automation."
}
$TitleMatch = [regex]::Match($HtmlContent, "<h1[^>]*>\s*(?<title>.*?)\s*</h1>", [System.Text.RegularExpressions.RegexOptions]::Singleline)
if (-not $TitleMatch.Success) {
    Write-Host "ERROR: Gemini response does not include a report title." -ForegroundColor Red
    throw "Missing Daily News report title. Stopping automation."
}
$ActualReportTitle = ([regex]::Replace($TitleMatch.Groups["title"].Value, "<[^>]+>", "")).Trim()
if ($ActualReportTitle -ne $ExpectedReportTitle) {
    Write-Host "ERROR: Gemini produced a report with the wrong date/title." -ForegroundColor Red
    Write-Host "Expected: $ExpectedReportTitle" -ForegroundColor Red
    Write-Host "Actual:   $ActualReportTitle" -ForegroundColor Red
    throw "Wrong-date Daily News report. Stopping automation before saving, publishing, or emailing."
}
# Preserve the generated HTML for the website content file.
# The website generator can render raw HTML inside the .md file.
$MarkdownContent = $HtmlContent.Trim()
$ContentDir = "C:\Antigravity\Daily_News_Project\content"
if (-not (Test-Path $ContentDir)) {
    New-Item -ItemType Directory -Path $ContentDir | Out-Null
}
$MarkdownFile = Join-Path -Path $ContentDir -ChildPath "$CurrentDate.md"
# Build Front Matter
$FrontMatter = @"
---
title: "Daily News Report - $CurrentDate"
date: $CurrentDate
type: "news"
gemini_model: "$SuccessfulModel"
---
"@
$FinalMarkdown = $FrontMatter + $MarkdownContent
Set-Content -Path $MarkdownFile -Value $FinalMarkdown -Encoding UTF8
Write-Host "Successfully saved Markdown to $MarkdownFile" -ForegroundColor Green
# Save the HTML to a temporary file
Set-Content -Path $TempHtml -Value $HtmlContent -Encoding UTF8
Write-Host "Successfully generated HTML report via Gemini model: $SuccessfulModel" -ForegroundColor Green
# Call the email script
Write-Host "Email sending skipped here. run_daily.ps1 will send email only after GitHub push succeeds." -ForegroundColor Yellow

Stop-Transcript







