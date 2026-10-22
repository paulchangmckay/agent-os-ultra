---
description: Cast an I Ching hexagram and publish it as an HTML reading
---

Cast a hexagram and show it as a formatted reading, in this order:

1. Run: `python3 ~/.claude/skills/i-ching-book-of-changes/scripts/render_reading.py`
   This casts fresh (three-coin method) and writes the reading to
   `~/.iching/reading.html`, overwriting the previous one. Read its stdout for
   the primary hexagram name/number and the resulting hexagram (if any lines
   moved).

2. Publish/update the artifact — always pass the existing URL so this
   redeploys the same page rather than creating a new one:
   - file_path: `~/.iching/reading.html`
   - url: `https://claude.ai/code/artifact/d1eda32d-edf7-44fa-a1ab-da71d08467e0`
   - favicon: ☯️
   - title: `I Ching Reading`
   - description: `A cast hexagram from the Wilhelm/Baynes I Ching, with the Judgment, Image, moving lines, and resulting hexagram.`

3. Reply with a short plain-text summary (hexagram name(s), whether any lines
   are moving) plus the artifact link — don't just say "done," give the actual
   reading in brief since not everyone will click through.

If the user asks a follow-up question about the reading (e.g. "what does the
moving line mean"), answer it from the matching chapter file under
`~/.claude/skills/i-ching-book-of-changes/chapters/` rather than re-casting.
