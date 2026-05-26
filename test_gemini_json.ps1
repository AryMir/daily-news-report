$ApiKey = "AIzaSyCY4aq1WKcZlfHcx5J0suWn0sthiKJepEI"
$Url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent?key=$ApiKey"
$BodyObj = @{
    contents = @(
        @{
            role = "user"
            parts = @( @{ text = "Give me a JSON object with 'html' and 'markdown' containing a short greeting." } )
        }
    )
    generationConfig = @{
        response_mime_type = "application/json"
    }
}
$Body = ConvertTo-Json -InputObject $BodyObj -Depth 10
$Headers = @{ "Content-Type" = "application/json" }
$Response = Invoke-RestMethod -Uri $Url -Method Post -Headers $Headers -Body ([System.Text.Encoding]::UTF8.GetBytes($Body))
$GeneratedText = $Response.candidates[0].content.parts[0].text
Write-Host "Generated text:"
Write-Host $GeneratedText
