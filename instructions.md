Create a clear, accurate daily news report using current, verified information.

Date: Today
Weather Location: Henderson, Nevada

Requirements:
- Use current information only, preferably from the past 24 hours.
- If no major update exists in a category, say so briefly.
- Prioritize credible sources such as AP, Reuters, BBC, Bloomberg, official government sources, and major financial outlets.
- Avoid speculation, opinion, rumors, and social-media-only claims.
- Keep each bullet to 1–2 short sentences.
- Include source names in parentheses when helpful.
- Use neutral, professional language.
- Keep the full report around 500–700 words.

Include these sections:

Daily News Report: [Today’s Date]

1. National Headlines
Top 5 major U.S. headlines.

2. International Headlines
Top 5 major global headlines.

3. Stock Market News
Summarize the current or most recent movement of the S&P 500, Dow Jones, and Nasdaq.
Mention the main reasons markets moved, if known.

4. Technology Industry News
Important product launches, company moves, cybersecurity issues, regulation, or industry trends.

5. Artificial Intelligence News
Major AI company updates, policy changes, product launches, research, lawsuits, or safety developments.

6. Weather for Henderson, Nevada
Include high/low temperature, conditions, precipitation chance, wind if important, and weather alerts if any.
Use `node scripts/henderson-weather.mjs` for the Henderson weather lines when possible.
The weather section must keep current temperature separate from the daily forecast high/low:
- Current Conditions: use the real current temperature (`data.current.temperature_2m` from Open-Meteo when available).
- Do not use `data.daily.temperature_2m_max[0]` as the current temperature.
- If no current temperature is provided, use the hourly temperature closest to report generation time in `America/Los_Angeles`.
- Today's Forecast: show the daily high and low from `data.daily.temperature_2m_max[0]` and `data.daily.temperature_2m_min[0]`.
- Use this wording: "Current Conditions: Approximately XX°F and [condition]" and "Today’s Forecast: High near XX°F, Low near XX°F".

Final check before answering:
- Confirm all sections are included.
- Make the report easy to scan.
- Do not use unnecessary symbols or decorative formatting.
