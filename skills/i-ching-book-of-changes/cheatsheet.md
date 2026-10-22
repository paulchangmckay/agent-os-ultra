# Cheatsheet

## Casting: coin values
| 3 coins | Sum | Line type | Moving? | Drawn as |
|---|---|---|---|---|
| 3 heads (yang) | 9 | Old yang | Yes → becomes yin | ━━━ → changing |
| 2 heads + 1 tail | 8 | Young yin | No | ━ ━ |
| 1 head + 2 tails | 7 | Young yang | No | ━━━ |
| 3 tails (yin) | 6 | Old yin | Yes → becomes yang | ━ ━ → changing |

Run `scripts/cast.py` to cast automatically and get the exact chapter file(s) to read.

## Decision rule: what to read after casting
| Moving lines | Read |
|---|---|
| None | Primary hexagram's Judgment + Image only |
| One or more | Primary hexagram's Judgment + Image, **plus** the text of every moving line, **plus** the resulting hexagram's Judgment + Image |

The source (Appendix I) gives no separate weighting rule for 2+ simultaneous moving lines — read all of them as stated above; don't import a hierarchy from another tradition.

## The Eight Trigrams
| Trigram | Attribute | Image | Family | 
|---|---|---|---|
| Ch'ien ☰ | strong | heaven | father |
| K'un ☷ | yielding | earth | mother |
| Chên ☳ | movement | thunder | eldest son |
| K'an ☵ | dangerous | water | middle son |
| Kên ☶ | standstill | mountain | youngest son |
| Sun ☴ | penetrating | wind/wood | eldest daughter |
| Li ☲ | clinging | fire | middle daughter |
| Tui ☱ | joyous | lake | youngest daughter |

## King Wên lookup: (upper, lower) trigram → hexagram number
| upper \ lower | Ch'ien | Chên | K'an | Kên | K'un | Sun | Li | Tui |
|---|---|---|---|---|---|---|---|---|
| **Ch'ien** | 1 | 25 | 6 | 33 | 12 | 44 | 13 | 10 |
| **Chên** | 34 | 51 | 40 | 62 | 16 | 32 | 55 | 54 |
| **K'an** | 5 | 3 | 29 | 39 | 8 | 48 | 63 | 60 |
| **Kên** | 26 | 27 | 4 | 52 | 23 | 18 | 22 | 41 |
| **K'un** | 11 | 24 | 7 | 15 | 2 | 46 | 36 | 19 |
| **Sun** | 9 | 42 | 59 | 53 | 20 | 57 | 37 | 61 |
| **Li** | 14 | 21 | 64 | 56 | 35 | 50 | 30 | 38 |
| **Tui** | 43 | 17 | 47 | 31 | 45 | 28 | 49 | 58 |

## The Six Places (line positions)
| Position | Meaning | Default reading |
|---|---|---|
| 1 (bottom) | Beginning, not yet in the situation | Neutral — wait |
| 2 | Official/son; central in lower trigram | Usually favorable |
| 3 | Transitional, at the trigram boundary | Riskiest position |
| 4 | Minister, close to the ruler | Requires caution |
| 5 | Ruler's place; central in upper trigram | Usually strong/favorable |
| 6 (top) | Withdrawn from the affairs of the time | Excess, or transcendence |

Correct = firm(yang) line in an odd place (1,3,5) or yielding(yin) line in an even place (2,4,6). Correctness matters less than **centrality** (2nd/5th) in most cases.

## Correspondence (2nd ↔ 5th line): quick read
| Pattern | Reading | Example hexagrams |
|---|---|---|
| Strong 2nd, yielding 5th ruler | Favorable | 4, 7, 11, 14, 18, 19, 32, 34, 38, 40, 41, 46, 50 |
| Yielding 2nd, strong 5th ruler | Unfavorable | 12, 13, 17, 20, 31 |
| Yielding 2nd, strong 5th ruler | Difficult but explainable | 3, 33, 39, 63 |

(1st/4th correspondence follows the same firm/yielding-must-differ rule. 3rd/top correspondence "hardly ever occurs" as genuinely favorable — per source.)

## Holding Together (4th ↔ 5th line): quick read
| Pattern | Reading | Example hexagrams |
|---|---|---|
| Yielding minister (4th), strong ruler (5th) | Favorable | 8, 9, 20, 29, 37, 42, 48, 53, 57, 59, 60, 61 |
| Strong, "incorrect" 4th, yielding ruler (5th) | Unfavorable | 30, 32, 35, 50, 51 |

## Tells and smells
- **Doubled (pure) trigram hexagrams** (1, 2, 29, 30, 51, 52, 57, 58) — a single force taken to its purest, most intensified expression; read the trigram's attribute at maximum strength, not moderated by a contrasting partner.
- **A line at position 3 or 4 reads unusually tense** — check nuclear trigrams first; these positions belong to 3 trigrams each (2 primary + 1 nuclear) and carry the most structural load.
- **Constituting ruler ≠ governing ruler** — the hexagram is describing a gap between what defines the situation and what would actually resolve it well; don't collapse the two into one reading.
- **A hexagram's line texts feel oddly specific/concrete** (an animal, a plant, a body part) — check the trigram's "Additional Symbols" list in `ch65-discussion-of-the-trigrams.md` before assuming the imagery is unique to that line.
