#!/usr/bin/env python3
# Adapted from udaysharmadev/Not-Ai — see THIRD_PARTY_NOTICES.md
"""anti-slop-prose: metrics.py

Readability, information density, and stance metrics. Phase 2 diagnostic —
read-only, run manually or as an optional extra check alongside gate.py.

Usage:
    python3 scripts/metrics.py [input_file]
    python3 scripts/metrics.py [input_file] --json
    python3 scripts/metrics.py --stdin
"""

import argparse
import json
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _shared import (  # noqa: E402
    get_sentences,
    tokenize_words,
    nominalization_stats,
    stance_balance,
)


def count_syllables(word: str) -> int:
    """Rough syllable counter for English words."""
    word = word.lower().strip(".,!?;:'\"()")
    if not word:
        return 0
    if word.endswith('e') and len(word) > 2:
        word = word[:-1]
    vowels = re.findall(r'[aeiou]+', word)
    return max(1, len(vowels))


def count_complex_words(words: list[str]) -> int:
    """Count polysyllabic words (3+ syllables), used for Gunning Fog."""
    return sum(1 for w in words if count_syllables(w) >= 3)


def flesch_kincaid_grade(sentences: list[str], words: list[str]) -> float:
    if not sentences or not words:
        return 0.0
    total_syllables = sum(count_syllables(w) for w in words)
    avg_sentence_length = len(words) / len(sentences)
    avg_syllables_per_word = total_syllables / len(words) if words else 0
    grade = 0.39 * avg_sentence_length + 11.8 * avg_syllables_per_word - 15.59
    return round(grade, 1)


def gunning_fog(sentences: list[str], words: list[str]) -> float:
    if not sentences or not words:
        return 0.0
    avg_sentence_length = len(words) / len(sentences)
    pct_complex = count_complex_words(words) / len(words) * 100 if words else 0
    return round(0.4 * (avg_sentence_length + pct_complex), 1)


def flesch_reading_ease(sentences: list[str], words: list[str]) -> float:
    if not sentences or not words:
        return 0.0
    total_syllables = sum(count_syllables(w) for w in words)
    avg_sentence_length = len(words) / len(sentences)
    avg_syllables = total_syllables / len(words) if words else 0
    return round(206.835 - 1.015 * avg_sentence_length - 84.6 * avg_syllables, 1)


def information_density_proxy(words: list[str], text: str) -> dict:
    prepositions = {'of', 'in', 'to', 'for', 'on', 'with', 'at', 'by', 'from',
                    'into', 'through', 'during', 'before', 'after', 'above', 'below',
                    'between', 'among', 'under', 'about', 'against', 'without', 'within',
                    'around', 'along', 'following', 'across', 'behind', 'beyond',
                    'including', 'throughout', 'regarding', 'concerning'}
    words_lower = [w.lower() for w in words]
    prep_rate = sum(1 for w in words_lower if w in prepositions) / len(words) if words else 0
    weak_verbs = {'is', 'are', 'was', 'were', 'be', 'been', 'being',
                  'have', 'has', 'had', 'do', 'does', 'did',
                  'will', 'would', 'could', 'should', 'may', 'might', 'can', 'shall'}
    weak_verb_rate = sum(1 for w in words_lower if w in weak_verbs) / len(words) if words else 0
    nom = nominalization_stats(text, words)
    density_score = (prep_rate * 200) + (nom["rate_per_1000_words"] / 2)
    return {
        "preposition_rate": round(prep_rate, 3),
        "weak_verb_rate": round(weak_verb_rate, 3),
        "nominalization_rate_per_1000": nom["rate_per_1000_words"],
        "nominalization_assessment": nom["assessment"],
        "estimated_density_score": round(density_score, 1),
        "assessment": (
            "high density, characteristic of formal academic prose" if density_score > 50 else
            "moderate density" if density_score > 30 else
            "low density, conversational"
        ),
    }


