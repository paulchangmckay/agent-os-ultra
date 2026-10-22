#!/usr/bin/env python3
"""
Cast an I Ching hexagram (reusing cast.py's logic) and render the result as a
self-contained HTML reading report.

Output: ~/.iching/reading.html (fixed path, overwritten on every run — this is
what gets published/redeployed to the same Claude Artifact URL each time).

Stdlib only. Run directly: python3 render_reading.py
"""
import html
import os
import re
from pathlib import Path

import cast  # sibling module: throw_line, line_from_sum, hexagram_lookup, etc.

SKILL_DIR = Path(__file__).resolve().parent.parent
CHAPTERS_DIR = SKILL_DIR / "chapters"
OUTPUT_PATH = Path.home() / ".iching" / "reading.html"

POSITION_PHRASE = {
    1: "at the beginning",
    2: "in the second place",
    3: "in the third place",
    4: "in the fourth place",
    5: "in the fifth place",
    6: "at the top",
}


# --- Chapter markdown parsing -------------------------------------------

def parse_sections(md_text):
    """Split a chapter file into {heading: body_text} by '## ' headers."""
    sections = {}
    current_heading = None
    buf = []
    for line in md_text.splitlines():
        if line.startswith("## "):
            if current_heading is not None:
                sections[current_heading] = "\n".join(buf).strip()
            current_heading = line[3:].strip()
            buf = []
        else:
            buf.append(line)
    if current_heading is not None:
        sections[current_heading] = "\n".join(buf).strip()
    return sections


def extract_quote_and_meaning(section_body):
    """'> quote text' + '**Meaning**: text' -> (quote, meaning)."""
    quote = ""
    meaning = ""
    for line in section_body.splitlines():
        line = line.strip()
        if line.startswith(">"):
            quote = line.lstrip(">").strip()
        elif line.startswith("**Meaning**"):
            meaning = line.split(":", 1)[1].strip() if ":" in line else ""
    return quote, meaning

def find_line_bullet(lines_section_body, position, is_yang):
    """Find the '- **Nine/Six <position phrase>**: "..." — meaning' bullet."""
    name = ("Nine" if is_yang else "Six") + " " + POSITION_PHRASE[position]
    for line in lines_section_body.splitlines():
        line = line.strip()
        m = re.match(r"^-\s*\*\*(.+?)\*\*:\s*(.+)$", line)
        if m and m.group(1).strip().lower() == name.lower():
            return name, m.group(2).strip()
    return name, None


def load_hexagram(number):
    """Read a hexagram's chapter file and pull the fields the report needs."""
    title = cast.HEXAGRAM_TITLES[number]
    slug = cast.slugify(title)
    path = CHAPTERS_DIR / f"ch{number:02d}-{slug}.md"
    text = path.read_text(encoding="utf-8")
    sections = parse_sections(text)

    judgment_quote, judgment_meaning = extract_quote_and_meaning(
        sections.get("The Judgment", ""))
    image_quote, image_meaning = extract_quote_and_meaning(
        sections.get("The Image", ""))

    takeaways = [
        l.strip("- ").strip()
        for l in sections.get("Key Takeaways", "").splitlines()
        if l.strip().startswith("-")
    ]

    trigrams = []
    for l in sections.get("Trigrams", "").splitlines():
        l = l.strip()
        if l.startswith("- Upper:") or l.startswith("- Lower:"):
            trigrams.append(l.lstrip("- ").strip())

    return {
        "number": number,
        "title": title,
        "slug": slug,
        "chapter_file": f"chapters/ch{number:02d}-{slug}.md",
        "core_idea": sections.get("Core Idea", "").strip(),
        "trigrams": trigrams,
        "judgment_quote": judgment_quote,
        "judgment_meaning": judgment_meaning,
        "image_quote": image_quote,
        "image_meaning": image_meaning,
        "takeaways": takeaways,
        "lines_section": sections.get("The Lines", ""),
    }


# --- Casting (delegates to cast.py) -------------------------------------

