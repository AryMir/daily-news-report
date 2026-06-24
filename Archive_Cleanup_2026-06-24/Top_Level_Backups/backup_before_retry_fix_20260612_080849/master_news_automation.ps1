# ============================================================
# Antigravity Daily News Automator
# Generates Daily News Report and sends email
# Testing version: BCC disabled
# ============================================================

$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# Project paths
# ------------------------------------------------------------
$ProjectFolder = "C:\Antigravity\Daily_News_Project"
$EnvFile       = Join-Path $ProjectFolder ".env"
$EmailScript   = Join-Path $ProjectFolder "send_news_email.ps1"

$TempHtml      = Join-Path $env:TEMP "daily_news_report.html"
$TempMarkdown  = Join-Path $env:TEMP "daily_news_report.md"

$LogFolder     = Join-Path $ProjectFolder "logs"
$LogFile       = Join-Path $LogFolder "daily_news_log.txt"

# ------------------------------------------------------------
# Prompt file candidates
# The script will use the first one it finds.
# ------------------------------------------------------------
$PromptFileCandidates = @(
    (Join-Path $ProjectFolder "Daily News Report Optimized.txt"),
    (Join-Path $ProjectFolder "Daily News Optimized Prompt.txt"),
    (Join-Path $ProjectFolder "optimized_daily_news_prompt.txt"),
    (Join-Path $ProjectFolder "Daily News Report.txt")
)

$PromptFile = $null

foreach ($Candidate in $PromptFileCandidates) {
    if (Test-Path $Candidate) {
        $PromptFile = $Candidate
        break
    }
}

# ------------------------------------------------------------
# Testing mode: BCC disabled
# Add BCC emails back later after testing succeeds
# ------------------------------------------------------------
# $BccList = @()

# Original BCC list, temporarily disabled:
# $BccList = @(
#     "linetskysemyon@yahoo.com",
#     "annamir4u@gmail.com",
#     "easyalinsincity@gmail.com",
#     "joni.w46@yahoo.com",
#     "gloriaoliver2429@gmail.com",
#     "wilkrom@cox.net"
# )

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

