$ApiKey = "AIzaSyCY4aq1WKcZlfHcx5J0suWn0sthiKJepEI"
$PromptFile = "k:\Google Drive\KNOWLEDGEBASE\Antigravity\Daily News Report.txt"
$EmailScript = "k:\Google Drive\KNOWLEDGEBASE\Antigravity\send_news_email.ps1"
$TempHtml = "$env:TEMP\daily_news_report.html"
$LogFile = "k:\Google Drive\KNOWLEDGEBASE\Antigravity\daily_news_log.txt"

$BccList = @(
    "linetskysemyon@yahoo.com",
    "annamir4u@gmail.com",
    "easyalinsincity@gmail.com",
    "joni.w46@yahoo.com",
    "gloriaoliver2429@gmail.com",
    "wilkrom@cox.net"
)

Start-Transcript -Path $LogFile -Append

Write-Host "Waiting 30 seconds for network and Google Drive to initialize..."
Start-Sleep -Seconds 30

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "   Antigravity Daily News Automator Started   " -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

# Ensure the prompt file exists
if (-not (Test-Path $PromptFile)) {
    Write-Host "Error: Could not find prompt file at $PromptFile" -ForegroundColor Red
    exit 1
}
Write-Host "[Trace] Reading prompt file..."

$SystemPrompt = [string](Get-Content -Path $PromptFile -Raw -Encoding UTF8)
Write-Host "[Trace] Building user prompt..."

$UserPrompt = 'Based on the system instructions, please perform a web search to gather today''s latest news, markets, tech, and Henderson NV weather. Output the final report EXCLUSIVELY as a beautifully styled, complete HTML document suitable for an email body. Use a clean, modern email template style. Do not wrap the output in markdown code blocks. Output ONLY the raw HTML.'
Write-Host "[Trace] Building JSON object..."

# Build the JSON payload for the Gemini API
$BodyObj = @{
    system_instruction = @{
        parts = @( @{ text = $SystemPrompt } )
    }
    contents = @(
        @{
            role = "user"
            parts = @( @{ text = $UserPrompt } )
        }
    )
    tools = @(
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
$ActiveModel = "gemini-2.5-pro" # Default fallback
try {
    $ModelsResponse = Invoke-RestMethod -Uri $ModelsUrl -Method Get
    $AvailableModels = $ModelsResponse.models.name | ForEach-Object { $_ -replace "^models/", "" }
    
    # Define preferred models in order of newest to oldest
    $PreferredModels = @(
        "gemini-4-pro",
        "gemini-3.5-pro",
        "gemini-3.1-pro",
        "gemini-3-pro",
        "gemini-2.5-pro",
        "gemini-1.5-pro-latest"
    )
    
    foreach ($Model in $PreferredModels) {
        if ($AvailableModels -contains $Model) {
            $ActiveModel = $Model
            break
        }
    }
    Write-Host "[Trace] Dynamically selected model: $ActiveModel"
} catch {
    Write-Host "[Trace] Failed to query models, using default: $ActiveModel" -ForegroundColor Yellow
}

$Url = "https://generativelanguage.googleapis.com/v1beta/models/${ActiveModel}:generateContent?key=$ApiKey"

Write-Host "Asking Gemini ($ActiveModel) to research and compile the news... (this takes about 15-30 seconds)" -ForegroundColor Yellow

try {
    $Response = Invoke-RestMethod -Uri $Url -Method Post -Headers $Headers -Body ([System.Text.Encoding]::UTF8.GetBytes($Body))
    $GeneratedText = $Response.candidates[0].content.parts[0].text
    
    # Strip markdown if Gemini accidentally included it
    $GeneratedText = $GeneratedText -replace "^```html\s*", ""
    $GeneratedText = $GeneratedText -replace "\s*```$", ""
    $GeneratedText = $GeneratedText.Trim()
    
    # Save the HTML to a temporary file
    Set-Content -Path $TempHtml -Value $GeneratedText -Encoding UTF8
    Write-Host "✅ Successfully generated HTML report via Gemini!" -ForegroundColor Green
    
    # Call the email script
    Write-Host "Calling email script to send to inbox..." -ForegroundColor Yellow
    & $EmailScript -HtmlFilePath $TempHtml -BccEmails $BccList
}
catch {
    Write-Host "❌ Error calling Gemini API:" -ForegroundColor Red
    if ($_.ErrorDetails) {
        Write-Host $_.ErrorDetails.Message -ForegroundColor Red
    } else {
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
    Stop-Transcript
    exit 1
}

Stop-Transcript
