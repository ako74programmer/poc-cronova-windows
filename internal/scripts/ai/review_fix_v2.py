import json
import os
import sys
import urllib.request
from apply_ai_file_patch import apply_ai_file_patch

project_dir = sys.argv[1]
package = sys.argv[2]
prompt_file = sys.argv[3]
req_file = sys.argv[4]
resp_file = sys.argv[5]
ai_model = sys.argv[6] if len(sys.argv) > 6 else os.environ.get("CRONOVA_AI_MODEL", "gpt-4o-mini")
ai_base_url = sys.argv[7] if len(sys.argv) > 7 else os.environ.get("CRONOVA_AI_BASE_URL", "")
ai_token = sys.argv[8] if len(sys.argv) > 8 else os.environ.get("CRONOVA_AI_TOKEN", "")


def normalize_chat_completions_url(url: str) -> str:
    normalized = (url or "").rstrip("/")
    if not normalized:
        return normalized
    if normalized.endswith("/chat/completions"):
        return normalized
    if normalized.endswith("/completions"):
        return normalized
    if normalized.endswith("/v1"):
        return normalized + "/chat/completions"
    return normalized + "/chat/completions"


ai_base_url = normalize_chat_completions_url(ai_base_url)

with open(prompt_file, "r", encoding="utf-8") as f:
    prompt = f.read()

req = {
    "model": ai_model,
    "messages": [
        {"role": "system", "content": "You output only valid JSON. Keys: pom_xml plus relative java file paths you modify."},
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
apply_ai_file_patch(project_dir, resp_body)
