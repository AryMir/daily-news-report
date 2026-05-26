const fs = require('fs');
const path = require('path');

const contentDir = path.join(__dirname, 'content');
const publicDir = path.join(__dirname, 'public');

if (!fs.existsSync(publicDir)) {
  fs.mkdirSync(publicDir);
}

// Global Nav HTML
const navHtml = `
    <nav class="nav-bar">
        <a href="index.html">Daily News</a>
        <a href="weather.html">Daily Forecast</a>
        <a href="schedule.html">Weekly Schedule</a>
    </nav>
`;

// Global CSS
const globalCss = `
    :root {
        --primary-blue: #113f8c;
        --bg-color: #f3f4f6;
        --content-bg: #ffffff;
        --text-main: #111827;
        --text-muted: #4b5563;
        --accent: #2563eb;
    }
    body {
        font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;
        margin: 0;
        padding: 0;
        background-color: var(--bg-color);
        color: var(--text-main);
        line-height: 1.6;
        font-size: 14pt;
    }
    .nav-bar {
        background-color: #0f2c60;
        display: flex;
        justify-content: center;
        gap: 2rem;
        padding: 1rem;
    }
    .nav-bar a {
        color: #ffffff;
        text-decoration: none;
        font-weight: 600;
        font-size: 16px;
        letter-spacing: 0.05em;
        text-transform: uppercase;
    }
    .nav-bar a:hover {
        color: #93c5fd;
    }
    .header-banner {
        background-color: var(--primary-blue);
        padding: 4rem 2rem;
        text-align: center;
        box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
    }
    .header-banner h1 {
        margin: 0;
        font-size: 2.5rem;
        letter-spacing: -0.025em;
        color: #ffffff;
    }
    .header-banner p {
        margin: 0.5rem 0 0;
        color: #ffffff;
        font-size: 1.1rem;
    }
    .container {
        max-width: 800px;
        margin: 0 auto;
        padding: 2rem 1rem;
    }
`;

function parseInline(text) {
    return text
        .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
        .replace(/\*(.*?)\*/g, '<em>$1</em>');
}

