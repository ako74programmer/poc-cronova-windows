import json
import os
import sys
import urllib.request
import xml.etree.ElementTree as ET


def normalize_pom_xml(pom_xml):
    if not isinstance(pom_xml, str):
        raise ValueError("AI returned pom_xml that is not a string")

    try:
        ET.fromstring(pom_xml)
        return pom_xml
    except ET.ParseError as original_error:
        # Some models double-escape formatting newlines in the JSON payload,
        # leaving literal backslash-n sequences in the decoded XML string.
        normalized = (
            pom_xml.replace(r"\r\n", "\r\n")
            .replace(r"\n", "\n")
            .replace(r"\r", "\r")
            .replace(r"\t", "\t")
        )
        if normalized == pom_xml:
            raise ValueError(f"AI returned invalid pom_xml: {original_error}") from original_error

        try:
            ET.fromstring(normalized)
        except ET.ParseError as normalized_error:
            raise ValueError(
                "AI returned invalid pom_xml after escaped-whitespace normalization: "
                f"{normalized_error} (original error: {original_error})"
            ) from normalized_error

        print(
            "Normalized literal escaped whitespace in AI-generated pom.xml after XML validation.",
            file=sys.stderr,
        )
        return normalized

project_dir = sys.argv[1]
prompt_file = sys.argv[2]
req_file = sys.argv[3]
resp_file = sys.argv[4]
ai_model = sys.argv[5] if len(sys.argv) > 5 else os.environ.get("CRONOVA_AI_MODEL", "gpt-4o-mini")
ai_base_url = sys.argv[6] if len(sys.argv) > 6 else os.environ.get("CRONOVA_AI_BASE_URL", "")
ai_token = sys.argv[7] if len(sys.argv) > 7 else os.environ.get("CRONOVA_AI_TOKEN", "")

with open(prompt_file, "r", encoding="utf-8") as f:
    prompt = f.read()

req = {
    "model": ai_model,
    "messages": [
        {"role": "system", "content": "You output only valid JSON where keys are relative file paths and values are file contents."},
        {"role": "user", "content": prompt},
    ],
    "temperature": 0.2,
}
with open(req_file, "w", encoding="utf-8") as f:
    json.dump(req, f)

with open(req_file, "rb") as f:
    data = f.read()

headers = {"Content-Type": "application/json"}
if ai_token:
    headers["Authorization"] = f"Bearer {ai_token}"

req_obj = urllib.request.Request(
    ai_base_url,
    data=data,
    headers=headers,
    method="POST",
)
with urllib.request.urlopen(req_obj) as resp:
    resp_body = resp.read().decode("utf-8")

with open(resp_file, "w", encoding="utf-8") as f:
    f.write(resp_body)

resp_json = json.loads(resp_body)
content = resp_json["choices"][0]["message"]["content"]

# Strip optional markdown code fences (```json ... ```)
content = content.strip()
if content.startswith("```"):
    content = "\n".join(content.split("\n")[1:])
    if content.endswith("```"):
        content = content[:-3].strip()

data = json.loads(content)

base = project_dir
if "pom_xml" in data:
    pom_xml = normalize_pom_xml(data["pom_xml"])
    with open(os.path.join(base, "pom.xml"), "w", encoding="utf-8") as f:
        f.write(pom_xml)
    print("Wrote pom.xml")

for key in data:
    if key == "pom_xml":
        continue
    path = os.path.join(base, key)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(data[key])
    print("Wrote", key)
