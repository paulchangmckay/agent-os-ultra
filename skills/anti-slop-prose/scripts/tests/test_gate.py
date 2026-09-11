import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from gate import evaluate  # noqa: E402


class GateTests(unittest.TestCase):
    def test_typography_is_advisory_by_default(self):
        result = evaluate('She called it “finished” — then revised it.')
        self.assertTrue(result.passed)
        self.assertEqual([item.severity for item in result.findings], ["review", "review"])

    def test_ascii_house_style_can_make_typography_blocking(self):
        result = evaluate("This is fine — except for the dash.", ascii_punctuation=True)
        self.assertFalse(result.passed)
        self.assertEqual([item.severity for item in result.findings], ["error"])

    def test_missing_explicitly_protected_text_is_blocking(self):
        result = evaluate(
            "The deploy finished on Tuesday.",
            "technical",
            protected_terms=["Tuesday", "Nagpur"],
        )
        self.assertFalse(result.passed)
        missing = [item.span for item in result.findings if item.rule == "protected-content"]
        self.assertEqual(missing, ["Nagpur"])

    def test_protected_terms_must_be_nonempty_strings(self):
        with self.assertRaises(ValueError):
            evaluate("Text", protected_terms=[""])

    def test_conversational_contract_is_advisory(self):
        text = "This is a formal note about a project. " * 12
        result = evaluate(text, "linkedin")
        self.assertTrue(result.passed)
        self.assertTrue(any(item.rule == "contractions" for item in result.findings))

    def test_academic_profile_does_not_request_contractions(self):
        text = "This study examines a small sample. " * 12
        result = evaluate(text, "academic")
        self.assertFalse(any(item.rule == "contractions" for item in result.findings))

    def test_student_profile_flags_choppy_report_prose(self):
        text = (
            "The input was noisy. Slang caused problems. Typos broke the parser. "
            "Emojis confused the tokenizer. The classifier still returned a label."
        )
        result = evaluate(text, "student")
        self.assertTrue(result.passed)
        self.assertEqual(result.counts["max_consecutive_short"], 5)
        self.assertTrue(any(item.rule == "choppy-run" for item in result.findings))

    def test_social_profile_allows_a_short_sentence_run(self):
        text = "It failed. We waited. Nothing changed. So we rolled back."
        result = evaluate(text, "social")
        self.assertFalse(any(item.rule == "choppy-run" for item in result.findings))

    def test_empty_text_fails(self):
        result = evaluate("", "technical")
        self.assertFalse(result.passed)
        self.assertEqual(result.findings[0].rule, "nonempty")

    def test_tier_vocabulary_is_flagged(self):
        result = evaluate("This robust, groundbreaking solution leverages a seamless framework.", "technical")
        rules = [item.rule for item in result.findings]
        self.assertIn("tier-2-vocabulary", rules)


if __name__ == "__main__":
    unittest.main()
