# Codex Semi-Automated Daily News Workflow

This workflow fills the manual gap before `semi_auto_publish_daily_news.ps1`.

## Daily Codex Task

1. Read `Daily_News_Script_2026-07-03.txt` for the report requirements.
2. Use live web browsing/search to create today's Daily News Report.
3. Output only the finished Markdown report content.
4. Save the report to the current user's Downloads folder as:

   `YYYY-MM-DD.md`

5. Run the existing publisher from `C:\Antigravity\Daily_News_Project`:

   `.\semi_auto_publish_daily_news.ps1 -SendEmail`

## Guardrails

- Do not modify the publisher script as part of the scheduled run.
- Do not save directly into `content`; the publisher owns that step.
- Do not use `-ForceEmail` during the scheduled run.
- If live web access is unavailable, stop before creating the Markdown file.
- If the publisher fails, report the failure and do not retry with `-ForceEmail`.

## Manual Override

The manual workflow remains unchanged:

1. Create or download a Markdown report into Downloads.
2. Run `.\semi_auto_publish_daily_news.ps1 -SendEmail`.
3. Use `.\semi_auto_publish_daily_news.ps1 -SendEmail -ForceEmail` only when intentionally resending.
