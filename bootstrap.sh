#!/usr/bin/env bash
set -euo pipefail

PROJECT="career-agent"

echo "=============================================="
echo " Personal Career Agent"
echo " GitHub + GitHub Actions + GitHub Pages"
echo "=============================================="

if [ -d "$PROJECT" ]; then
  echo "ERROR: $PROJECT already exists."
  exit 1
fi

mkdir -p \
  "$PROJECT/.github/workflows" \
  "$PROJECT/.github/ISSUE_TEMPLATE" \
  "$PROJECT/agent" \
  "$PROJECT/agent/prompts" \
  "$PROJECT/ai" \
  "$PROJECT/jobs" \
  "$PROJECT/interview" \
  "$PROJECT/memory" \
  "$PROJECT/data" \
  "$PROJECT/security" \
  "$PROJECT/site" \
  "$PROJECT/tests"

# ------------------------------------------------
# SECURITY
# ------------------------------------------------

cat > "$PROJECT/security/policy.yaml" <<'EOF'
security:
  local_machine_access: false
  mac_access: false
  ssh_access: false
  keychain_access: false
  browser_password_access: false

  automatic_job_application: false
  automatic_recruiter_contact: false
  automatic_external_messages: false
  automatic_spending: false

  code_self_modification:
    allowed: false

  important_preference_changes:
    require_user_confirmation: true
EOF

# ------------------------------------------------
# PROFILE
# ------------------------------------------------

cat > "$PROJECT/memory/profile.yaml" <<'EOF'
candidate:
  experience_years: 10+

target_roles:
  - Principal Software Engineer
  - Staff Software Engineer
  - Software Architect
  - Associate Director
  - Senior Engineering Manager

location:
  preferred:
    - Remote India
  relocation: false

work_style:
  remote: true
  hybrid: false

skills:
  - Full Stack
  - Software Architecture
  - Distributed Systems
  - Cloud
  - Backend Engineering
  - System Design
  - Technical Leadership
EOF

cat > "$PROJECT/memory/preferences.yaml" <<'EOF'
preferences:
  remote_india: true
  hybrid: false
  relocation: false

  minimum_experience_years: 10

  priorities:
    architecture: high
    technical_leadership: high
    full_stack: high
    distributed_systems: high
    cloud: high

  application:
    automatic: false
    confirmation_required: true
EOF

cat > "$PROJECT/memory/decisions.json" <<'EOF'
[]
EOF

cat > "$PROJECT/memory/lessons.json" <<'EOF'
[]
EOF

cat > "$PROJECT/memory/conversation.json" <<'EOF'
[]
EOF

# ------------------------------------------------
# AGENT POLICY
# ------------------------------------------------

cat > "$PROJECT/agent/config.yaml" <<'EOF'
agent:
  name: Personal Career Agent

  purpose:
    - Find relevant jobs
    - Analyze opportunities
    - Prepare interview questions
    - Learn search preferences
    - Ask for decisions when needed

  autonomy:
    search: true
    analyze: true
    rank: true
    deduplicate: true
    interview_preparation: true
    strategy_learning: true

  confirmation_required:
    important_preference_changes: true
    job_application: true
    recruiter_contact: true
    external_message: true

  forbidden:
    local_machine_access: true
    credential_access: true
    automatic_application: true
    automatic_spending: true

  llm:
    provider: openrouter
    model: openrouter/free

  limits:
    max_requests_per_run: 12
    max_requests_per_day: 40
EOF

cat > "$PROJECT/agent/prompts/system.txt" <<'EOF'
You are a personal career-search assistant.

The user has 10+ years of experience and is targeting:

- Principal Software Engineer
- Staff Software Engineer
- Software Architect
- Associate Director
- Senior Engineering Manager

The user prefers Remote India.

The user's technical focus includes:

- Full Stack
- Software Architecture
- Distributed Systems
- Cloud
- Backend Engineering
- System Design
- Technical Leadership

You are an autonomous assistant within strict boundaries.

You may:
- search permitted public job sources
- analyze job descriptions
- rank jobs
- remove duplicates
- generate interview questions
- generate model answers
- identify job-market patterns
- improve search queries
- maintain memory

You must ask before:
- changing major career preferences
- changing location strategy
- changing seniority strategy
- changing relocation preference

You must NEVER:
- access the user's Mac
- access the user's files
- access passwords
- access the macOS keychain
- access browser passwords
- automatically apply to jobs
- automatically contact recruiters
- spend money

Never claim that an action happened unless it actually happened.

Prefer concise, useful recommendations.
EOF

# ------------------------------------------------
# OPENROUTER
# ------------------------------------------------

cat > "$PROJECT/ai/openrouter.py" <<'PY'
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
PY

# ------------------------------------------------
# JOB SCORING
# ------------------------------------------------

