---
name: i-ching-book-of-changes
description: "Knowledge base from \"The I Ching or Book of Changes\" (Richard Wilhelm translation, rendered into English by Cary F. Baynes; Princeton University Press, Bollingen Series XIX). Use when casting or interpreting a hexagram, applying the Wilhelm/Baynes framework of yin-yang, trigrams, correspondence, and moving lines, studying the book, or consulting the oracle interactively."
---

<!-- argument-hint: [hexagram number, trigram name, or "cast"] -->

# The I Ching or Book of Changes
**Translation**: Richard Wilhelm, rendered into English by Cary F. Baynes | **Foreword**: C. G. Jung
**Pages**: ~1,336 | **Chapters**: 67 (64 hexagrams + 3 methodology chapters) | **Generated**: 2026-09-15

## How to Use This Skill

- **To consult the oracle** — run `python3 scripts/cast.py`. It casts a hexagram using the three-coin method, prints each line as it's thrown, and tells you exactly which chapter file(s) to read (the primary hexagram, and — if any lines are moving — the resulting hexagram too).
- **Without arguments** — load Core Frameworks below for the interpretive method.
- **With a hexagram number or name** — ask about hexagram 29, or "The Abysmal," or "water" — I read the matching chapter.
- **With a topic** — ask about `correspondence`, `moving lines`, `trigrams`, or another indexed topic below; I find and read the relevant chapter.
- **Browse** — ask "what hexagrams do you have?" to see the full index.

When you ask about a topic not covered in Core Frameworks below, I will read the
relevant chapter file before answering.

---

## Core Frameworks & Mental Models

**The oracle's premise (Jung's synchronicity)**: the hexagram cast in a given moment is treated as sharing the essential quality of that moment — not causally, but through meaningful coincidence. Use this to frame *why* a cast hexagram is worth reading closely: the "chance" of the coins is understood to be operating inside the same structure as the situation being asked about, not separate from it.

**Tao as the alternation of yin and yang**: stability comes from the *regularity of the handoff* between the two forces, not either one dominating. Use this as the master lens whenever a hexagram or line seems to contradict itself across time.

**Moving lines carry the message**: a line cast as old yin (6) or old yang (9) is "moving" — it is the site of actual change and must be read individually, on top of the hexagram's overall Judgment and Image. Static lines (7, 8) are the stable backdrop. Reading priority: no moving lines → read only the primary hexagram's Judgment + Image. One or more moving lines → also read each moving line's text, and also read the resulting hexagram's Judgment + Image.

