param(
    [string]$HtmlFilePath,
    [string]$RecipientEmail = "arymir@gmail.com",
    [string[]]$BccEmails = @()
)

$SenderEmail = "arymir@gmail.com"
$AppPassword = "ggrggqdhokophtkz"

if (-not $SenderEmail -or -not $AppPassword -or $AppPassword -eq "your_16_character_app_password") {
    Write-Host "Error: Please set GMAIL_SENDER and GMAIL_APP_PASSWORD correctly." -ForegroundColor Red
    Write-Host "Make sure you replace 'your_16_character_app_password' with your actual password from Google!" -ForegroundColor Yellow
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

Write-Host "EMAIL SCRIPT VERSION: Ary Gmail SMTP v2 - $(Get-Date)" -ForegroundColor Cyan
Write-Host "Connecting to Gmail SMTP server and sending email..." -ForegroundColor Cyan

try {
    $SMTPClient.Send($MailMessage)
    Write-Host "✅ Email sent successfully!" -ForegroundColor Green
}
catch {
    Write-Host "❌ Failed to send email. Error:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}