cat > "$PROJECT/jobs/scoring.py" <<'PY'
ROLE_WEIGHTS = {
    "principal software engineer": 45,
    "staff software engineer": 43,
    "software architect": 43,
    "associate director": 40,
    "senior engineering manager": 40
}

KEYWORDS = [
    "architecture",
    "distributed systems",
    "system design",
    "cloud",
    "aws",
    "azure",
    "gcp",
    "kubernetes",
    "microservices",
    "full stack",
    "technical leadership"
]


def score(job):
    title = job.get("title", "").lower()
    description = job.get("description", "").lower()

    result = 0

    for role, weight in ROLE_WEIGHTS.items():
        if role in title:
            result += weight

    for keyword in KEYWORDS:
        if keyword in description:
            result += 3

    if "remote" in description:
        result += 7

    if "india" in description:
        result += 7

    if "relocation required" in description:
        result -= 30

    return max(0, min(100, result))
PY

# ------------------------------------------------
# JOB DATA
# ------------------------------------------------

cat > "$PROJECT/data/jobs.json" <<'EOF'
[]
EOF

# ------------------------------------------------
# DAILY AGENT
# ------------------------------------------------

cat > "$PROJECT/agent/daily.py" <<'PY'
import json
from pathlib import Path
from datetime import datetime, timezone

from ai.openrouter import ask
from jobs.scoring import score

ROOT = Path(__file__).resolve().parent.parent

JOBS = ROOT / "data/jobs.json"
REPORT = ROOT / "data/latest_report.md"
PROFILE = ROOT / "memory/profile.yaml"
PROMPT = ROOT / "agent/prompts/system.txt"


def load_jobs():
    if not JOBS.exists():
        return []

    return json.loads(JOBS.read_text())


def save_jobs(jobs):
    JOBS.write_text(
        json.dumps(jobs, indent=2, ensure_ascii=False)
    )


def main():
    jobs = load_jobs()

    for job in jobs:
        job["score"] = score(job)

    jobs.sort(
        key=lambda x: x.get("score", 0),
        reverse=True
    )

    save_jobs(jobs)

    top = jobs[:10]

    context = "\n\n".join(
        f"""
TITLE: {job.get('title')}
COMPANY: {job.get('company')}
LOCATION: {job.get('location')}
URL: {job.get('url')}
SCORE: {job.get('score')}
DESCRIPTION:
{job.get('description', '')[:5000]}
"""
        for job in top
    )

    system = PROMPT.read_text()

    question = f"""
Create today's career briefing.

Candidate profile:
{PROFILE.read_text()}

Jobs:
{context}

Provide:

1. Top jobs
2. Why they match
3. Concerns/gaps
4. Interview topics
5. Market observations
6. A question for the user if an important decision is needed

Never claim that an application was submitted.
"""

    try:
        result = ask(
            system,
            question,
            max_tokens=4500
        )

    except Exception as exc:
        result = (
            "# Agent temporarily unavailable\n\n"
            f"LLM error: {exc}\n\n"
            "The job data has still been updated."
        )

    REPORT.write_text(
        "# Daily Career Briefing\n\n"
        f"Generated: {datetime.now(timezone.utc).isoformat()}\n\n"
        + result
    )

    print(result)


if __name__ == "__main__":
    main()
PY

# ------------------------------------------------
# WEBSITE
# ------------------------------------------------

cat > "$PROJECT/site/index.html" <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Personal Career Agent</title>

<style>
:root {
  --bg:#080d18;
  --panel:#111827;
  --border:#26334d;
  --text:#f4f7fb;
  --muted:#94a3b8;
  --blue:#5b8cff;
  --green:#22c55e;
  --orange:#f59e0b;
}

* {
  box-sizing:border-box;
}

body {
  margin:0;
  background:var(--bg);
  color:var(--text);
  font-family:Inter,system-ui,-apple-system,sans-serif;
}

header {
  padding:22px 28px;
  border-bottom:1px solid var(--border);
  background:#0d1424;
}

header strong {
  font-size:20px;
}

nav {
  display:flex;
  gap:10px;
  padding:15px 28px;
  border-bottom:1px solid var(--border);
  overflow:auto;
}

nav button {
  background:#172137;
  color:white;
  border:1px solid var(--border);
  padding:9px 14px;
  border-radius:8px;
}

main {
  max-width:1200px;
  margin:auto;
  padding:28px;
}

.card {
  background:var(--panel);
  border:1px solid var(--border);
  border-radius:14px;
  padding:22px;
  margin-bottom:18px;
}

.stats {
  display:grid;
  grid-template-columns:repeat(auto-fit,minmax(180px,1fr));
  gap:15px;
}

.stat {
  background:#0d1526;
  padding:18px;
  border-radius:12px;
  border:1px solid var(--border);
}

.number {
  font-size:30px;
  font-weight:700;
}

