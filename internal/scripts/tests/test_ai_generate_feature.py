import json
import runpy
import sys
import tempfile
import unittest
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "ai_generate_feature.py"


class FakeResponse:
    def __init__(self, body):
        self.body = body

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        return False

    def read(self):
        return self.body


class AiGenerateFeaturePomTests(unittest.TestCase):
    def run_generator(self, pom_xml):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        project = root / "project"
        project.mkdir()
        prompt = root / "prompt.txt"
        prompt.write_text("test prompt", encoding="utf-8")
        request_file = root / "request.json"
        response_file = root / "response.json"

        content = json.dumps({"pom_xml": pom_xml}, ensure_ascii=False)
        body = json.dumps(
            {"choices": [{"message": {"content": content}}]}
        ).encode("utf-8")
        argv = [
            str(SCRIPT), str(project), str(prompt), str(request_file),
            str(response_file), "test-model", "http://127.0.0.1/test", "",
        ]
        with patch.object(sys, "argv", argv), patch.object(
            urllib.request, "urlopen", return_value=FakeResponse(body)
        ):
            runpy.run_path(str(SCRIPT), run_name="__main__")
        return project / "pom.xml"

    def test_normalizes_literal_escaped_whitespace_only_when_xml_is_valid(self):
        malformed = (
            '<project xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"'
            r'\n    xsi:schemaLocation="urn:test test.xsd">\n'
            "</project>"
        )
        pom_path = self.run_generator(malformed)
        pom = pom_path.read_text(encoding="utf-8")

        self.assertIn("\n    xsi:schemaLocation", pom)
        ET.fromstring(pom)

    def test_leaves_valid_pom_unchanged(self):
        valid = '<project>\n  <modelVersion>4.0.0</modelVersion>\n</project>'
        pom_path = self.run_generator(valid)
        self.assertEqual(pom_path.read_text(encoding="utf-8"), valid)

    def test_rejects_invalid_pom_before_writing_it(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            project = root / "project"
            project.mkdir()
            prompt = root / "prompt.txt"
            prompt.write_text("test prompt", encoding="utf-8")
            request_file = root / "request.json"
            response_file = root / "response.json"
            content = json.dumps({"pom_xml": "<project><broken></project>"})
            body = json.dumps(
                {"choices": [{"message": {"content": content}}]}
            ).encode("utf-8")
            argv = [
                str(SCRIPT), str(project), str(prompt), str(request_file),
                str(response_file), "test-model", "http://127.0.0.1/test", "",
            ]
            with patch.object(sys, "argv", argv), patch.object(
                urllib.request, "urlopen", return_value=FakeResponse(body)
            ), self.assertRaises(ValueError):
                runpy.run_path(str(SCRIPT), run_name="__main__")

            self.assertFalse((project / "pom.xml").exists())


if __name__ == "__main__":
    unittest.main()
