import json
import os
import urllib.request
import urllib.error

URL = "https://openrouter.ai/api/v1/chat/completions"
MODEL = "openrouter/free"


def ask(system_prompt, user_prompt, max_tokens=1800):
    key = os.environ.get("OPENROUTER_API_KEY")

    if not key:
        raise RuntimeError("OPENROUTER_API_KEY is not configured")

    payload = {
        "model": MODEL,
        "messages": [
            {
                "role": "system",
                "content": system_prompt
            },
            {
                "role": "user",
                "content": user_prompt
            }
        ],
        "temperature": 0.2,
        "max_tokens": max_tokens
    }

    request = urllib.request.Request(
        URL,
        data=json.dumps(payload).encode(),
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "HTTP-Referer": "https://github.com",
            "X-Title": "Personal Career Agent"
        }
    )

    try:
        with urllib.request.urlopen(request, timeout=90) as response:
            data = json.loads(response.read().decode())

        return data["choices"][0]["message"]["content"]

    except urllib.error.HTTPError as exc:
        body = exc.read().decode(errors="replace")
        raise RuntimeError(
            f"OpenRouter HTTP {exc.code}: {body[:1000]}"
        )