def tone_markers(text: str) -> dict:
    text_lower = text.lower()
    word_count = len(text.split())
    hedge_patterns = [
        r'\bmight\b', r'\bcould\b', r'\bmay\b', r'\bperhaps\b', r'\bpossibly\b',
        r'\bappears? to\b', r'\bseems? to\b', r'\btends? to\b',
        r'\bi think\b', r'\bi believe\b', r'\bone might\b', r'\bargua\w+\b',
        r'\bsuggests?\b', r'\bindicates?\b', r'\bseems?\b',
    ]
    hedge_count = sum(len(re.findall(p, text_lower)) for p in hedge_patterns)
    booster_patterns = [
        r'\bclearly\b', r'\bobviously\b', r'\bcertainly\b', r'\bdefinitely\b',
        r'\bundoubtedly\b', r'\bwithout question\b', r'\bit is clear\b',
        r'\bof course\b', r'\bevident\w*\b',
    ]
    booster_count = sum(len(re.findall(p, text_lower)) for p in booster_patterns)
    question_count = text.count('?')
    reader_address = len(re.findall(r'\byou\b|\byour\b', text_lower))
    first_person = len(re.findall(r'\bi\b|\bme\b|\bmy\b|\bwe\b|\bour\b', text_lower))
    return {
        "hedge_count": hedge_count,
        "hedge_rate_per_1000": round(hedge_count / word_count * 1000, 1) if word_count else 0,
        "booster_count": booster_count,
        "booster_rate_per_1000": round(booster_count / word_count * 1000, 1) if word_count else 0,
        "question_count": question_count,
        "reader_address_count": reader_address,
        "first_person_count": first_person,
        "first_person_rate_per_1000": round(first_person / word_count * 1000, 1) if word_count else 0,
        "stance_balance": stance_balance(hedge_count, booster_count, word_count),
    }


def analyze(text: str) -> dict:
    sentences = get_sentences(text)
    words = tokenize_words(text)
    readability = {
        "flesch_kincaid_grade": flesch_kincaid_grade(sentences, words),
        "gunning_fog_index": gunning_fog(sentences, words),
        "flesch_reading_ease": flesch_reading_ease(sentences, words),
    }
    ease = readability["flesch_reading_ease"]
    readability["readability_assessment"] = (
        "very easy" if ease > 80 else
        "easy" if ease > 70 else
        "standard" if ease > 60 else
        "difficult" if ease > 40 else
        "very difficult"
    )
    return {
        "word_count": len(words),
        "sentence_count": len(sentences),
        "readability": readability,
        "information_density": information_density_proxy(words, text),
        "tone_markers": tone_markers(text),
    }


def human_readable_summary(result: dict) -> str:
    lines = ["ANTI-SLOP-PROSE: METRICS", "-" * 40]
    r = result['readability']
    lines.append(f"\nREADABILITY")
    lines.append(f"  Flesch-Kincaid Grade:  {r['flesch_kincaid_grade']}")
    lines.append(f"  Gunning Fog Index:     {r['gunning_fog_index']} ({r['readability_assessment']})")
    lines.append(f"  Flesch Reading Ease:   {r['flesch_reading_ease']} / 100")
    d = result['information_density']
    lines.append(f"\nINFORMATION DENSITY")
    lines.append(f"  Density score: {d['estimated_density_score']}  |  {d['assessment']}")
    lines.append(f"  Nominalizations: {d['nominalization_rate_per_1000']} per 1,000 words | {d['nominalization_assessment']}")
    t = result['tone_markers']
    lines.append(f"\nEPISTEMIC STANCE")
    lines.append(f"  Hedges: {t['hedge_count']}  Boosters: {t['booster_count']}  Balance: {t['stance_balance']}")
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(description='anti-slop-prose: writing metrics')
    parser.add_argument('input_file', nargs='?', help='Input text file')
    parser.add_argument('--stdin', action='store_true', help='Read from stdin')
    parser.add_argument('--json', action='store_true', help='Output raw JSON')
    args = parser.parse_args()
    if args.stdin or not args.input_file:
        text = sys.stdin.read()
    else:
        path = Path(args.input_file)
        if not path.exists():
            print(f"Error: file not found: {args.input_file}", file=sys.stderr)
            sys.exit(1)
        text = path.read_text(encoding='utf-8')
    if not text.strip():
        print("Error: no text provided", file=sys.stderr)
        sys.exit(1)
    result = analyze(text)
    print(json.dumps(result, indent=2, ensure_ascii=False) if args.json else human_readable_summary(result))


if __name__ == '__main__':
    main()
