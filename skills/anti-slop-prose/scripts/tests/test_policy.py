import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from policy import get_policy, POLICIES  # noqa: E402


class PolicyTests(unittest.TestCase):
    def test_all_nine_genres_present(self):
        expected = {
            "linkedin", "personal", "email", "social", "fiction",
            "readme", "technical", "student", "academic",
        }
        self.assertEqual(set(POLICIES.keys()), expected)

    def test_get_policy_is_case_insensitive(self):
        self.assertEqual(get_policy("LinkedIn").name, "linkedin")

    def test_unknown_genre_raises_value_error(self):
        with self.assertRaises(ValueError):
            get_policy("haiku")

    def test_linkedin_requires_contractions_and_allows_fragments(self):
        policy = get_policy("linkedin")
        self.assertTrue(policy.require_contractions)
        self.assertTrue(policy.allow_fragments)

    def test_academic_is_not_conversational(self):
        policy = get_policy("academic")
        self.assertFalse(policy.conversational)
        self.assertFalse(policy.require_contractions)
        self.assertFalse(policy.check_nominalizations)


if __name__ == "__main__":
    unittest.main()