def do_cast():
    lines = []
    for position in range(1, 7):
        coins, total = cast.throw_line()
        is_yang, is_moving = cast.line_from_sum(total)
        lines.append({
            "position": position, "coins": coins, "sum": total,
            "yang": is_yang, "moving": is_moving,
        })

    primary_bits = [1 if l["yang"] else 0 for l in lines]
    p_number, p_title, p_slug = cast.hexagram_lookup(primary_bits)

    moving = [l for l in lines if l["moving"]]
    resulting = None
    if moving:
        resulting_bits = list(primary_bits)
        for l in moving:
            resulting_bits[l["position"] - 1] = 1 - resulting_bits[l["position"] - 1]
        r_number, r_title, r_slug = cast.hexagram_lookup(resulting_bits)
        resulting = r_number

    return lines, p_number, resulting


# --- HTML rendering -------------------------------------------------------

def hexagram_bars_html(lines_for_hexagram):
    """Render 6 lines (top to bottom for display) as simple CSS bars."""
    rows = []
    for l in reversed(lines_for_hexagram):  # top line first, visually
        moving_cls = " moving" if l["moving"] else ""
        if l["yang"]:
            rows.append(
                f'<div class="hexline yang{moving_cls}"><span class="bar"></span></div>'
            )
        else:
            rows.append(
                f'<div class="hexline yin{moving_cls}">'
                f'<span class="bar"></span><span class="gap"></span><span class="bar"></span>'
                f"</div>"
            )
    return "\n".join(rows)


def cast_table_html(lines):
    rows = []
    for l in lines:
        coin_desc = " · ".join("H" if c == 3 else "T" for c in l["coins"])
        glyph = "yang" if l["yang"] else "yin"
        moving = ' <span class="tag">changing</span>' if l["moving"] else ""
        rows.append(
            f'<tr><td>{l["position"]}</td><td>{coin_desc}</td>'
            f'<td>{l["sum"]}</td><td>{glyph}{moving}</td></tr>'
        )
    return "\n".join(rows)


def hexagram_card_html(hx, lines_for_bars, emphasis, moving_lines=None):
    e = html.escape
    trigram_html = ""
    if hx["trigrams"]:
        trigram_html = (
            '<p class="trigrams">' + " · ".join(e(t) for t in hx["trigrams"]) + "</p>"
        )

    moving_html = ""
    if moving_lines:
        rows = []
        for pos, is_yang in moving_lines:
            name, text = find_line_bullet(hx["lines_section"], pos, is_yang)
            if text:
                rows.append(f"<li><strong>{e(name)}</strong>: {e(text)}</li>")
        if rows:
            moving_html = (
                '<div class="moving-lines"><h4>Lines in Motion</h4><ul>'
                + "".join(rows) + "</ul></div>"
            )

    takeaways_html = ""
    if hx["takeaways"]:
        items = "".join(f"<li>{e(t)}</li>" for t in hx["takeaways"])
        takeaways_html = f'<div class="takeaways"><h4>Key Takeaways</h4><ul>{items}</ul></div>'

    card_class = "hexcard primary" if emphasis else "hexcard resulting"
    return f"""
<div class="{card_class}">
  <div class="hexcard-head">
    <div class="hexgraphic">{hexagram_bars_html(lines_for_bars)}</div>
    <div class="hexmeta">
      <div class="hexnum">Hexagram {hx['number']}</div>
      <h3>{e(hx['title'])}</h3>
      {trigram_html}
    </div>
  </div>
  <p class="core-idea">{e(hx['core_idea'])}</p>
  <blockquote class="judgment"><span class="label">The Judgment</span>{e(hx['judgment_quote'])}</blockquote>
  <p class="meaning">{e(hx['judgment_meaning'])}</p>
  <blockquote class="image"><span class="label">The Image</span>{e(hx['image_quote'])}</blockquote>
  <p class="meaning">{e(hx['image_meaning'])}</p>
  {moving_html}
  {takeaways_html}
  <p class="chapter-ref">Full chapter: <code>{e(hx['chapter_file'])}</code></p>
</div>
"""


