#!/usr/bin/env python3
# Adapted from udaysharmadev/Not-Ai — see THIRD_PARTY_NOTICES.md
"""Measurement primitives shared by metrics.py.

Import it from a sibling script with:

    from _shared import get_sentences, tokenize_words, nominalization_stats

The scripts insert their own directory onto sys.path before importing, so this
works whatever the current working directory is.
"""

import re

# HEURISTIC PROXY. This matches any word ending in a nominalizing suffix. It
# has no part-of-speech information, so it over-counts substantially against
# a real morphosyntactic tagger. Compare a figure from this proxy only
# against another figure from this proxy, a draft against its own rewrite, or
# an author against their earlier work.

NOMINALIZATION_SUFFIXES = (
    "tion", "tions",
    "ment", "ments",
    "ness", "nesses",
    "ity", "ities",
    "ance", "ances",
    "ence", "ences",
)

NOMINALIZATION_PATTERN = re.compile(
    r"\b\w+(" + "|".join(NOMINALIZATION_SUFFIXES) + r")\b",
    re.IGNORECASE,
)

HEURISTIC_NOMINALIZATION_BANDS = {
    "high": 50.0,
    "elevated": 35.0,
}

WORD_PATTERN = re.compile(r"\b[a-zA-Z]+\b")

SENTENCE_SPLIT_PATTERN = re.compile(r'(?<=[.!?])\s+(?=[A-Z"\'])')

STANCE_MIN_MARKERS = 3
STANCE_MIN_RATE_PER_1000 = 2.0


def stance_balance(hedge_count: int, booster_count: int, word_count: int) -> str:
    """Verdict on the hedge-to-booster balance, or a refusal to give one."""
    total = hedge_count + booster_count
    if total == 0:
        return "absent"
    rate = total / word_count * 1000 if word_count else 0.0
    if total < STANCE_MIN_MARKERS or rate < STANCE_MIN_RATE_PER_1000:
        return "too sparse to judge"
    if hedge_count > booster_count * 3:
        return "over-hedged"
    if booster_count > hedge_count * 2:
        return "over-assertive"
    return "calibrated"


def tokenize_words(text: str) -> list[str]:
    """Alphabetic word tokens. The canonical denominator for every rate here."""
    return WORD_PATTERN.findall(text)


def get_sentences(text: str) -> list[str]:
    """Split into sentences on terminal punctuation followed by a capital."""
    text = re.sub(r"\s+", " ", text.strip())
    sentences = SENTENCE_SPLIT_PATTERN.split(text)
    return [s.strip() for s in sentences if s.strip() and len(s.split()) >= 2]


def get_paragraphs(text: str) -> list[str]:
    """Split on blank lines."""
    paragraphs = re.split(r"\n\s*\n", text.strip())
    return [p.strip() for p in paragraphs if p.strip()]


def nominalization_stats(text: str, words: list[str] | None = None) -> dict:
    """Count nominalization-suffixed words and express the rate per 1,000 words."""
    if words is None:
        words = tokenize_words(text)

    total_words = len(words)
    count = len(NOMINALIZATION_PATTERN.findall(text))
    rate = (count / total_words * 1000) if total_words else 0.0

    if rate > HEURISTIC_NOMINALIZATION_BANDS["high"]:
        assessment = "high for this proxy"
    elif rate > HEURISTIC_NOMINALIZATION_BANDS["elevated"]:
        assessment = "elevated for this proxy"
    else:
        assessment = "normal for this proxy"

    return {
        "nominalization_count": count,
        "total_words": total_words,
        "rate_per_1000_words": round(rate, 1),
        "assessment": assessment,
    }
