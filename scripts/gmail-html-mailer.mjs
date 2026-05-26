import fs from 'node:fs/promises';
import http from 'node:http';
import path from 'node:path';
import process from 'node:process';
import {google} from 'googleapis';

const SCOPES = ['https://www.googleapis.com/auth/gmail.compose'];
const TOKEN_PATH = 'token.json';

function argValue(name, fallback = undefined) {
  const prefix = `${name}=`;
  const found = process.argv.find((arg) => arg.startsWith(prefix));
  return found ? found.slice(prefix.length) : fallback;
}

function isoDate(value = new Date()) {
  const year = value.getFullYear();
  const month = String(value.getMonth() + 1).padStart(2, '0');
  const day = String(value.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function displayDate(value = new Date()) {
  return new Intl.DateTimeFormat('en-US', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  }).format(value);
}

function parseDateFromIso(value) {
  if (!value) return null;
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) return null;
  const [, year, month, day] = match;
  return new Date(Number(year), Number(month) - 1, Number(day));
}

function normalizeHeaderList(value) {
  return (value || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean)
    .join(', ');
}

function encodeSubject(value) {
  return /[^\x00-\x7F]/.test(value)
    ? `=?UTF-8?B?${Buffer.from(value, 'utf8').toString('base64')}?=`
    : value;
}

function base64Url(value) {
  return Buffer.from(value, 'utf8')
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

function stripHtml(html) {
  return html
    .replace(/<style[\s\S]*?<\/style>/gi, '')
    .replace(/<script[\s\S]*?<\/script>/gi, '')
    .replace(/<\/(p|div|h1|h2|h3|tr)>/gi, '\n')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&deg;/g, '°')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function buildMime({to, bcc, subject, html, text}) {
  const boundary = `daily-news-${Date.now()}`;
  const headers = [
    `To: ${to}`,
    bcc ? `Bcc: ${bcc}` : null,
    `Subject: ${encodeSubject(subject)}`,
    'MIME-Version: 1.0',
    `Content-Type: multipart/alternative; boundary="${boundary}"`,
  ].filter(Boolean);

  return [
    ...headers,
    '',
    `--${boundary}`,
    'Content-Type: text/plain; charset="UTF-8"',
    'Content-Transfer-Encoding: 8bit',
    '',
    text,
    '',
    `--${boundary}`,
    'Content-Type: text/html; charset="UTF-8"',
    'Content-Transfer-Encoding: 8bit',
    '',
    html,
    '',
    `--${boundary}--`,
    '',
  ].join('\r\n');
}

async function fileExists(filePath) {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    return false;
  }
}

function getClientConfig(credentials) {
  const config = credentials.installed || credentials.web;
  if (!config) {
    throw new Error('credentials.json must contain an "installed" or "web" OAuth client.');
  }
  return config;
}

async function authorize({credentialsPath, tokenPath}) {
  const credentials = JSON.parse(await fs.readFile(credentialsPath, 'utf8'));
  const config = getClientConfig(credentials);
  const client = new google.auth.OAuth2(
    config.client_id,
    config.client_secret,
    'http://127.0.0.1:3000/oauth2callback',
  );

  if (await fileExists(tokenPath)) {
    client.setCredentials(JSON.parse(await fs.readFile(tokenPath, 'utf8')));
    return client;
  }

  const server = http.createServer();
  const codePromise = new Promise((resolve, reject) => {
    server.on('request', (req, res) => {
      const reqUrl = new URL(req.url, 'http://127.0.0.1:3000');
      if (reqUrl.pathname !== '/oauth2callback') {
        res.writeHead(404);
        res.end('Not found');
        return;
      }

      const error = reqUrl.searchParams.get('error');
      if (error) {
        res.writeHead(400, {'Content-Type': 'text/plain'});
        res.end(`OAuth error: ${error}`);
        reject(new Error(`OAuth error: ${error}`));
        return;
      }

      const code = reqUrl.searchParams.get('code');
      res.writeHead(200, {'Content-Type': 'text/html; charset=utf-8'});
      res.end('<p>Authorization complete. You can close this tab and return to Codex.</p>');
      resolve(code);
    });
    server.on('error', reject);
  });

  await new Promise((resolve, reject) => {
    server.listen(3000, '127.0.0.1', resolve);
    server.on('error', reject);
  });

  const authUrl = client.generateAuthUrl({
    access_type: 'offline',
    prompt: 'consent',
    scope: SCOPES,
  });

  console.log('');
  console.log('Open this URL in your browser and approve Gmail send access:');
  console.log(authUrl);
  console.log('');
  console.log('Waiting for Google to redirect back to http://127.0.0.1:3000/oauth2callback ...');

  const code = await codePromise;
  server.close();

  if (!code) {
    throw new Error('Google did not return an authorization code.');
  }

  const {tokens} = await client.getToken(code);
  client.setCredentials(tokens);
  await fs.writeFile(tokenPath, JSON.stringify(tokens, null, 2));
  console.log(`Saved OAuth token to ${tokenPath}`);
  return client;
}

async function main() {
  const cwd = process.cwd();
  const mode = argValue('--mode', 'draft');
  const requestedDate = argValue('--date', process.env.REPORT_DATE || '');
  const date = parseDateFromIso(requestedDate) || new Date();
  const dateIso = isoDate(date);
  const credentialsPath = process.env.GMAIL_CREDENTIALS_PATH || path.join(cwd, 'credentials.json');
  const tokenPath = process.env.GMAIL_TOKEN_PATH || path.join(cwd, TOKEN_PATH);
  const defaultHtmlFile = `daily-news-report-email-preview-${dateIso}.html`;
  const htmlPath = process.env.REPORT_HTML_PATH || path.join(cwd, defaultHtmlFile);
  const to = normalizeHeaderList(process.env.GMAIL_TO || 'arymir@gmail.com');
  const bcc = normalizeHeaderList(process.env.GMAIL_BCC || '');
  const subject =
    process.env.GMAIL_SUBJECT || `Daily News Report: ${displayDate(date)}`;

  if (!['draft', 'send'].includes(mode)) {
    throw new Error('Use --mode=draft or --mode=send.');
  }

  const html = await fs.readFile(htmlPath, 'utf8');
  const text = process.env.REPORT_TEXT || stripHtml(html);
  const raw = base64Url(buildMime({to, bcc, subject, html, text}));

  const auth = await authorize({credentialsPath, tokenPath});
  const gmail = google.gmail({version: 'v1', auth});

  if (mode === 'draft') {
    const result = await gmail.users.drafts.create({
      userId: 'me',
      requestBody: {message: {raw}},
    });
    console.log(`Created Gmail HTML draft: ${result.data.id}`);
    return;
  }

  const result = await gmail.users.messages.send({
    userId: 'me',
    requestBody: {raw},
  });
  console.log(`Sent Gmail HTML message: ${result.data.id}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