PAGE_TEMPLATE = """<title>I Ching Reading</title>
<style>
:root {{
  --bg: #fafaf8;
  --surface: #f5f2ed;
  --text: #2a2a28;
  --accent: #6b5b54;
  --secondary: #5a7a8a;
  --supporting: #a89980;
  --border: #e4ddd2;
}}
@media (prefers-color-scheme: dark) {{
  :root:not([data-theme="light"]) {{
    --bg: #201f1d;
    --surface: #2a2a28;
    --text: #f5f2ed;
    --accent: #6b5b54;
    --secondary: #5a7a8a;
    --supporting: #a89980;
    --border: #3a3733;
  }}
}}
:root[data-theme="dark"] {{
  --bg: #201f1d;
  --surface: #2a2a28;
  --text: #f5f2ed;
  --accent: #6b5b54;
  --secondary: #5a7a8a;
  --supporting: #a89980;
  --border: #3a3733;
}}

* {{ box-sizing: border-box; }}
body {{
  background: var(--bg);
  color: var(--text);
  font-family: 'Lora', Georgia, serif;
  font-size: 17px;
  line-height: 1.6;
  margin: 0;
  padding: 40px 20px 80px;
  display: flex;
  justify-content: center;
}}
main {{ width: 100%; max-width: 680px; }}
h1, h2, h3, h4 {{
  font-family: 'Poppins', -apple-system, sans-serif;
  font-weight: 700;
  text-wrap: balance;
  margin: 0 0 8px;
}}
header.page-head {{
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 32px;
  gap: 16px;
}}
.mark {{
  color: var(--accent);
  font-size: 28px;
  line-height: 1;
}}
header.page-head h1 {{ font-size: 26px; margin: 0; }}
.timestamp {{
  font-family: 'IBM Plex Mono', 'SF Mono', Consolas, monospace;
  font-size: 13px;
  color: var(--supporting);
  text-align: right;
}}

.cast-panel {{
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 4px;
  padding: 16px 20px;
  margin-bottom: 32px;
}}
.cast-panel h2 {{ font-size: 15px; text-transform: uppercase; letter-spacing: 0.06em; margin-bottom: 12px; }}
table.cast-table {{
  width: 100%;
  border-collapse: collapse;
  font-family: 'IBM Plex Mono', 'SF Mono', Consolas, monospace;
  font-size: 13px;
  font-variant-numeric: tabular-nums;
}}
table.cast-table td {{ padding: 4px 8px; border-bottom: 1px solid var(--border); }}
table.cast-table tr:last-child td {{ border-bottom: none; }}
.tag {{
  background: var(--secondary);
  color: var(--bg);
  font-size: 10px;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  padding: 1px 6px;
  border-radius: 3px;
  margin-left: 6px;
}}

.hexcard {{
  border: 1px solid var(--border);
  border-radius: 6px;
  padding: 24px;
  margin-bottom: 20px;
}}
.hexcard.primary {{ background: var(--surface); }}
.hexcard.resulting {{ background: transparent; }}
.hexcard-head {{
  display: flex;
  gap: 20px;
  align-items: flex-start;
  margin-bottom: 16px;
}}
.hexgraphic {{ display: flex; flex-direction: column; gap: 5px; width: 64px; flex-shrink: 0; padding-top: 4px; }}
.hexline {{ display: flex; gap: 6px; height: 7px; }}
.hexline .bar {{ background: var(--text); border-radius: 1.5px; flex: 1; }}
.hexline.yang .bar {{ flex: 1 1 100%; }}
.hexline .gap {{ width: 14%; }}
.hexline.moving .bar {{ background: var(--secondary); }}
.hexnum {{
  font-family: 'IBM Plex Mono', monospace;
  font-size: 12px;
  color: var(--supporting);
  text-transform: uppercase;
  letter-spacing: 0.05em;
}}
.hexmeta h3 {{ font-size: 22px; margin: 2px 0 4px; }}
.trigrams {{ font-size: 13px; color: var(--supporting); margin: 0; }}
.core-idea {{ font-style: italic; margin: 0 0 16px; }}
blockquote {{
  margin: 0 0 6px;
  padding-left: 16px;
  border-left: 3px solid var(--accent);
}}
blockquote .label {{
  display: block;
  font-family: 'Poppins', sans-serif;
  font-size: 11px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--accent);
  margin-bottom: 2px;
}}
.meaning {{ margin: 0 0 16px; }}
.moving-lines, .takeaways {{ margin-top: 16px; }}
.moving-lines h4, .takeaways h4 {{
  font-size: 13px;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--accent);
  margin-bottom: 8px;
}}
.moving-lines ul, .takeaways ul {{ margin: 0; padding-left: 20px; }}
.moving-lines li, .takeaways li {{ margin-bottom: 6px; }}
.chapter-ref {{ font-size: 13px; color: var(--supporting); margin: 16px 0 0; }}
.chapter-ref code {{ font-family: 'IBM Plex Mono', monospace; font-size: 12px; }}

.transition {{
  text-align: center;
  font-family: 'Poppins', sans-serif;
  font-weight: 700;
  font-size: 13px;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--secondary);
  margin: 8px 0 20px;
}}

footer {{
  margin-top: 40px;
  padding-top: 16px;
  border-top: 1px solid var(--border);
  font-size: 13px;
  color: var(--supporting);
}}
</style>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Poppins:wght@700;800&family=Lora:ital,wght@0,400;0,500;1,400&family=IBM+Plex+Mono:wght@400;500&display=swap" rel="stylesheet">

<main>
  <header class="page-head">
    <div>
      <span class="mark">◆</span>
      <h1>I Ching Reading</h1>
    </div>
    <div class="timestamp">{timestamp}</div>
  </header>

  <section class="cast-panel">
    <h2>Cast (three coins, bottom to top)</h2>
    <table class="cast-table">
      <tr><td><strong>Line</strong></td><td><strong>Coins</strong></td><td><strong>Sum</strong></td><td><strong>Value</strong></td></tr>
      {cast_rows}
    </table>
  </section>

  {primary_card}
  {transition}
  {resulting_card}

  <footer>
    Cast with the Wilhelm/Baynes coin method · <code>scripts/cast.py</code> ·
    Run <code>iching</code> again for a new reading.
  </footer>
</main>
"""


