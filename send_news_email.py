param(
    [string]$HtmlFilePath,
    [string]$RecipientEmail = "arymir@gmail.com",
    [string[]]$BccEmails = @()
)

$SenderEmail = $env:GMAIL_SENDER
$AppPassword = $env:GMAIL_APP_PASSWORD

if (-not $SenderEmail -or -not $AppPassword) {
    Write-Host "Error: GMAIL_SENDER and GMAIL_APP_PASSWORD must be set in the .env file." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $HtmlFilePath)) {
    Write-Host "Error: Could not find HTML file at $HtmlFilePath" -ForegroundColor Red
    exit 1
}

$HtmlContent = Get-Content -Path $HtmlFilePath -Raw -Encoding UTF8

$SMTPClient = New-Object System.Net.Mail.SmtpClient("smtp.gmail.com", 587)
$SMTPClient.EnableSsl = $true
$SMTPClient.Credentials = New-Object System.Net.NetworkCredential($SenderEmail, $AppPassword)

$MailMessage = New-Object System.Net.Mail.MailMessage
$MailMessage.From = $SenderEmail
$MailMessage.To.Add($RecipientEmail)

foreach ($bcc in $BccEmails) {
    if (-not [string]::IsNullOrWhiteSpace($bcc)) {
        $MailMessage.Bcc.Add($bcc)
    }
}

$MailMessage.Subject = "Daily News Report"
$MailMessage.SubjectEncoding = [System.Text.Encoding]::UTF8
$MailMessage.IsBodyHtml = $true
$MailMessage.Body = $HtmlContent
$MailMessage.BodyEncoding = [System.Text.Encoding]::UTF8

Write-Host "Connecting to Gmail SMTP server and sending email..." -ForegroundColor Cyan

try {
    $SMTPClient.Send($MailMessage)
    Write-Host "✅ Email sent successfully!" -ForegroundColor Green
}
catch {
    Write-Host "❌ Failed to send email. Error:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}