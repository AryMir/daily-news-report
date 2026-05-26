$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"k:\Google Drive\KNOWLEDGEBASE\Antigravity\master_news_automation.ps1`""
$Trigger = New-ScheduledTaskTrigger -Daily -At "7:00AM"
Register-ScheduledTask -TaskName "Antigravity Daily News" -Action $Action -Trigger $Trigger -Description "Generates and emails the Daily News Report via Gemini API" -Force
