import io
import sys
import unittest
from contextlib import redirect_stderr
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from metrics import analyze, main  # noqa: E402


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


class CliArgumentTests(unittest.TestCase):
    def test_stdin_and_input_file_together_is_an_error(self):
        tmp_path = Path(__file__).resolve().parent / "_tmp_cli_test_input.txt"
        tmp_path.write_text("placeholder text for the test file", encoding="utf-8")
        try:
            stderr = io.StringIO()
            with patch.object(sys, "argv", ["metrics.py", str(tmp_path), "--stdin"]):
                with redirect_stderr(stderr):
                    with self.assertRaises(SystemExit) as ctx:
                        main()
            self.assertEqual(ctx.exception.code, 2)
            self.assertIn("--stdin", stderr.getvalue())
            self.assertIn("mutually exclusive", stderr.getvalue())
        finally:
            tmp_path.unlink()


if __name__ == "__main__":
    unittest.main()
