import json
import os
import sys

CURRENT_DIR = os.path.dirname(__file__)
if CURRENT_DIR not in sys.path:
    sys.path.insert(0, CURRENT_DIR)

from pom_xml import normalize_pom_xml


def parse_ai_response_content(resp_body):
    resp_json = json.loads(resp_body)
    content = resp_json["choices"][0]["message"]["content"]
    content = content.strip()
    if content.startswith("```"):
        content = "\n".join(content.split("\n")[1:])
        if content.endswith("```"):
            content = content[:-3].strip()
    return json.loads(content)


def apply_ai_file_patch(project_dir, response_payload, emit_writes=True):
    if isinstance(response_payload, str):
        data = parse_ai_response_content(response_payload)
    else:
        data = response_payload

    if "pom_xml" in data:
        pom_xml = normalize_pom_xml(data["pom_xml"])
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