import sys
import unittest
from pathlib import Path


AI_DIR = Path(__file__).resolve().parents[1] / "ai"
sys.path.insert(0, str(AI_DIR))
from pom_xml import normalize_pom_xml


class PomXmlTests(unittest.TestCase):
    def test_preserves_valid_xml(self):
        pom = '<project>\n  <modelVersion>4.0.0</modelVersion>\n</project>'
        self.assertEqual(normalize_pom_xml(pom), pom)

    def test_normalizes_literal_escaped_newlines_when_result_is_valid_xml(self):
        pom = '<project xmlns:xsi="urn:test"\\n    xsi:schemaLocation="urn:test test.xsd">\\n</project>'
        normalized = normalize_pom_xml(pom)
        self.assertIn("\n    xsi:schemaLocation", normalized)
        self.assertIn("\n</project>", normalized)

    def test_rejects_invalid_xml_without_escaped_whitespace_repair(self):
        with self.assertRaisesRegex(ValueError, "invalid pom_xml"):
            normalize_pom_xml("<project><broken></project>")

    def test_rejects_non_string_pom(self):
        with self.assertRaisesRegex(ValueError, "not a string"):
            normalize_pom_xml(None)


if __name__ == "__main__":
    unittest.main()
