# Daily News on the HP laptop

Project: `C:\Antigravity\Daily_News_Project`.

The recommended workflow is live research followed by the semi-automatic publisher. The older Gemini launcher is retained but has not been exercised end-to-end during restoration.

## Preview without publishing or email

Save a researched Markdown report as `YYYY-MM-DD.md`, then run:

```powershell
.\semi_auto_publish_daily_news.ps1 -SourceFile C:\path\to\YYYY-MM-DD.md -Preview -SelfOnly
```

Preview validates the report date and required sections, copies it into content, refreshes weather and calendar, builds the static site and email, and stops before Git staging, commits, pushes, Cloudflare deployment, email, source deletion, and sent-marker creation. Email previews are in `.preview`; run transcripts are in `logs`.

Required sections include Medicare & Medical News for Seniors and Weather for Henderson. Invalid source reports are rejected before replacing the content report. The current calendar project remains at `C:\Antigravity\Next_Week_Schedule`; `refresh_calendar.cjs` redirects its JSON output to this project's directory.

## Live run after Ary approves

```powershell
.\semi_auto_publish_daily_news.ps1 -SourceFile C:\path\to\YYYY-MM-DD.md -SendEmail -SelfOnly
```

This commits publish data, pushes GitHub, deploys the Worker, sends to `arymir@gmail.com`, and records success in `status\email-sent-YYYY-MM-DD.ok`. SelfOnly excludes all BCC recipients regardless of the list's setting. Without SelfOnly, optional distribution still follows bcc_list.txt: YES enables the supplied list; NO disables it. The mailer checks the control again. Keep NO throughout restoration. Never use ForceEmail to bypass a failure.

Gmail credentials come from the ignored `.env` file. Do not commit or share that file. The mailer throws on send failure, so a failed send cannot produce a success marker. SMTP acceptance still needs a real self-email delivery check.

## Site and schedule

One Worker, `daily-news-report`, serves `public`. Its default hostname is `daily-news-report.arymir.workers.dev`. Main pages are index.html, weather.html, and schedule.html, plus dated report archives. The schedule page uses the pre-existing browser-side passcode gate; it does not provide server-side access control.

The recovered Codex automation is `daily-news-report-publish-2`, daily at 06:45 Pacific. It remains PAUSED and its instructions permit report preparation only until Ary authorizes the production workflow. Do not enable it until the first approved deployment and self-email are verified. Keep this machine available for local scheduled work.

The complete original laptop folder, including its staged Git index, is preserved at `C:\Antigravity\Daily_News_Project_before_restoration_20261006-181347`. It should be kept until Ary is satisfied with the restored workflow. No restoration Git push, deployment, or email has been performed yet.
