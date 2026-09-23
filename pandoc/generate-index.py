#!/usr/bin/env python3
"""Generate a static index portal for the published slide decks in build/."""

import os
import re

docs = ["ploneconf-2026.md", "wrobocon-2026.md"]
cards = []

for d in docs:
    base = os.path.splitext(os.path.basename(d))[0]
    title = base
    subtitle = ""
    with open(d, "r", encoding="utf-8") as f:
        content = f.read()
        m_title = re.search(r'^title:\s*["\']?(.*?)["\']?\s*$', content, re.MULTILINE)
        if m_title:
            title = m_title.group(1)
        m_sub = re.search(r'^subtitle:\s*["\']?(.*?)["\']?\s*$', content, re.MULTILINE)
        if m_sub:
            subtitle = m_sub.group(1)

    sub_html = f'<div class="deck-subtitle">{subtitle}</div>' if subtitle else ""
    cards.append(f"""    <div class="deck-card">
      <div class="deck-info">
        <div class="deck-title">{title}</div>
        {sub_html}
      </div>
      <div class="links">
        <a class="btn btn-html" href="{base}.html">Reveal.js (HTML)</a>
        <a class="btn btn-pdf" href="{base}.pdf">Beamer (PDF)</a>
      </div>
    </div>""")

html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Presentations & Slide Decks</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Fira+Sans:ital,wght@0,300;0,400;0,500;0,600;1,400&display=swap">
  <style>
    :root {{
      --primary: #002957;
      --accent: #F1563F;
      --bg: #FAFAFA;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      font-family: 'Fira Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: var(--bg);
      color: #23373B;
      margin: 0;
      padding: 3.5rem 1.5rem;
      display: flex;
      justify-content: center;
    }}
    .container {{
      max-width: 820px;
      width: 100%;
    }}
    h1 {{
      color: var(--primary);
      font-size: 2.2rem;
      margin: 0 0 0.5rem 0;
      padding-bottom: 0.6rem;
      position: relative;
    }}
    h1::after {{
      content: "";
      display: block;
      width: 100%;
      height: 2.5px;
      background: var(--accent);
      position: absolute;
      bottom: 0;
      left: 0;
    }}
    p.subtitle {{
      color: #555555;
      font-size: 1.05rem;
      margin-top: 0.8rem;
      margin-bottom: 2.5rem;
    }}
    .deck-list {{
      display: flex;
      flex-direction: column;
      gap: 1.2rem;
    }}
    .deck-card {{
      background: #FFFFFF;
      border-radius: 8px;
      padding: 1.3rem 1.6rem;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
      border: 1px solid rgba(0, 0, 0, 0.04);
      display: flex;
      justify-content: space-between;
      align-items: center;
      flex-wrap: wrap;
      gap: 1.2rem;
      transition: transform 0.15s ease, box-shadow 0.15s ease;
    }}
    .deck-card:hover {{
      transform: translateY(-2px);
      box-shadow: 0 6px 16px rgba(0, 0, 0, 0.08);
    }}
    .deck-info {{
      flex: 1 1 300px;
    }}
    .deck-title {{
      font-size: 1.15rem;
      font-weight: 500;
      color: var(--primary);
    }}
    .deck-subtitle {{
      font-size: 0.9rem;
      color: #666666;
      margin-top: 0.25rem;
    }}
    .links {{
      display: flex;
      gap: 0.6rem;
    }}
    .btn {{
      display: inline-block;
      padding: 0.5rem 1rem;
      border-radius: 5px;
      font-size: 0.88rem;
      font-weight: 500;
      text-decoration: none;
      transition: background 0.15s ease, color 0.15s ease, transform 0.1s ease;
    }}
    .btn-html {{
      background: var(--primary);
      color: #FFFFFF;
    }}
    .btn-html:hover {{
      background: #001834;
    }}
    .btn-pdf {{
      background: #F0F0F0;
      color: #333333;
    }}
    .btn-pdf:hover {{
      background: var(--accent);
      color: #FFFFFF;
    }}
  </style>
</head>
<body>
  <div class="container">
    <h1>Presentations & Slide Decks</h1>
    <p class="subtitle">Markdown-first presentation authoring compiled with Beamer Metropolis (PDF) and Reveal.js (HTML).</p>
    <div class="deck-list">
{"\n".join(cards)}
    </div>
  </div>
</body>
</html>"""

os.makedirs("build", exist_ok=True)
with open("build/index.html", "w", encoding="utf-8") as f:
    f.write(html)
