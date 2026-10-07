# Codex Laptop Handoff - Semi-Automated Daily News Workflow

Use this note when opening a new Codex thread on the laptop.

## Project Location

`C:\Antigravity\Daily_News_Project`

The related schedule project also needs to exist:

`C:\Antigravity\Next_Week_Schedule`

## Current Working Workflow

The reliable workflow is the Codex semi-automated path:

1. Codex runs daily at 6:45 AM Pacific.
2. Codex reads `Daily_News_Script_2026-07-03.txt`.
3. Codex uses live web search to generate the daily Markdown report.
4. Codex saves the report to:

   `C:\Users\AryMi\Downloads\YYYY-MM-DD.md`

5. The publisher script picks up the Downloads file:

   `.\semi_auto_publish_daily_news.ps1 -SendEmail`

6. The publisher copies the report into `content`, refreshes calendar/weather data, builds the site, commits, pushes, deploys to Cloudflare, sends email, and deletes the processed Downloads file.

## Important Scripts and Files

- `semi_auto_publish_daily_news.ps1` is the trusted publisher.
- `run_daily.ps1` is the older full automation path that depends on Gemini and is less reliable.
- `Daily_News_Script_2026-07-03.txt` contains the report-writing instructions.
- `codex_semi_auto_daily_news_workflow.md` documents the Codex automation bridge.
- `config.json` controls the weather location.
- `bcc_list.txt` controls whether BCC email recipients are enabled.

## Weather Location

The report instructions now tell Codex to read the weather location from:

`config.json`

Specifically:

`weather_settings.current_location`

For Park City, set:

`"current_location": "Park City"`

For Henderson, set:

`"current_location": "Henderson"`

## Codex Automation

The desktop automation id was:

`daily-news-report-publish`

It was active and configured to run daily at 6:45 AM Pacific.

On the laptop, verify the automation exists at:

`C:\Users\AryMi\.codex\automations\daily-news-report-publish\automation.toml`

The automation should tell Codex to save the report into Downloads and then run:

`.\semi_auto_publish_daily_news.ps1 -SendEmail`

## Validation History

- July 4, 2026: first full scheduled Codex semi-automation run worked as designed.
- July 5-7, 2026: scheduled runs continued successfully.
- July 7 took about 11-15 minutes, which was slower but normal for live research.

## First Laptop Verification

In a fresh Codex thread on the laptop, ask:

`Please verify the Daily News setup on this laptop using codex_laptop_handoff.md. Check the project path, automation file, config location, GitHub access, Cloudflare/Wrangler access, and whether the semi-auto publisher can run when a dated Markdown file is in Downloads. Do not send a forced email.`