def main():
    lines, p_number, r_number = do_cast()
    primary = load_hexagram(p_number)

    moving_lines = [(l["position"], l["yang"]) for l in lines if l["moving"]]
    primary_card = hexagram_card_html(
        primary, lines, emphasis=True, moving_lines=moving_lines or None
    )

    transition_html = ""
    resulting_card_html = ""
    if r_number:
        resulting = load_hexagram(r_number)
        resulting_lines = list(lines)  # same 6 positions, values already flipped conceptually
        # Build the resulting hexagram's own line states (moving lines flipped, others unchanged)
        r_lines = []
        for l in lines:
            if l["moving"]:
                r_lines.append({**l, "yang": not l["yang"], "moving": False})
            else:
                r_lines.append(l)
        transition_html = '<div class="transition">&darr; becomes &darr;</div>'
        resulting_card_html = hexagram_card_html(
            resulting, r_lines, emphasis=False
        )

    from datetime import datetime
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M")

    page = PAGE_TEMPLATE.format(
        timestamp=timestamp,
        cast_rows=cast_table_html(lines),
        primary_card=primary_card,
        transition=transition_html,
        resulting_card=resulting_card_html,
    )

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(page, encoding="utf-8")

    print(f"Primary hexagram: {p_number} - {primary['title']}")
    if r_number:
        print(f"Resulting hexagram: {r_number} - {load_hexagram(r_number)['title']}")
    print(f"Reading written to: {OUTPUT_PATH}")


if __name__ == "__main__":
    os.chdir(Path(__file__).resolve().parent)
    main()
