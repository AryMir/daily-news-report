const fs = require('fs');
const path = require('path');

const contentDir = path.join(__dirname, 'content');
const publicDir = path.join(__dirname, 'public');

if (!fs.existsSync(publicDir)) {
  fs.mkdirSync(publicDir);
}

function parseInline(text) {
    return text
        .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
        .replace(/\*(.*?)\*/g, '<em>$1</em>');
}

function parseMarkdown(md) {
    // Remove UTF-8 BOM if present
    if (md.charCodeAt(0) === 0xFEFF) {
        md = md.slice(1);
    }
    
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

    // Strip redundant title, date, and horizontal rule from the top of the body
    body = body.replace(/^\s*#\s+Optimized Daily News[\s\S]*?(?=##\s)/i, '');

    // Process tables
    body = body.replace(/((?:\|.+?\|\s*\n)+)/g, (match) => {
        let rows = match.trim().split('\n');
        let tableHtml = '<div class="table-container">\n<table>\n';
        let isHeader = true;
        for (let row of rows) {
            if (row.includes('---')) {
                isHeader = false;
                continue;
            }
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
            htmlLines.push('<hr>');
            continue;
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
            htmlLines.push(line);
            continue;
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
    if (inList) { htmlLines.push('</ul>'); }

    return { frontMatter, html: htmlLines.join('\n') };
}

const files = fs.readdirSync(contentDir).filter(f => f.endsWith('.md'));
const posts = [];

for (const file of files) {
    const md = fs.readFileSync(path.join(contentDir, file), 'utf-8');
    const { frontMatter, html } = parseMarkdown(md);
    
    // Fallback date if front matter is missing
    const dateStr = frontMatter.date || file.replace('.md', '');
    const title = frontMatter.title || `Daily News Report - ${dateStr}`;
    
    posts.push({
        filename: file.replace('.md', '.html'),
        date: dateStr,
        title: title,
        html: html
    });
}

// Sort by date descending
posts.sort((a, b) => b.date.localeCompare(a.date));

const generateHtml = (post, allPosts) => {
    const archiveLinks = allPosts.map(p => `<li><a href="${p.filename}">${p.title}</a></li>`).join('');
    
    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${post.title}</title>
    <style>
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
            font-size: 18px;
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
            display: flex;
            flex-direction: column;
            gap: 2rem;
        }
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
        .main-content ul {
            padding-left: 1.5rem;
            margin-bottom: 1.5rem;
        }
        .main-content li {
            margin-bottom: 0.75rem;
        }
        .main-content strong {
            color: #000000;
        }
        .table-container {
            overflow-x: auto;
            margin: 1.5rem 0;
        }
        table {
            width: 100%;
            border-collapse: collapse;
        }
        th, td {
            text-align: left;
            padding: 0.75rem 1rem;
            border-bottom: 1px solid #e5e7eb;
        }
        th {
            background-color: var(--bg-color);
            color: var(--text-muted);
            font-weight: 600;
            text-transform: uppercase;
            font-size: 0.875rem;
            letter-spacing: 0.05em;
        }
        hr {
            border: 0;
            border-top: 1px solid #e5e7eb;
            margin: 2rem 0;
        }
        .sidebar {
            background-color: var(--content-bg);
            padding: 1.5rem;
            border-radius: 0.5rem;
            box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1);
            align-self: start;
        }
        .sidebar h3 {
            margin-top: 0;
            color: var(--text-main);
            font-size: 28px;
            border-bottom: 1px solid #e5e7eb;
            padding-bottom: 0.5rem;
        }
        .sidebar ul {
            list-style: none;
            padding: 0;
            margin: 0;
        }
        .sidebar li {
            margin-bottom: 0.5rem;
        }
        .sidebar a {
            text-decoration: none;
            color: var(--accent);
            transition: color 0.2s;
        }
        .sidebar a:hover {
            color: var(--primary-blue);
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <header class="header-banner">
        <h1>Optimized Daily News</h1>
        <p>${post.date}</p>
    </header>
    
    <div class="container">
        <main class="main-content">
            ${post.html}
        </main>
        
        <aside class="sidebar">
            <h3>Recent Archives</h3>
            <ul>
                ${archiveLinks}
            </ul>
        </aside>
    </div>
</body>
</html>`;
};

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
