import json
import os
import sys
import re

CURRENT_DIR = os.path.dirname(__file__)
if CURRENT_DIR not in sys.path:
    sys.path.insert(0, CURRENT_DIR)

from pom_xml import normalize_pom_xml


FORBIDDEN_TEST_PATTERNS = (
    "MockMvc",
    "@AutoConfigureMockMvc",
    "@WebMvcTest",
    "MockBean",
    "RestTemplate",
    "TestRestTemplate",
    "getStatusCodeValue()",
    "http://localhost:",
    "http://127.0.0.1:",
    "org.springframework.test.web.servlet",
    "org.springframework.boot.test.autoconfigure.web.servlet",
    "org.springframework.boot.test.mock.mockito",
)


PACKAGE_DECL_RE = re.compile(r"^\s*package\s+([a-zA-Z_][\w.]*)\s*;", re.MULTILINE)


def expected_package_for_key(key: str) -> str | None:
    normalized = key.replace("\\", "/")
    if "/src/main/java/" in normalized:
        relative = normalized.split("/src/main/java/", 1)[1]
    elif "/src/test/java/" in normalized:
        relative = normalized.split("/src/test/java/", 1)[1]
    elif normalized.startswith("src/main/java/"):
        relative = normalized[len("src/main/java/"):]
    elif normalized.startswith("src/test/java/"):
        relative = normalized[len("src/test/java/"):]
    else:
        return None
    parts = relative.split("/")[:-1]
    if not parts:
        return None
    return ".".join(parts)


def validate_java_package(key: str, value: str) -> None:
    expected_package = expected_package_for_key(key)
    if not expected_package:
        return
    match = PACKAGE_DECL_RE.search(value)
    if not match:
        raise ValueError(
            f"AI response for {key} is missing required package declaration 'package {expected_package};'"
        )
    actual_package = match.group(1)
    if actual_package != expected_package:
        raise ValueError(
            f"AI response for {key} declares package '{actual_package}' but expected '{expected_package}'"
        )


def parse_ai_response_content(resp_body):
    resp_json = json.loads(resp_body)
    content = resp_json["choices"][0]["message"]["content"]
    content = content.strip()
    if content.startswith("```"):
        content = "\n".join(content.split("\n")[1:])
        if content.endswith("```"):
            content = content[:-3].strip()
    return json.loads(content)


def validate_ai_file_patch(data):
    """Validate the whole AI payload before anything is written; returns the normalized pom.xml (or None)."""
    if not isinstance(data, dict) or not data:
        raise ValueError("AI response must be a non-empty JSON object of file path -> content")
    pom_xml = normalize_pom_xml(data["pom_xml"]) if "pom_xml" in data else None
    for key, value in data.items():
        if key == "pom_xml":
            continue
        if not isinstance(value, str):
            raise ValueError(f"AI response for {key} is not a string")
        if key.endswith(".java"):
            validate_java_package(key, value)
        if key.endswith("Test.java"):
            for forbidden_pattern in FORBIDDEN_TEST_PATTERNS:
                if forbidden_pattern in value:
                    raise ValueError(
                        f"AI response for {key} contains unsupported Spring MVC test pattern: {forbidden_pattern}"
                    )
    return pom_xml


def apply_ai_file_patch(project_dir, response_payload, emit_writes=True):
    if isinstance(response_payload, str):
        data = parse_ai_response_content(response_payload)
    else:
        data = response_payload

    pom_xml = validate_ai_file_patch(data)
    if pom_xml is not None:
        with open(os.path.join(project_dir, "pom.xml"), "w", encoding="utf-8") as file_handle:
            file_handle.write(pom_xml)
        if emit_writes:
            print("Wrote pom.xml")

    for key, value in data.items():
        if key == "pom_xml":
            continue
        path = os.path.join(project_dir, key)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as file_handle:
            file_handle.write(value)
        if emit_writes:
            print("Wrote", key)

    return data