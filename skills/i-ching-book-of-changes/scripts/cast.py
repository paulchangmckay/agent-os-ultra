#!/usr/bin/env python3
"""
Cast an I Ching hexagram using the three-coin method.

Method (Wilhelm/Baynes, Appendix I, "The Coin Oracle"):
  Three coins are thrown together, six times (once per line, bottom to top).
  Inscribed side (tails) = yin = 2. Reverse side (heads) = yang = 3.
  Sum of the three coins per throw:
    6 = old yin  (broken line, MOVING)
    7 = young yang (solid line, stable)
    8 = young yin  (broken line, stable)
    9 = old yang (solid line, MOVING)
  Moving lines flip to build the resulting hexagram: old yin (6) -> yang,
  old yang (9) -> yin. Stable lines (7, 8) carry over unchanged.

Stdlib only. Run directly: python3 cast.py
"""
import random
import re

YANG_GLYPH = "━━━"       # solid line
YIN_GLYPH = "━ ━"             # broken line

# --- Trigrams, as bottom-to-top bit tuples (1 = yang, 0 = yin) ---------
# Cross-checked against Shuo Kua ch. X (family of trigrams: each "child"
# trigram's determining line is where the opposite-sex parent's line
# entered K'un/Ch'ien at the bottom/middle/top place).
TRIGRAM_BITS = {
    "Ch'ien": (1, 1, 1),   # Heaven -- father
    "K'un":   (0, 0, 0),   # Earth -- mother
    "Chên":   (1, 0, 0),   # Thunder -- eldest son
    "K'an":   (0, 1, 0),   # Water -- middle son
    "Kên":    (0, 0, 1),   # Mountain -- youngest son
    "Sun":    (0, 1, 1),   # Wind -- eldest daughter
    "Li":     (1, 0, 1),   # Fire -- middle daughter
    "Tui":    (1, 1, 0),   # Lake -- youngest daughter
}
BITS_TO_TRIGRAM = {bits: name for name, bits in TRIGRAM_BITS.items()}

# --- King Wên sequence: (upper trigram, lower trigram) -> hexagram number
# Built directly from Appendix II, "The Hexagrams Arranged by Houses"
# ("X with Y is NAME (n)" = upper trigram X, lower trigram Y). Verified to
# cover 1-64 exactly once with no gaps or duplicates.
KING_WEN = {
    ("Ch'ien", "Ch'ien"): 1,  ("Ch'ien", "Chên"): 25, ("Ch'ien", "K'an"): 6,
    ("Ch'ien", "Kên"): 33,    ("Ch'ien", "K'un"): 12, ("Ch'ien", "Sun"): 44,
    ("Ch'ien", "Li"): 13,     ("Ch'ien", "Tui"): 10,

    ("Chên", "Ch'ien"): 34,   ("Chên", "Chên"): 51,   ("Chên", "K'an"): 40,
    ("Chên", "Kên"): 62,      ("Chên", "K'un"): 16,   ("Chên", "Sun"): 32,
    ("Chên", "Li"): 55,       ("Chên", "Tui"): 54,

    ("K'an", "Ch'ien"): 5,    ("K'an", "Chên"): 3,    ("K'an", "K'an"): 29,
    ("K'an", "Kên"): 39,      ("K'an", "K'un"): 8,    ("K'an", "Sun"): 48,
    ("K'an", "Li"): 63,       ("K'an", "Tui"): 60,

    ("Kên", "Ch'ien"): 26,    ("Kên", "Chên"): 27,    ("Kên", "K'an"): 4,
    ("Kên", "Kên"): 52,       ("Kên", "K'un"): 23,    ("Kên", "Sun"): 18,
    ("Kên", "Li"): 22,        ("Kên", "Tui"): 41,

    ("K'un", "Ch'ien"): 11,   ("K'un", "Chên"): 24,   ("K'un", "K'an"): 7,
    ("K'un", "Kên"): 15,      ("K'un", "K'un"): 2,    ("K'un", "Sun"): 46,
    ("K'un", "Li"): 36,       ("K'un", "Tui"): 19,

    ("Sun", "Ch'ien"): 9,     ("Sun", "Chên"): 42,    ("Sun", "K'an"): 59,
    ("Sun", "Kên"): 53,       ("Sun", "K'un"): 20,    ("Sun", "Sun"): 57,
    ("Sun", "Li"): 37,        ("Sun", "Tui"): 61,

    ("Li", "Ch'ien"): 14,     ("Li", "Chên"): 21,     ("Li", "K'an"): 64,
    ("Li", "Kên"): 56,        ("Li", "K'un"): 35,     ("Li", "Sun"): 50,
    ("Li", "Li"): 30,         ("Li", "Tui"): 38,

    ("Tui", "Ch'ien"): 43,    ("Tui", "Chên"): 17,    ("Tui", "K'an"): 47,
    ("Tui", "Kên"): 31,       ("Tui", "K'un"): 45,    ("Tui", "Sun"): 28,
    ("Tui", "Li"): 49,        ("Tui", "Tui"): 58,
}

