import json
import os
import sys
import urllib.request

project_dir = sys.argv[1]
package = sys.argv[2]
prompt_file = sys.argv[3]
req_file = sys.argv[4]
resp_file = sys.argv[5]

with open(prompt_file, "r", encoding="utf-8") as f:
    prompt = f.read()

req = {
    "model": "gpt-4o-mini",
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

req_obj = urllib.request.Request(
    "http://127.0.0.1:4141/v1/chat/completions",
    data=data,
    headers={
        "Content-Type": "application/json",
        "Authorization": "Bearer sk-local-proxy-token",
    },
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
    with open(os.path.join(base, "pom.xml"), "w", encoding="utf-8") as f:
        f.write(data["pom_xml"])
for key in data:
    if key == "pom_xml":
        continue
    path = os.path.join(base, key)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(data[key])
    print("Wrote", key)
