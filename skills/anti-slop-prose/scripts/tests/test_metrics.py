import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from metrics import analyze  # noqa: E402


class MetricsTests(unittest.TestCase):
    def test_analyze_reports_expected_top_level_keys(self):
        result = analyze("This is a short, plain sentence. It has two parts.")
        self.assertEqual(
            set(result.keys()),
            {"word_count", "sentence_count", "readability", "information_density", "tone_markers"},
        )

    def test_word_and_sentence_counts(self):
        result = analyze("Short sentence one. Short sentence two.")
        self.assertEqual(result["word_count"], 6)
        self.assertEqual(result["sentence_count"], 2)

    def test_dense_nominalized_text_flagged_high(self):
        text = ("Implementation of the specification required consideration of "
                 "documentation, coordination, and verification. " * 5)
        result = analyze(text)
        self.assertIn(
            result["information_density"]["nominalization_assessment"],
            {"elevated for this proxy", "high for this proxy"},
        )

    def test_flesch_kincaid_grade_is_numeric(self):
        result = analyze("The cat sat on the mat. It was warm.")
        self.assertIsInstance(result["readability"]["flesch_kincaid_grade"], float)

    def test_stance_balance_absent_with_no_markers(self):
        result = analyze("The deploy finished at 2:14 a.m. It rolled back cleanly.")
        self.assertEqual(result["tone_markers"]["stance_balance"], "absent")


if __name__ == "__main__":
    unittest.main()