# --- Hexagram titles, exactly as printed in the source (Book I headers).
# Slugs are derived from these at runtime (see slugify()) rather than
# hand-duplicated, so the two can never drift apart.
HEXAGRAM_TITLES = {
    1: "The Creative", 2: "The Receptive", 3: "Difficulty at the Beginning",
    4: "Youthful Folly", 5: "Waiting (Nourishment)", 6: "Conflict",
    7: "The Army", 8: "Holding Together [Union]",
    9: "The Taming Power of the Small", 10: "Treading [Conduct]",
    11: "Peace", 12: "Standstill [Stagnation]", 13: "Fellowship with Men",
    14: "Possession in Great Measure", 15: "Modesty", 16: "Enthusiasm",
    17: "Following", 18: "Work on What Has Been Spoiled [Decay]",
    19: "Approach", 20: "Contemplation (View)", 21: "Biting Through",
    22: "Grace", 23: "Splitting Apart", 24: "Return (The Turning Point)",
    25: "Innocence (The Unexpected)", 26: "The Taming Power of the Great",
    27: "The Corners of the Mouth", 28: "Preponderance of the Great",
    29: "The Abysmal (Water)", 30: "The Clinging, Fire",
    31: "Influence (Wooing)", 32: "Duration", 33: "Retreat",
    34: "The Power of the Great", 35: "Progress",
    36: "Darkening of the Light", 37: "The Family [The Clan]",
    38: "Opposition", 39: "Obstruction", 40: "Deliverance", 41: "Decrease",
    42: "Increase", 43: "Break-through (Resoluteness)",
    44: "Coming to Meet", 45: "Gathering Together [Massing]",
    46: "Pushing Upward", 47: "Oppression (Exhaustion)", 48: "The Well",
    49: "Revolution (Molting)", 50: "The Caldron",
    51: "The Arousing (Shock, Thunder)", 52: "Keeping Still, Mountain",
    53: "Development (Gradual Progress)", 54: "The Marrying Maiden",
    55: "Abundance [Fullness]", 56: "The Wanderer",
    57: "The Gentle (Penetrating, Wind)", 58: "The Joyous, Lake",
    59: "Dispersion [Dissolution]", 60: "Limitation", 61: "Inner Truth",
    62: "Preponderance of the Small", 63: "After Completion",
    64: "Before Completion",
}


def slugify(title):
    """English hexagram title -> the-file-slug used under chapters/."""
    s = re.sub(r"[\[\](),]", "", title)
    s = s.lower().strip()
    return re.sub(r"\s+", "-", s)


def throw_line():
    """Throw 3 coins for one line. Returns (coin_values, line_sum)."""
    coins = [random.choice([2, 3]) for _ in range(3)]
    return coins, sum(coins)


def line_from_sum(total):
    """Map a coin-sum (6/7/8/9) to (is_yang, is_moving)."""
    return {
        6: (False, True),   # old yin
        7: (True, False),   # young yang
        8: (False, False),  # young yin
        9: (True, True),    # old yang
    }[total]


def hexagram_lookup(bits_bottom_to_top):
    """6 bits (bottom to top) -> (hexagram number, title, slug)."""
    lower = BITS_TO_TRIGRAM[tuple(bits_bottom_to_top[0:3])]
    upper = BITS_TO_TRIGRAM[tuple(bits_bottom_to_top[3:6])]
    number = KING_WEN[(upper, lower)]
    title = HEXAGRAM_TITLES[number]
    return number, title, slugify(title)


def render_line(is_yang, is_moving):
    glyph = YANG_GLYPH if is_yang else YIN_GLYPH
    return glyph + ("  (changing)" if is_moving else "")


def cast_hexagram():
    """Throw all 6 lines, printing each as it's cast. Returns line records."""
    print("Casting hexagram (three-coin method, bottom line first)...\n")
    lines = []  # each: {"sum": int, "yang": bool, "moving": bool}
    for position in range(1, 7):
        coins, total = throw_line()
        is_yang, is_moving = line_from_sum(total)
        lines.append({"sum": total, "yang": is_yang, "moving": is_moving})
        coin_desc = ", ".join("heads" if c == 3 else "tails" for c in coins)
        print(f"Line {position}: coins = {coin_desc} (sum = {total})")
        print(f"         {render_line(is_yang, is_moving)}")
    return lines


def main():
    lines = cast_hexagram()

    primary_bits = [1 if l["yang"] else 0 for l in lines]
    number, title, slug = hexagram_lookup(primary_bits)

    print(f"\nPrimary hexagram: {number} - {title}")
    print(f"Read: chapters/ch{number:02d}-{slug}.md")

    moving_positions = [i for i, l in enumerate(lines) if l["moving"]]
    if moving_positions:
        resulting_bits = list(primary_bits)
        for i in moving_positions:
            resulting_bits[i] = 1 - resulting_bits[i]  # 6->yang, 9->yin
        r_number, r_title, r_slug = hexagram_lookup(resulting_bits)
        print(f"\nMoving lines: {[p + 1 for p in moving_positions]}")
        print(f"Resulting hexagram: {r_number} - {r_title}")
        print(f"Read: chapters/ch{r_number:02d}-{r_slug}.md")


if __name__ == "__main__":
    main()