**The Judgment and The Image**: every hexagram carries a Judgment (the situation as a whole, attributed to King Wên) and an Image (what the "superior man" should do in response, drawn from the two trigrams' natural scene). Read both before touching line-level detail.

**Trigram identity, three layers deep**: every hexagram splits into a lower trigram (lines 1-3) and upper trigram (lines 4-6) — read their attributes, images, and family roles first (`ch65`). For a deeper reading, the four *middle* lines (2-5) hide a second pair of "nuclear" trigrams (`ch67`) — lines 3 and 4 belong to three trigrams each (2 primary + 1 nuclear) and carry the most structural tension in any hexagram.

**Correspondence and Holding Together**: the 2nd/5th line relationship (correspondence, if they differ in kind) and the 4th/5th line relationship (holding together, adjacent lines of differing character) are usually the two most informative structural checks in a hexagram, after trigram identity. See `cheatsheet.md` for the specific favorable/unfavorable hexagram lists.

**Ruling line(s)**: separate the *constituting* ruler (whichever line defines the hexagram's meaning, good or bad) from the *governing* ruler (the line, usually the 5th, that is genuinely good and rules by both position and timing). When they're the same line, the hexagram reads cleanly; when they differ, that gap is itself part of the message.

**"Time" governs meaning**: the same line value reads differently depending on whether the hexagram represents a movement (growth/decrease), a process, a law/principle, or a symbolic situation as such. Classify the "time" before judging any individual line as good or bad.

**Good fortune ≠ moral reward**: a favorable Judgment means the trend aligns with the situation's actual direction — not that virtue is being rewarded. Read outcomes as diagnoses of alignment with circumstance.

**How to consult**: cast with three coins (or run `scripts/cast.py`), read the primary hexagram's Judgment + Image, read any moving lines, and if lines moved, read the resulting hexagram too. Full method: `patterns.md`. Quick tables: `cheatsheet.md`.

---

## Chapter Index

| # | Title | Upper / Lower Trigrams |
|---|-------|----------------|
| [ch01](chapters/ch01-the-creative.md) | The Creative | Ch'ien / Ch'ien |
| [ch02](chapters/ch02-the-receptive.md) | The Receptive | K'un / K'un |
| [ch03](chapters/ch03-difficulty-at-the-beginning.md) | Difficulty at the Beginning | K'an / Chên |
| [ch04](chapters/ch04-youthful-folly.md) | Youthful Folly | Kên / K'an |
| [ch05](chapters/ch05-waiting-nourishment.md) | Waiting (Nourishment) | K'an / Ch'ien |
| [ch06](chapters/ch06-conflict.md) | Conflict | Ch'ien / K'an |
| [ch07](chapters/ch07-the-army.md) | The Army | K'un / K'an |
| [ch08](chapters/ch08-holding-together-union.md) | Holding Together [Union] | K'an / K'un |
| [ch09](chapters/ch09-the-taming-power-of-the-small.md) | The Taming Power of the Small | Sun / Ch'ien |
| [ch10](chapters/ch10-treading-conduct.md) | Treading [Conduct] | Ch'ien / Tui |
| [ch11](chapters/ch11-peace.md) | Peace | K'un / Ch'ien |
| [ch12](chapters/ch12-standstill-stagnation.md) | Standstill [Stagnation] | Ch'ien / K'un |
| [ch13](chapters/ch13-fellowship-with-men.md) | Fellowship with Men | Ch'ien / Li |
| [ch14](chapters/ch14-possession-in-great-measure.md) | Possession in Great Measure | Li / Ch'ien |
| [ch15](chapters/ch15-modesty.md) | Modesty | K'un / Kên |
| [ch16](chapters/ch16-enthusiasm.md) | Enthusiasm | Chên / K'un |
| [ch17](chapters/ch17-following.md) | Following | Tui / Chên |
| [ch18](chapters/ch18-work-on-what-has-been-spoiled-decay.md) | Work on What Has Been Spoiled [Decay] | Kên / Sun |
| [ch19](chapters/ch19-approach.md) | Approach | K'un / Tui |
| [ch20](chapters/ch20-contemplation-view.md) | Contemplation (View) | Sun / K'un |
| [ch21](chapters/ch21-biting-through.md) | Biting Through | Li / Chên |
| [ch22](chapters/ch22-grace.md) | Grace | Kên / Li |
| [ch23](chapters/ch23-splitting-apart.md) | Splitting Apart | Kên / K'un |
| [ch24](chapters/ch24-return-the-turning-point.md) | Return (The Turning Point) | K'un / Chên |
| [ch25](chapters/ch25-innocence-the-unexpected.md) | Innocence (The Unexpected) | Ch'ien / Chên |
| [ch26](chapters/ch26-the-taming-power-of-the-great.md) | The Taming Power of the Great | Kên / Ch'ien |
| [ch27](chapters/ch27-the-corners-of-the-mouth.md) | The Corners of the Mouth | Kên / Chên |
| [ch28](chapters/ch28-preponderance-of-the-great.md) | Preponderance of the Great | Tui / Sun |
| [ch29](chapters/ch29-the-abysmal-water.md) | The Abysmal (Water) | K'an / K'an |
| [ch30](chapters/ch30-the-clinging-fire.md) | The Clinging, Fire | Li / Li |
| [ch31](chapters/ch31-influence-wooing.md) | Influence (Wooing) | Tui / Kên |
| [ch32](chapters/ch32-duration.md) | Duration | Chên / Sun |
| [ch33](chapters/ch33-retreat.md) | Retreat | Ch'ien / Kên |
| [ch34](chapters/ch34-the-power-of-the-great.md) | The Power of the Great | Chên / Ch'ien |
| [ch35](chapters/ch35-progress.md) | Progress | Li / K'un |
| [ch36](chapters/ch36-darkening-of-the-light.md) | Darkening of the Light | K'un / Li |
| [ch37](chapters/ch37-the-family-the-clan.md) | The Family [The Clan] | Sun / Li |
| [ch38](chapters/ch38-opposition.md) | Opposition | Li / Tui |
| [ch39](chapters/ch39-obstruction.md) | Obstruction | K'an / Kên |
| [ch40](chapters/ch40-deliverance.md) | Deliverance | Chên / K'an |
| [ch41](chapters/ch41-decrease.md) | Decrease | Kên / Tui |
| [ch42](chapters/ch42-increase.md) | Increase | Sun / Chên |
| [ch43](chapters/ch43-break-through-resoluteness.md) | Break-through (Resoluteness) | Tui / Ch'ien |
| [ch44](chapters/ch44-coming-to-meet.md) | Coming to Meet | Ch'ien / Sun |
| [ch45](chapters/ch45-gathering-together-massing.md) | Gathering Together [Massing] | Tui / K'un |
| [ch46](chapters/ch46-pushing-upward.md) | Pushing Upward | K'un / Sun |
| [ch47](chapters/ch47-oppression-exhaustion.md) | Oppression (Exhaustion) | Tui / K'an |
| [ch48](chapters/ch48-the-well.md) | The Well | K'an / Sun |
| [ch49](chapters/ch49-revolution-molting.md) | Revolution (Molting) | Tui / Li |
| [ch50](chapters/ch50-the-caldron.md) | The Caldron | Li / Sun |
| [ch51](chapters/ch51-the-arousing-shock-thunder.md) | The Arousing (Shock, Thunder) | Chên / Chên |
| [ch52](chapters/ch52-keeping-still-mountain.md) | Keeping Still, Mountain | Kên / Kên |
| [ch53](chapters/ch53-development-gradual-progress.md) | Development (Gradual Progress) | Sun / Kên |
| [ch54](chapters/ch54-the-marrying-maiden.md) | The Marrying Maiden | Chên / Tui |
| [ch55](chapters/ch55-abundance-fullness.md) | Abundance [Fullness] | Chên / Li |
| [ch56](chapters/ch56-the-wanderer.md) | The Wanderer | Li / Kên |
| [ch57](chapters/ch57-the-gentle-penetrating-wind.md) | The Gentle (Penetrating, Wind) | Sun / Sun |
| [ch58](chapters/ch58-the-joyous-lake.md) | The Joyous, Lake | Tui / Tui |
| [ch59](chapters/ch59-dispersion-dissolution.md) | Dispersion [Dissolution] | Sun / K'an |
| [ch60](chapters/ch60-limitation.md) | Limitation | K'an / Tui |
| [ch61](chapters/ch61-inner-truth.md) | Inner Truth | Sun / Tui |
| [ch62](chapters/ch62-preponderance-of-the-small.md) | Preponderance of the Small | Chên / Kên |
| [ch63](chapters/ch63-after-completion.md) | After Completion | K'an / Li |
| [ch64](chapters/ch64-before-completion.md) | Before Completion | Li / K'an |
| [ch65](chapters/ch65-discussion-of-the-trigrams.md) | The Eight Trigrams (Shuo Kua) | — |
| [ch66](chapters/ch66-the-great-treatise.md) | The Great Treatise (Ta Chuan) | — |
| [ch67](chapters/ch67-the-structure-of-the-hexagrams.md) | The Structure of the Hexagrams | — |

## Topic Index

- **Casting method (coins)** → `ch65`, `scripts/cast.py`, `patterns.md`, `cheatsheet.md`
- **Casting method (yarrow stalks)** → `ch66`, `patterns.md`
- **Correspondence** → `ch67`, `cheatsheet.md`
- **Danger / adversity** → ch03, ch06, ch29, ch39, ch47
- **Decline / excess** → ch23, ch28, ch55, ch62
- **Family, household, relationships** → ch37, ch44, ch54
- **Holding Together** → `ch67`, `cheatsheet.md`
- **Leadership, authority, rulership** → ch01, ch05, ch07, ch08, ch11, ch12, ch13, ch14, ch34
- **Moving / changing lines** → `ch66`, `cheatsheet.md`
- **Nuclear trigrams** → `ch65`, `ch67`
- **Ruling line** → `ch67`
- **Synchronicity** → Core Frameworks above (Jung's Foreword)
- **Tao / yin-yang** → `ch66`
- **Timing, patience, retreat** → ch05, ch33, ch53
- **Trigram attributes / family roles** → `ch65`

## Supporting Files

- [glossary.md](glossary.md) — all key terms with definitions
- [patterns.md](patterns.md) — casting methods and interpretive techniques
- [cheatsheet.md](cheatsheet.md) — quick-reference tables and decision rules
- [scripts/cast.py](scripts/cast.py) — interactive hexagram casting tool (stdlib Python, no dependencies)

---

## Scope & Limits

This skill covers the Wilhelm/Baynes translation's content only, synthesized into
practitioner-facing chapters — it does not reproduce the book's prose at length.
For a different translation's wording or scholarly commentary beyond this edition,
consult the source book directly. `scripts/cast.py` simulates a genuine random
cast; it does not predict or guarantee any real-world outcome.

**Copyright note**: this skill's content is derived from a copyrighted
translation (Princeton University Press, Bollingen Series XIX) and is kept
private for personal use — see the book-to-skill converter's copyright policy.
