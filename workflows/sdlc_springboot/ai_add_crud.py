import json
import os
import sys
import urllib.request

project_dir = sys.argv[1]
package = sys.argv[2]
prompt_file = sys.argv[3]
req_file = sys.argv[4]
resp_file = sys.argv[5]
ai_model = sys.argv[6] if len(sys.argv) > 6 else os.environ.get("CRONOVA_AI_MODEL", "gpt-4o-mini")
ai_base_url = sys.argv[7] if len(sys.argv) > 7 else os.environ.get("CRONOVA_AI_BASE_URL", "")
ai_token = sys.argv[8] if len(sys.argv) > 8 else os.environ.get("CRONOVA_AI_TOKEN", "")

with open(prompt_file, "r", encoding="utf-8") as f:
    prompt = f.read()

req = {
    "model": ai_model,
    "messages": [
        {"role": "system", "content": "You output only valid JSON with keys pom_xml, Item_java, ItemController_java."},
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
pkg_path = package.replace(".", "/")
with open(os.path.join(base, "pom.xml"), "w", encoding="utf-8") as f:
    f.write(data["pom_xml"])
with open(os.path.join(base, f"src/main/java/{pkg_path}/model/Item.java"), "w", encoding="utf-8") as f:
    f.write(data["Item_java"])
with open(os.path.join(base, f"src/main/java/{pkg_path}/api/ItemController.java"), "w", encoding="utf-8") as f:
    f.write(data["ItemController_java"])

print("Wrote pom.xml, Item.java, ItemController.java")
