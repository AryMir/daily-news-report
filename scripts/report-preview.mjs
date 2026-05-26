import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import {buildWeatherSection, loadWeatherData} from './henderson-weather.mjs';

const WEATHER_SECTION_HEADING = '6. Weather for Henderson, Nevada';
const LOCAL_OUTPUT_HTML = 'daily-news-report-email-preview-local.html';

function argValue(name, fallback = undefined) {
  const prefix = `${name}=`;
  const found = process.argv.find((arg) => arg.startsWith(prefix));
  return found ? found.slice(prefix.length) : fallback;
}

function htmlEscape(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function inlineMarkdownToHtml(value) {
  return htmlEscape(value)
    .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
    .replace(/°/g, '&deg;');
}

function weatherMarkdownToHtml(markdown) {
  const lines = markdown
    .split(/\r?\n/)
    .map((line) => line.replace(/^-\s*/, '').trim())
    .filter(Boolean);

  return lines
    .map((line, index) => {
      const margin = index === lines.length - 1 ? '0' : '0 0 11px 0';
      return `                  <p style="margin:${margin};">${inlineMarkdownToHtml(line)}</p>`;
    })
    .join('\n');
}

function localDateIso(value) {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'America/Los_Angeles',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(value);
  const byType = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${byType.year}-${byType.month}-${byType.day}`;
}

async function latestPreviewHtml(cwd) {
  const files = await fs.readdir(cwd);
  const previews = files
    .filter((file) => /^daily-news-report-email-preview-\d{4}-\d{2}-\d{2}\.html$/.test(file))
    .sort();

  if (!previews.length) {
    throw new Error('No daily-news-report-email-preview-YYYY-MM-DD.html file found.');
  }

  return path.join(cwd, previews.at(-1));
}

function replaceWeatherSection(html, weatherHtml) {
  const escapedHeading = WEATHER_SECTION_HEADING.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const pattern = new RegExp(
    `(<div style="font-size:20px; line-height:26px; font-weight:bold; color:#102a43; margin-bottom:12px;">${escapedHeading}</div>\\s*<div style="font-size:15px; line-height:23px;">)[\\s\\S]*?(\\s*</div>\\s*</td>\\s*</tr>)`,
  );

  if (!pattern.test(html)) {
    throw new Error(`Could not find the "${WEATHER_SECTION_HEADING}" HTML block to replace.`);
  }

  return html.replace(pattern, `$1\n${weatherHtml}\n$2`);
}

async function main() {
  const cwd = process.cwd();
  const sourceHtml = argValue('--source', process.env.REPORT_SOURCE_HTML)
    || await latestPreviewHtml(cwd);
  const fixturePath = argValue('--fixture', process.env.WEATHER_FIXTURE);
  const reportTime = new Date(argValue('--at', process.env.REPORT_GENERATED_AT || new Date().toISOString()));
  const datedOutputHtml = path.join(
    cwd,
    `daily-news-report-email-preview-${localDateIso(reportTime)}.html`,
  );
  const outputHtml = argValue('--output', process.env.REPORT_OUTPUT_HTML) || datedOutputHtml;
  const localOutputHtml = path.join(cwd, LOCAL_OUTPUT_HTML);

  const data = await loadWeatherData({fixturePath});
  const weatherMarkdown = buildWeatherSection(data, reportTime);
  const html = await fs.readFile(sourceHtml, 'utf8');
  const nextHtml = replaceWeatherSection(html, weatherMarkdownToHtml(weatherMarkdown));

  await fs.writeFile(outputHtml, nextHtml);
  if (path.resolve(outputHtml) !== path.resolve(localOutputHtml)) {
    await fs.writeFile(localOutputHtml, nextHtml);
  }
  console.log(`Generated preview: ${outputHtml}`);
  if (path.resolve(outputHtml) !== path.resolve(localOutputHtml)) {
    console.log(`Updated local preview: ${localOutputHtml}`);
  }
  console.log('');
  console.log(weatherMarkdown);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