# ------------------------------------------------------------
# Ensure log folder exists
# ------------------------------------------------------------
if (-not (Test-Path $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
}

$TranscriptStarted = $false

try {
    Start-Transcript -Path $LogFile -Append
    $TranscriptStarted = $true

    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "   Antigravity Daily News Automator Started   " -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "Run started: $(Get-Date)"
    Write-Host "Running as user: $env:USERNAME"
    Write-Host "Project folder: $ProjectFolder"
    Write-Host ""

    # ------------------------------------------------------------
    # Wait briefly for network
    # ------------------------------------------------------------
    Write-Host "Waiting 10 seconds for network to initialize..."
    Start-Sleep -Seconds 10

    # ------------------------------------------------------------
    # Load environment variables from .env
    # ------------------------------------------------------------
    Write-Host "[Trace] Loading .env file..."

    if (-not (Test-Path $EnvFile)) {
        Write-Host "ERROR: .env file not found at $EnvFile" -ForegroundColor Red
        exit 1
    }

    $EnvLines = Get-Content $EnvFile

    foreach ($Line in $EnvLines) {
        $CleanLine = $Line.Trim()

        if ([string]::IsNullOrWhiteSpace($CleanLine)) {
            continue
        }

        if ($CleanLine.StartsWith("#")) {
            continue
        }

        if ($CleanLine -match "^\s*([^=]+?)\s*=\s*(.*)\s*$") {
            $Name = $matches[1].Trim()
            $Value = $matches[2].Trim()

            # Remove surrounding quotes if present
            $Value = $Value.Trim('"').Trim("'")

            [Environment]::SetEnvironmentVariable($Name, $Value, "Process")
        }
    }

    # ------------------------------------------------------------
    # Load Gemini API key
    # ------------------------------------------------------------
    $ApiKey = $env:GEMINI_API_KEY

    if (-not $ApiKey) {
        Write-Host "ERROR: GEMINI_API_KEY is missing from .env file." -ForegroundColor Red
        exit 1
    }

    Write-Host "[Trace] Gemini API key loaded. Length: $($ApiKey.Length)"

    # ------------------------------------------------------------
    # Validate required files
    # ------------------------------------------------------------
    if (-not $PromptFile) {
        Write-Host "ERROR: Could not find a Daily News prompt file." -ForegroundColor Red
        Write-Host "Checked these locations:" -ForegroundColor Yellow

        foreach ($Candidate in $PromptFileCandidates) {
            Write-Host " - $Candidate" -ForegroundColor Yellow
        }

        exit 1
    }

    if (-not (Test-Path $EmailScript)) {
        Write-Host "ERROR: Could not find email script at $EmailScript" -ForegroundColor Red
        exit 1
    }

    Write-Host "[Trace] Using prompt file: $PromptFile"
    Write-Host "[Trace] Using email script: $EmailScript"

    # ------------------------------------------------------------
    # Read system prompt
    # ------------------------------------------------------------
    Write-Host "[Trace] Reading prompt file..."
    $SystemPrompt = [string](Get-Content -Path $PromptFile -Raw -Encoding UTF8)

    # ------------------------------------------------------------
    # Build user prompt
    # This matches the optimized report style more closely.
    # ------------------------------------------------------------
    Write-Host "[Trace] Building user prompt..."

    $UserPrompt = @"
Based on the system instructions, please perform a web search to gather today's news, markets, technology news, AI news, and Henderson NV weather.

Structure the information exactly as requested in the instructions.

Provide your output in two parts separated by the exact string:

|||MARKDOWN_SEPARATOR|||

Part 1 must be exclusively the beautifully styled, complete HTML document suitable for an email body. Use a clean, modern email template style.

Part 2 must be the exact same content formatted as clean Markdown for a static website.

Do not output any conversational text.

Do not wrap either part in markdown code blocks.

Output only the two requested parts separated by the separator.
"@

    # ------------------------------------------------------------
    # Build JSON body for Gemini API
    # ------------------------------------------------------------
    Write-Host "[Trace] Building JSON object..."

    $BodyObj = @{
        system_instruction = @{
            parts = @(
                @{
                    text = $SystemPrompt
                }
            )
        }
        contents = @(
            @{
                role = "user"
                parts = @(
                    @{
                        text = $UserPrompt
                    }
                )
            }
        )
        tools = @(
            @{
                googleSearch = @{}
            }
        )
    }

    Write-Host "[Trace] Converting JSON..."
    $Body = ConvertTo-Json -InputObject $BodyObj -Depth 20

    $Headers = @{
        "Content-Type" = "application/json"
    }

    # ------------------------------------------------------------
    # Select Gemini model
    # ------------------------------------------------------------
    $ActiveModel = "gemini-2.5-flash"
    $ModelsUrl = "https://generativelanguage.googleapis.com/v1beta/models?key=$ApiKey"

    Write-Host "[Trace] Checking for active Gemini models..."

    try {
        $ModelsResponse = Invoke-RestMethod -Uri $ModelsUrl -Method Get
        $AvailableModels = $ModelsResponse.models.name | ForEach-Object {
            $_ -replace "^models/", ""
        }

        $PreferredModels = @(
            "gemini-2.5-flash",
            "gemini-2.0-flash",
            "gemini-1.5-flash",
            "gemini-1.5-pro-latest"
        )

        foreach ($Model in $PreferredModels) {
            if ($AvailableModels -contains $Model) {
                $ActiveModel = $Model
                break
            }
        }

        Write-Host "[Trace] Dynamically selected model: $ActiveModel"
    }
    catch {
        Write-Host "[Warning] Failed to query models. Using default model: $ActiveModel" -ForegroundColor Yellow
        Write-Host "[Warning] $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # ------------------------------------------------------------
    # Call Gemini API
    # ------------------------------------------------------------
    $Url = "https://generativelanguage.googleapis.com/v1beta/models/${ActiveModel}:generateContent?key=$ApiKey"

    Write-Host "Asking Gemini ($ActiveModel) to research and compile the news..."
    Write-Host "This may take 15 to 60 seconds."

    try {
        $Response = Invoke-RestMethod `
            -Uri $Url `
            -Method Post `
            -Headers $Headers `
            -Body ([System.Text.Encoding]::UTF8.GetBytes($Body))

        if (-not $Response.candidates -or -not $Response.candidates[0].content.parts[0].text) {
            Write-Host "ERROR: Gemini returned an empty response." -ForegroundColor Red
            exit 1
        }

        $GeneratedText = $Response.candidates[0].content.parts[0].text

        # Remove accidental markdown fences
        $GeneratedText = $GeneratedText -replace "^```html\s*", ""
        $GeneratedText = $GeneratedText -replace "^```markdown\s*", ""
        $GeneratedText = $GeneratedText -replace "^```\s*", ""
        $GeneratedText = $GeneratedText -replace "\s*```$", ""
        $GeneratedText = $GeneratedText.Trim()

        # Split optimized output into HTML and Markdown
        $Separator = "|||MARKDOWN_SEPARATOR|||"
        $Parts = $GeneratedText -split [regex]::Escape($Separator), 2

        if ($Parts.Count -lt 2) {
            Write-Host "WARNING: Gemini did not return the expected separator." -ForegroundColor Yellow
            Write-Host "Using the entire response as HTML for this test." -ForegroundColor Yellow

            $HtmlContent = $GeneratedText
            $MarkdownContent = ""
        }
        else {
            $HtmlContent = $Parts[0].Trim()
            $MarkdownContent = $Parts[1].Trim()
        }

        # Save the HTML portion for email
        Set-Content -Path $TempHtml -Value $HtmlContent -Encoding UTF8

        # Save Markdown portion for inspection/testing
        if ($MarkdownContent) {
            Set-Content -Path $TempMarkdown -Value $MarkdownContent -Encoding UTF8
        }

        Write-Host "SUCCESS: Optimized-style HTML email report generated."
        Write-Host "Saved temporary HTML to: $TempHtml"

        if ($MarkdownContent) {
            Write-Host "Saved temporary Markdown to: $TempMarkdown"
        }
    }
    catch {
        Write-Host "ERROR: Gemini API call failed." -ForegroundColor Red

        if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
            Write-Host $_.ErrorDetails.Message -ForegroundColor Red
        }
        else {
            Write-Host $_.Exception.Message -ForegroundColor Red
        }

        exit 1
    }

    # ------------------------------------------------------------
    # Send email
    # ------------------------------------------------------------
    Write-Host "Calling email script to send the report..."
    Write-Host "Testing mode: BCC list is disabled."

    try {
        & $EmailScript -HtmlFilePath $TempHtml -BccEmails $BccList

        if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
            Write-Host "ERROR: Email script returned exit code $LASTEXITCODE" -ForegroundColor Red
            exit $LASTEXITCODE
        }

        Write-Host "SUCCESS: Email script completed."
    }
    catch {
        Write-Host "ERROR: Email script failed." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        exit 1
    }

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host "   Antigravity Daily News Automator Finished  " -ForegroundColor Green
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host "Run finished: $(Get-Date)"

    exit 0
}
finally {
    if ($TranscriptStarted) {
        Stop-Transcript
    }
}