.muted {
  color:var(--muted);
}

.job {
  padding:18px 0;
  border-bottom:1px solid var(--border);
}

.job:last-child {
  border-bottom:0;
}

.score {
  color:var(--green);
  font-weight:700;
}

a {
  color:#8fb3ff;
}

button.primary {
  background:var(--blue);
  color:white;
  border:0;
  padding:11px 17px;
  border-radius:8px;
}

pre {
  white-space:pre-wrap;
  font-family:inherit;
}
</style>
</head>

<body>

<header>
  <strong>🤖 Personal Career Agent</strong>
  <span class="muted"> — Private Career Assistant</span>
</header>

<nav>
  <button onclick="show('dashboard')">Dashboard</button>
  <button onclick="show('jobs')">Jobs</button>
  <button onclick="show('interview')">Interview</button>
  <button onclick="show('decisions')">Decisions</button>
  <button onclick="show('memory')">Memory</button>
</nav>

<main>

<section id="dashboard">

<div class="card">
<h1>Good morning 👋</h1>

<p class="muted">
Your career agent searches jobs, analyzes opportunities,
generates interview preparation and learns from your decisions.
</p>
</div>

<div class="stats">

<div class="stat">
<div class="number" id="jobCount">0</div>
<div class="muted">Jobs found</div>
</div>

<div class="stat">
<div class="number" id="strongCount">0</div>
<div class="muted">Strong matches</div>
</div>

<div class="stat">
<div class="number">10+</div>
<div class="muted">Experience target</div>
</div>

<div class="stat">
<div class="number">🇮🇳</div>
<div class="muted">Remote India</div>
</div>

</div>

<div class="card">
<h2>🧠 Today's briefing</h2>
<pre id="report">Loading...</pre>
</div>

</section>

<section id="jobs" style="display:none">

<div class="card">
<h2>💼 Recommended jobs</h2>
<div id="jobList">Loading...</div>
</div>

</section>

<section id="interview" style="display:none">

<div class="card">
<h2>📚 Interview preparation</h2>

<p>
Questions will be generated from your highest-priority jobs.
</p>

<div id="interviewContent">
Run the daily agent to generate today's preparation.
</div>

</div>

</section>

<section id="decisions" style="display:none">

<div class="card">
<h2>🤔 Decisions</h2>

<p>
When the agent needs your judgment, the decision will appear here.
</p>

<div class="muted">
No pending decisions.
</div>

</div>

</section>

<section id="memory" style="display:none">

<div class="card">
<h2>🧠 Agent memory</h2>

<p>
Current target: Principal / Staff / Architect /
Associate Director / Senior Engineering Manager
</p>

<p>
Experience: 10+ years
</p>

<p>
Location: Remote India
</p>

<p>
Automatic applications: Disabled
</p>

</div>

</section>

</main>

<script>

function show(id) {
  document.querySelectorAll("main section")
    .forEach(x => x.style.display = "none");

  document.getElementById(id).style.display = "block";
}

async function loadData() {

  try {

    const jobsResponse =
      await fetch("./data/jobs.json");

    if (jobsResponse.ok) {

      const jobs =
        await jobsResponse.json();

      document.getElementById("jobCount")
        .textContent = jobs.length;

      document.getElementById("strongCount")
        .textContent =
          jobs.filter(x => (x.score || 0) >= 70).length;

      const list =
        document.getElementById("jobList");

      if (!jobs.length) {
        list.innerHTML =
          "<p class='muted'>No jobs yet.</p>";
      } else {

        list.innerHTML =
          jobs.slice(0,20).map(job => `
            <div class="job">
              <h3>${escapeHtml(job.title || "")}</h3>

              <div class="muted">
                ${escapeHtml(job.company || "")}
                ·
                ${escapeHtml(job.location || "")}
              </div>

              <p>
                Match:
                <span class="score">
                  ${job.score || 0}%
                </span>
              </p>

              <a href="${escapeAttr(job.url || "#")}"
                 target="_blank"
                 rel="noopener">
                View job →
              </a>
            </div>
          `).join("");
      }
    }

  } catch(e) {
    console.log(e);
  }

  try {

    const reportResponse =
      await fetch("./data/latest_report.md");

    if (reportResponse.ok) {
      document.getElementById("report")
        .textContent =
          await reportResponse.text();
    }

  } catch(e) {
    document.getElementById("report")
      .textContent =
      "No report yet.";
  }
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&","&amp;")
    .replaceAll("<","&lt;")
    .replaceAll(">","&gt;")
    .replaceAll('"',"&quot;")
    .replaceAll("'","&#039;");
}

function escapeAttr(value) {
  return escapeHtml(value);
}

loadData();

</script>

</body>
</html>
EOF

# ------------------------------------------------
# PAGES WORKFLOW
# ------------------------------------------------