function parseMarkdown(md) {
    if (md.charCodeAt(0) === 0xFEFF) md = md.slice(1);
    
    let frontMatter = {};
    let body = md;
    if (md.startsWith('---')) {
        const end = md.indexOf('---', 3);
        if (end !== -1) {
            const fmText = md.substring(3, end).trim();
            body = md.substring(end + 3).trim();
            fmText.split('\n').forEach(line => {
                const [key, ...rest] = line.split(':');
                if (key && rest.length) {
                    frontMatter[key.trim()] = rest.join(':').trim().replace(/^"|"$/g, '');
                }
            });
        }
    }

    body = body.replace(/^[\s\S]*?(?=##\s)/i, '');
    body = body.replace(/((?:\|.+?\|\s*\n)+)/g, (match) => {
        let rows = match.trim().split('\n');
        let tableHtml = '<div class="table-container">\n<table>\n';
        let isHeader = true;
        for (let row of rows) {
            if (row.includes('---')) { isHeader = false; continue; }
            let cleanRow = row.replace(/^\||\|$/g, '').trim();
            let cells = cleanRow.split('|');
            tableHtml += '<tr>';
            for (let cell of cells) {
                let tag = isHeader ? 'th' : 'td';
                tableHtml += `<${tag}>${parseInline(cell.trim())}</${tag}>`;
            }
            tableHtml += '</tr>\n';
            isHeader = false;
        }
        tableHtml += '</table>\n</div>\n';
        return tableHtml;
    });

    let lines = body.split('\n');
    let htmlLines = [];
    let inList = false;

    for (let i = 0; i < lines.length; i++) {
        let line = lines[i].trimEnd();
        if (line === '---') {
            if (inList) { htmlLines.push('</ul>'); inList = false; }
            htmlLines.push('<hr>'); continue;
        }
        let headerMatch = line.match(/^(#{1,6})\s+(.*)/);
        if (headerMatch) {
            if (inList) { htmlLines.push('</ul>'); inList = false; }
            let level = headerMatch[1].length;
            htmlLines.push(`<h${level}>${parseInline(headerMatch[2])}</h${level}>`);
            continue;
        }
        if (line.match(/^[\*\-]\s+(.*)/)) {
            if (!inList) { htmlLines.push('<ul>'); inList = true; }
            let liContent = line.match(/^[\*\-]\s+(.*)/)[1];
            htmlLines.push(`<li>${parseInline(liContent)}</li>`);
            continue;
        } else if (inList && line.trim() === '') {
            htmlLines.push('</ul>'); inList = false;
        }
        if (line.startsWith('<div') || line.startsWith('<table') || line.startsWith('<tr') || line.startsWith('<th') || line.startsWith('<td') || line.startsWith('</table') || line.startsWith('</div')) {
            if (inList) { htmlLines.push('</ul>'); inList = false; }
            htmlLines.push(line); continue;
        }
        if (line.trim() !== '') {
            if (inList) { htmlLines.push('</ul>'); inList = false; }
            if (line.trim().startsWith('<')) {
                htmlLines.push(line);
            } else {
                htmlLines.push(`<p>${parseInline(line)}</p>`);
            }
        }
    }
    if (inList) htmlLines.push('</ul>');
    return { frontMatter, html: htmlLines.join('\n') };
}

const generateHtml = (post, allPosts) => {
    const archiveLinks = allPosts.map(p => `<li><a href="${p.filename}">${p.title}</a></li>`).join('');
    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${post.title}</title>
    <style>
        ${globalCss}
        .container-main { display: flex; flex-direction: column; gap: 2rem; max-width: 800px; margin: 0 auto; padding: 2rem 1rem;}
        .main-content {
            background-color: var(--content-bg);
            padding: 30px;
            border-radius: 0.5rem;
            box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1);
        }
        .main-content h1, .main-content h2, .main-content h3 {
            color: var(--primary-blue);
            border-bottom: 1px solid #e2e8f0;
            padding-bottom: 8px;
            margin-bottom: 20px;
            margin-top: 2rem;
        }
        .main-content h1 { font-size: 2.5rem; margin-top: 0; }
        .main-content h2 { font-size: 28px; }
        .main-content ul { padding-left: 1.5rem; margin-bottom: 1.5rem; }
        .main-content li { margin-bottom: 0.75rem; }
        .main-content strong { color: #000000; }
        .table-container { overflow-x: auto; margin: 1.5rem 0; }
        table { width: 100%; border-collapse: collapse; }
        th, td { text-align: left; padding: 0.75rem 1rem; border-bottom: 1px solid #e5e7eb; }
        th {
            background-color: var(--bg-color);
            color: var(--text-muted);
            font-weight: 600;
            text-transform: uppercase;
            font-size: 0.875rem;
            letter-spacing: 0.05em;
        }
        hr { border: 0; border-top: 1px solid #e5e7eb; margin: 2rem 0; }
        .sidebar {
            background-color: var(--content-bg);
            padding: 1.5rem;
            border-radius: 0.5rem;
            box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1);
            align-self: start;
        }
        .sidebar h3 {
            margin-top: 0; color: var(--text-main); font-size: 28px;
            border-bottom: 1px solid #e5e7eb; padding-bottom: 0.5rem;
        }
        .sidebar ul { list-style: none; padding: 0; margin: 0; }
        .sidebar li { margin-bottom: 0.5rem; }
        .sidebar a { text-decoration: none; color: var(--accent); transition: color 0.2s; }
        .sidebar a:hover { color: var(--primary-blue); text-decoration: underline; }
    </style>
</head>
<body>
    ${navHtml}
    <header class="header-banner">
        <h1>Optimized Daily News</h1>
        <p>${post.date}</p>
    </header>
    <div class="container-main">
        <main class="main-content">
            ${post.html}
        </main>
        <aside class="sidebar">
            <h3>Recent Archives</h3>
            <ul>${archiveLinks}</ul>
        </aside>
    </div>
</body>
</html>`;
};

const getIcon = (condition) => {
    const c = condition.toLowerCase();
    if (c.includes('sun') || c.includes('clear')) return '☀️';
    if (c.includes('rain') || c.includes('drizzle')) return '🌧️';
    if (c.includes('cloud') || c.includes('overcast')) return '☁️';
    if (c.includes('snow')) return '❄️';
    if (c.includes('thunder')) return '⛈️';
    return '⛅';
};

const generateWeatherHtml = (data) => {
    const today = data.today;
    const forecast = data.forecast;
    
    let forecastListHtml = forecast.map(d => `
        <div class="forecast-row">
            <div class="f-col f-day">${d.dayName}</div>
            <div class="f-col f-temp"><strong>${d.high}&deg; / ${d.low}&deg;</strong></div>
            <div class="f-col f-cond">${getIcon(d.condition)} ${d.condition}</div>
            <div class="f-col f-wind">${d.precipChance}% &#x1F4A7; <span class="wind-align">${d.windSpeed} mph ${d.windDir}</span></div>
        </div>
    `).join('');

    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Daily Forecast - ${today.location}</title>
    <style>
        ${globalCss}
        .weather-top { display: flex; gap: 20px; margin-bottom: 2rem; }
        .weather-card {
            background-color: var(--content-bg); border-radius: 0.5rem;
            padding: 1.5rem; flex: 1; box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1);
        }
        .weather-card h2 {
            margin-top: 0; color: var(--primary-blue); font-size: 1.5rem;
            border-bottom: 1px solid #e5e7eb; padding-bottom: 0.5rem; margin-bottom: 1rem;
        }
        .card-grid { display: grid; grid-template-columns: 1fr 1fr; grid-template-rows: auto auto; gap: 1.5rem; }
        .main-stat { display: flex; align-items: center; gap: 10px; }
        .temp-large { font-size: 3rem; font-weight: bold; line-height: 1; }
        .icon-large { font-size: 2.5rem; }
        .desc-text { font-size: 1rem; color: var(--text-main); }
        .quadrants {
            grid-column: 1 / -1; display: grid; grid-template-columns: 1fr 1fr 1fr 1fr;
            gap: 10px; background-color: #f9fafb; padding: 1rem; border-radius: 0.5rem;
        }
        .quadrant { display: flex; flex-direction: column; text-align: center; }
        .q-label { font-size: 0.85rem; color: var(--text-muted); text-transform: uppercase; font-weight: 600; }
        .q-val { font-size: 1.1rem; font-weight: bold; color: var(--text-main); }
        .forecast-list {
            background-color: var(--content-bg); border-radius: 0.5rem;
            padding: 1.5rem; box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1);
        }
        .forecast-row {
            display: flex; justify-content: space-between; align-items: center;
            padding: 1rem 0; border-bottom: 1px solid #e5e7eb;
        }
        .forecast-row:last-child { border-bottom: none; padding-bottom: 0; }
        .f-col { flex: 1; }
        .f-day { font-weight: 600; color: var(--text-muted); }
        .f-temp { text-align: center; font-size: 1.1rem; }
        .f-cond { text-align: center; }
        .f-wind { text-align: right; color: var(--text-muted); display: flex; justify-content: flex-end; gap: 15px;}
        .wind-align { min-width: 80px; text-align: right; }
    </style>
</head>
<body>
    ${navHtml}
    <header class="header-banner">
        <h1>Daily Forecast: ${today.location}</h1>
        <p>${today.date}</p>
    </header>
    <div class="container">
        <div class="weather-top">
            <div class="weather-card">
                <h2>Day</h2>
                <div class="card-grid">
                    <div class="main-stat">
                        <div class="temp-large">${today.day.temp}&deg;</div>
                        <div class="icon-large">${getIcon(today.day.condition)}</div>
                    </div>
                    <div class="desc-text">
                        Current Conditions: ${today.day.temp}&deg;F and ${today.day.condition}.<br>
                        High near ${today.high}&deg;F.<br>
                        Wind ${today.day.windSpeed} mph ${today.day.windDir}.
                    </div>
                    <div class="quadrants">
                        <div class="quadrant"><span class="q-label">Humidity</span><span class="q-val">${today.day.humidity}%</span></div>
                        <div class="quadrant"><span class="q-label">UV Index</span><span class="q-val">${today.uvIndex}</span></div>
                        <div class="quadrant"><span class="q-label">Sunrise</span><span class="q-val">${today.sunrise}</span></div>
                        <div class="quadrant"><span class="q-label">Sunset</span><span class="q-val">${today.sunset}</span></div>
                    </div>
                </div>
            </div>
            
            <div class="weather-card">
                <h2>Night</h2>
                <div class="card-grid">
                    <div class="main-stat">
                        <div class="temp-large">${today.night.temp}&deg;</div>
                        <div class="icon-large">🌙</div>
                    </div>
                    <div class="desc-text">
                        <strong>${today.night.condition}</strong><br>
                        Low near ${today.low}&deg;F.<br>
                        Wind ${today.night.windSpeed} mph ${today.night.windDir}.
                    </div>
                    <div class="quadrants">
                        <div class="quadrant"><span class="q-label">Humidity</span><span class="q-val">${today.night.humidity}%</span></div>
                        <div class="quadrant"><span class="q-label">UV Index</span><span class="q-val">0</span></div>
                        <div class="quadrant"><span class="q-label">Moonrise</span><span class="q-val">--</span></div>
                        <div class="quadrant"><span class="q-label">Moonset</span><span class="q-val">--</span></div>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="forecast-list">
            <h3 style="margin-top: 0; color: var(--primary-blue); border-bottom: 1px solid #e5e7eb; padding-bottom: 10px;">Next 6 Days</h3>
            ${forecastListHtml}
        </div>
    </div>
</body>
</html>`;
};

const generateScheduleHtml = (config) => {
    const masterPasscode = config.security_settings.master_passcode;
    
    let calendarData = {};
    const calendarDataPath = path.join(__dirname, 'calendar_data.json');
    if (fs.existsSync(calendarDataPath)) {
        calendarData = JSON.parse(fs.readFileSync(calendarDataPath, 'utf-8'));
    }

    let scheduleRows = '';
    
    const nowStr = new Date().toLocaleString("en-US", {timeZone: "America/Los_Angeles"});
    const todayMidnight = new Date(nowStr);
    todayMidnight.setHours(0, 0, 0, 0);

    const filteredEntries = Object.entries(calendarData).filter(([day, events]) => {
        const dateMatch = day.match(/,\s*(.*)$/);
        if (dateMatch) {
            let d = new Date(`${dateMatch[1]}, ${todayMidnight.getFullYear()}`);
            if (todayMidnight.getMonth() === 11 && d.getMonth() === 0) {
                d.setFullYear(todayMidnight.getFullYear() + 1);
            } else if (todayMidnight.getMonth() === 0 && d.getMonth() === 11) {
                d.setFullYear(todayMidnight.getFullYear() - 1);
            }
            return d >= todayMidnight;
        }
        return true;
    });

    if (filteredEntries.length > 0) {
        for (const [day, events] of filteredEntries) {
            let eventsHtml = '';
            if (events.length === 0) {
                eventsHtml = `<p style="color: var(--text-muted); font-style: italic;">No community or family events scheduled.</p>`;
            } else {
                for (let ev of events) {
                    let timeStr = ev.isAllDay ? "All Day" : `${new Date(ev.displayStart).toLocaleTimeString('en-US', {timeZone: config.timezone_settings.timezone, hour: 'numeric', minute:'2-digit'})} - ${new Date(ev.displayEnd).toLocaleTimeString('en-US', {timeZone: config.timezone_settings.timezone, hour: 'numeric', minute:'2-digit'})}`;
                    let locationStr = ev.location ? `<br><small style="color: var(--text-muted);">&#x1F4CD; ${ev.location}</small>` : '';
                    eventsHtml += `<div style="padding: 10px 0; border-bottom: 1px dashed #eee;">
                        <strong>${timeStr}</strong>: ${ev.summary} (${ev.owner})
                        ${locationStr}
                    </div>`;
                }
            }
            
            scheduleRows += `
                <div class="schedule-day">
                    <h3>${day}</h3>
                    ${eventsHtml}
                </div>
            `;
        }
    } else {
        let currentDate = new Date();
        let daysUntilNextSunday = (7 - currentDate.getDay()) % 7; 
        let totalDays = daysUntilNextSunday === 0 ? 14 : daysUntilNextSunday + 7;
        
        for (let i = 0; i <= totalDays; i++) {
            let d = new Date(currentDate);
            d.setDate(d.getDate() + i);
            let dateStr = d.toLocaleDateString('en-US', { weekday: 'long', month: 'short', day: 'numeric' });
            
            scheduleRows += `
                <div class="schedule-day">
                    <h3>${dateStr}</h3>
                    <p style="color: var(--text-muted); font-style: italic;">No community or family events scheduled.</p>
                </div>
            `;
        }
    }

    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Weekly Schedule</title>
    <style>
        ${globalCss}
        .locked-container {
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            min-height: 60vh;
        }
        .password-box {
            background: white;
            padding: 40px;
            border-radius: 8px;
            box-shadow: 0 4px 15px rgba(0,0,0,0.1);
            text-align: center;
            max-width: 400px;
            width: 100%;
        }
        .password-box h2 {
            margin-top: 0;
            color: var(--primary-blue);
        }
        .password-box input {
            padding: 12px;
            font-size: 18px;
            margin-top: 20px;
            width: 80%;
            border: 1px solid #ccc;
            border-radius: 4px;
            text-align: center;
        }
        .password-box button {
            padding: 12px 30px;
            font-size: 16px;
            margin-top: 20px;
            background-color: var(--primary-blue);
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            transition: background-color 0.2s;
        }
        .password-box button:hover {
            background-color: var(--accent);
        }
        #schedule-content {
            display: none;
        }
        .schedule-grid {
            display: flex;
            flex-direction: column;
            gap: 15px;
        }
        .schedule-day {
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }
        .schedule-day h3 {
            margin-top: 0;
            color: var(--primary-blue);
            border-bottom: 2px solid #f3f4f6;
            padding-bottom: 10px;
            margin-bottom: 15px;
        }
    </style>
</head>
<body>
    ${navHtml}
    
    <div id="locked-view" class="locked-container">
        <div class="password-box">
            <h2>Access Restricted</h2>
            <p>Please enter the master passcode to view the weekly schedule.</p>
            <input type="password" id="passcode-input" placeholder="Enter Passcode" onkeydown="if(event.key === 'Enter') checkPasscode()" />
            <br>
            <button onclick="checkPasscode()">Unlock</button>
            <p id="error-msg" style="color: red; display: none; margin-top: 15px; font-weight: bold;">Incorrect passcode.</p>
        </div>
    </div>
    
    <div id="schedule-content">
        <header class="header-banner">
            <h1>Weekly Schedule</h1>
            <p>Rolling view: Today through next Sunday</p>
        </header>
        <div class="container">
            <div class="schedule-grid">
               ${scheduleRows}
            </div>
        </div>
    </div>
    
    <script>
       const MASTER_PASSCODE = "${masterPasscode}";
       
       function unlock() {
           document.getElementById('locked-view').style.display = 'none';
           document.getElementById('schedule-content').style.display = 'block';
       }
       
       function checkPasscode() {
           const input = document.getElementById('passcode-input').value;
           if (input === MASTER_PASSCODE) {
               localStorage.setItem('schedule_auth_master', 'true');
               unlock();
           } else {
               document.getElementById('error-msg').style.display = 'block';
           }
       }
       
       if (localStorage.getItem('schedule_auth_master') === 'true') {
           unlock();
       }
    </script>
</body>
</html>`;
}

// 1. Compile Markdown Blog Posts
const files = fs.readdirSync(contentDir).filter(f => f.endsWith('.md'));
const posts = [];
for (const file of files) {
    const md = fs.readFileSync(path.join(contentDir, file), 'utf-8');
    const { frontMatter, html } = parseMarkdown(md);
    const dateStr = frontMatter.date || file.replace('.md', '');
    const title = frontMatter.title || `Daily News Report - ${dateStr}`;
    posts.push({ filename: file.replace('.md', '.html'), date: dateStr, title, html });
}
posts.sort((a, b) => b.date.localeCompare(a.date));

for (const post of posts) {
    const fullHtml = generateHtml(post, posts);
    fs.writeFileSync(path.join(publicDir, post.filename), fullHtml);
}

// Generate index.html (latest post)
if (posts.length > 0) {
    const latestPost = posts[0];
    const indexHtml = generateHtml(latestPost, posts);
    fs.writeFileSync(path.join(publicDir, 'index.html'), indexHtml);
    console.log('Successfully built static site in /public directory.');
} else {
    console.log('No posts found to build.');
}

// 2. Compile Weather Page
const weatherDataPath = path.join(__dirname, 'weather_data.json');
if (fs.existsSync(weatherDataPath)) {
    const weatherData = JSON.parse(fs.readFileSync(weatherDataPath, 'utf-8'));
    const weatherHtml = generateWeatherHtml(weatherData);
    fs.writeFileSync(path.join(publicDir, 'weather.html'), weatherHtml);
    console.log('Successfully built weather.html in /public directory.');
}

// 3. Compile Schedule Page
const configPath = path.join(__dirname, 'config.json');
if (fs.existsSync(configPath)) {
    const configData = JSON.parse(fs.readFileSync(configPath, 'utf-8'));
    const scheduleHtml = generateScheduleHtml(configData);
    fs.writeFileSync(path.join(publicDir, 'schedule.html'), scheduleHtml);
    console.log('Successfully built schedule.html in /public directory.');
}
