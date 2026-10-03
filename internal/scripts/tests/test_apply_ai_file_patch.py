import json
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

from internal.scripts.ai.apply_ai_file_patch import apply_ai_file_patch


class ApplyAiFilePatchTests(unittest.TestCase):
    def test_applies_pom_and_source_files_from_response_body(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            project_dir = Path(temp_dir)
            response_body = json.dumps(
                {
                    "choices": [
                        {
                            "message": {
                                "content": json.dumps(
                                    {
                                        "pom_xml": "<project><modelVersion>4.0.0</modelVersion></project>",
                                        "src/main/java/com/example/App.java": "class App {}",
                                    }
                                )
                            }
                        }
                    ]
                }
            )

            apply_ai_file_patch(str(project_dir), response_body, emit_writes=False)

            pom_path = project_dir / "pom.xml"
            source_path = project_dir / "src/main/java/com/example/App.java"
            self.assertTrue(pom_path.exists())
            self.assertTrue(source_path.exists())
            ET.fromstring(pom_path.read_text(encoding="utf-8"))
            self.assertEqual(source_path.read_text(encoding="utf-8"), "class App {}")


if __name__ == "__main__":
    unittest.main()