cat > "$PROJECT/.github/workflows/pages.yml" <<'EOF'
name: Deploy Career Agent Website

on:
  push:
    branches:
      - main
    paths:
      - "site/**"
      - "data/**"

  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: true

jobs:

  deploy:

    runs-on: ubuntu-latest

    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}

    steps:

      - name: Checkout
        uses: actions/checkout@v4

      - name: Prepare website
        run: |
          mkdir -p public
          cp -r site/* public/
          mkdir -p public/data
          cp data/jobs.json public/data/jobs.json
          cp data/latest_report.md public/data/latest_report.md 2>/dev/null || true

      - name: Configure Pages
        uses: actions/configure-pages@v5

      - name: Upload Pages artifact
        uses: actions/upload-pages-artifact@v4
        with:
          path: public

      - name: Deploy
        id: deployment
        uses: actions/deploy-pages@v4
EOF

# ------------------------------------------------
# DAILY WORKFLOW
# ------------------------------------------------

cat > "$PROJECT/.github/workflows/daily-agent.yml" <<'EOF'
name: Career Agent - Daily

on:

  workflow_dispatch:

  schedule:
    - cron: "30 2 * * *"

permissions:
  contents: write

concurrency:
  group: career-agent
  cancel-in-progress: false

jobs:

  agent:

    runs-on: ubuntu-latest

    timeout-minutes: 20

    steps:

      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Run career agent
        env:
          OPENROUTER_API_KEY: ${{ secrets.OPENROUTER_API_KEY }}
          PYTHONPATH: .
        run: |
          python career-agent/agent/daily.py

      - name: Publish updated state
        run: |
          git config user.name "career-agent"
          git config user.email "career-agent@users.noreply.github.com"

          git add data memory

          if git diff --cached --quiet; then
            echo "No state changes."
          else
            git commit -m "chore(agent): update career state"
            git push
          fi
EOF

# ------------------------------------------------
# MAINTENANCE
# ------------------------------------------------

cat > "$PROJECT/.github/workflows/maintenance.yml" <<'EOF'
name: Career Agent - Maintenance

on:
  workflow_dispatch:

  schedule:
    - cron: "0 4 * * 0"

permissions:
  contents: read

jobs:

  test:

    runs-on: ubuntu-latest

    steps:

      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Validate Python
        run: |
          python -m compileall agent ai jobs

      - name: Verify security policy
        run: |
          grep -q "mac_access: false" security/policy.yaml
          grep -q "automatic_job_application: false" security/policy.yaml

          echo "Security policy OK."
EOF

# ------------------------------------------------
# TEST
# ------------------------------------------------

cat > "$PROJECT/tests/test_scoring.py" <<'PY'
from jobs.scoring import score


def test_principal_remote():
    job = {
        "title": "Principal Software Engineer",
        "description": """
        Remote India architecture role.
        Distributed systems, cloud and full stack.
        """
    }

    assert score(job) >= 50
PY

# ------------------------------------------------
# GITHUB ISSUE TEMPLATE
# ------------------------------------------------

cat > "$PROJECT/.github/ISSUE_TEMPLATE/agent-task.md" <<'EOF'
---
name: Ask Career Agent
about: Give the career agent a task or answer a decision
title: "[Agent] "
labels: agent
---

## Request

<!-- Tell the career agent what you want -->

EOF

# ------------------------------------------------
# README
# ------------------------------------------------

cat > "$PROJECT/README.md" <<'EOF'
# Personal Career Agent

Private personal job-search assistant.

Architecture:

GitHub
→ GitHub Actions
→ OpenClaw
→ OpenRouter
→ persistent repository state
→ GitHub Pages

No Gmail.
No Cloudflare.
No Ollama.
No local Mac execution.
No automatic applications.

The GitHub Pages site is a static dashboard.

GitHub Actions performs agent work.

OpenRouter is accessed only from GitHub Actions.

The OpenRouter API key must NEVER be placed in the Pages
frontend or committed to the repository.

The agent may analyze jobs and prepare recommendations,
but job applications and recruiter communication require
human confirmation.

## Initial profile

10+ years experience.

Target:
- Principal Software Engineer
- Staff Software Engineer
- Software Architect
- Associate Director
- Senior Engineering Manager

Location:
Remote India.

## Security

The agent must never access the user's Mac,
filesystem, Keychain, browser passwords or SSH credentials.
EOF

echo
echo "=============================================="
echo "Bootstrap completed successfully"
echo "=============================================="
echo
echo "Generated:"
echo "  $PROJECT/"
echo
echo "Next:"
echo "  1. Commit the generated directory."
echo "  2. Add OPENROUTER_API_KEY to GitHub Secrets."
echo "  3. Enable GitHub Pages."
echo "  4. Run the Daily Agent workflow."
echo
