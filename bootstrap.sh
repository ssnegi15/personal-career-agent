#!/usr/bin/env bash
set -euo pipefail

echo "=============================================="
echo " Personal Career Agent"
echo " GitHub + Actions + Pages + OpenClaw"
echo "=============================================="

mkdir -p \
  .github/workflows \
  agent \
  agent/prompts \
  ai \
  jobs \
  interview \
  memory \
  data \
  security \
  site \
  tests

# ============================================================
# SECURITY POLICY
# ============================================================

cat > security/policy.yaml <<'EOF'
security:
  execution_environment: github_actions_only

  local_machine_access: false
  mac_access: false
  filesystem_access: false
  ssh_access: false
  keychain_access: false
  browser_password_access: false

  gmail_access: false
  email_access: false

  automatic_job_application: false
  automatic_recruiter_contact: false
  automatic_external_messages: false
  automatic_spending: false

  self_modify_code: false

  important_preference_changes:
    require_confirmation: true

  external_side_effects:
    require_confirmation: true
EOF

# ============================================================
# PROFILE
# ============================================================

cat > memory/profile.yaml <<'EOF'
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

work_style:
  remote: true
  hybrid: false
  relocation: false

skills:
  - Full Stack
  - Software Architecture
  - Distributed Systems
  - Cloud
  - Backend Engineering
  - System Design
  - Technical Leadership
EOF

cat > memory/preferences.yaml <<'EOF'
preferences:
  minimum_experience_years: 10

  locations:
    - Remote India

  remote_only: true

  priorities:
    architecture: high
    technical_leadership: high
    full_stack: high
    distributed_systems: high
    cloud: high
    system_design: high

  automatic_application: false
  recruiter_contact: false
EOF

cat > memory/decisions.json <<'EOF'
[]
EOF

cat > memory/lessons.json <<'EOF'
[]
EOF

cat > memory/conversation.json <<'EOF'
[]
EOF

# ============================================================
# OPENCLAW CONFIGURATION
# ============================================================

cat > agent/openclaw.json <<'EOF'
{
  "agent": {
    "name": "Personal Career Agent"
  },

  "model": {
    "primary": "openrouter/auto"
  },

  "security": {
    "allowLocalFilesystem": false,
    "allowMacAccess": false,
    "allowSSH": false,
    "allowBrowserPasswords": false,
    "allowKeychain": false
  },

  "career": {
    "automaticApplications": false,
    "automaticRecruiterContact": false,
    "requireConfirmationForExternalActions": true
  }
}
EOF

cat > agent/prompts/system.txt <<'EOF'
You are a personal career-search and interview-preparation assistant.

Candidate:
- 10+ years experience
- Principal Software Engineer
- Staff Software Engineer
- Software Architect
- Associate Director
- Senior Engineering Manager
- Remote India

Core skills:
- Full Stack
- Architecture
- Distributed Systems
- Cloud
- Backend
- System Design
- Technical Leadership

Responsibilities:
1. Find relevant public job opportunities.
2. Analyze complete job descriptions.
3. Score relevance.
4. Remove duplicate jobs.
5. Explain why each job matches.
6. Identify gaps and risks.
7. Generate interview questions.
8. Generate model answers.
9. Learn from user decisions.
10. Improve search strategy.
11. Ask the user when an important decision is required.

You may automatically:
- search public job sources
- analyze jobs
- rank jobs
- deduplicate
- generate interview preparation
- improve search queries
- maintain career memory

You MUST ask before:
- changing major career preferences
- changing target seniority
- changing location strategy
- changing remote/hybrid preference
- taking an external action

You MUST NEVER:
- access the user's Mac
- access local files
- access SSH keys
- access Keychain
- access browser passwords
- access Gmail
- automatically apply for jobs
- automatically contact recruiters
- send external messages
- spend money

Applications are always human-approved.

Be proactive, but stay inside these boundaries.
EOF

# ============================================================
# JOB SCORING
# ============================================================

cat > jobs/scoring.py <<'EOF'
ROLE_WEIGHTS = {
    "principal software engineer": 40,
    "staff software engineer": 38,
    "software architect": 38,
    "associate director": 36,
    "senior engineering manager": 36
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
    "technical leadership",
    "platform",
    "scalability"
]


def score(job):
    title = job.get("title", "").lower()
    description = job.get("description", "").lower()

    points = 0

    for role, weight in ROLE_WEIGHTS.items():
        if role in title:
            points += weight
            break

    for keyword in KEYWORDS:
        if keyword in description:
            points += 3

    if "remote" in description:
        points += 8

    if "india" in description:
        points += 8

    if "relocation required" in description:
        points -= 30

    return max(0, min(100, points))
EOF

cat > jobs/__init__.py <<'EOF'
EOF

# ============================================================
# JOB DATA
# ============================================================

cat > data/jobs.json <<'EOF'
[]
EOF

cat > data/latest_report.md <<'EOF'
# Career Agent

The agent has not run yet.

Go to:

GitHub → Actions → Career Agent Daily → Run workflow
EOF

# ============================================================
# DAILY AGENT
# ============================================================

cat > agent/daily.py <<'EOF'
import json
from pathlib import Path
from datetime import datetime, timezone

from jobs.scoring import score

ROOT = Path(__file__).resolve().parent.parent

JOBS = ROOT / "data" / "jobs.json"
REPORT = ROOT / "data" / "latest_report.md"


def load_jobs():
    return json.loads(JOBS.read_text())


def save_jobs(jobs):
    JOBS.write_text(
        json.dumps(
            jobs,
            indent=2,
            ensure_ascii=False
        )
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

    report = f"""# Daily Career Briefing

Generated:
{datetime.now(timezone.utc).isoformat()}

## Jobs

Found: {len(jobs)}

"""

    for job in jobs[:20]:

        report += f"""
### {job.get("title", "Unknown")}

**Company:** {job.get("company", "Unknown")}

**Location:** {job.get("location", "Unknown")}

**Match:** {job.get("score", 0)}%

**Link:** {job.get("url", "#")}

{job.get("description", "")[:1500]}

---
"""

    REPORT.write_text(report)

    print(report)


if __name__ == "__main__":
    main()
EOF

# ============================================================
# WEBSITE
# ============================================================

cat > site/index.html <<'EOF'
<!DOCTYPE html>

<html lang="en">

<head>

<meta charset="UTF-8">

<meta
  name="viewport"
  content="width=device-width,initial-scale=1"
>

<title>Personal Career Agent</title>

<style>

* {
  box-sizing: border-box;
}

body {
  margin: 0;
  background: #07111f;
  color: #eef4ff;
  font-family:
    Inter,
    system-ui,
    -apple-system,
    sans-serif;
}

header {
  padding: 22px;
  background: #0c1728;
  border-bottom: 1px solid #22334f;
}

header h1 {
  margin: 0;
  font-size: 22px;
}

nav {
  display: flex;
  gap: 8px;
  padding: 14px 22px;
  overflow-x: auto;
  background: #0a1423;
  border-bottom: 1px solid #22334f;
}

nav button {
  padding: 9px 14px;
  background: #17253b;
  border: 1px solid #2a3b59;
  border-radius: 8px;
  color: white;
  cursor: pointer;
}

main {
  max-width: 1200px;
  margin: auto;
  padding: 24px;
}

.card {
  background: #0e1a2d;
  border: 1px solid #253652;
  border-radius: 14px;
  padding: 22px;
  margin-bottom: 18px;
}

.stats {
  display: grid;
  grid-template-columns:
    repeat(auto-fit,minmax(180px,1fr));
  gap: 14px;
}

.stat {
  background: #101f35;
  padding: 18px;
  border-radius: 12px;
}

.number {
  font-size: 30px;
  font-weight: 700;
}

.muted {
  color: #91a4bd;
}

.job {
  padding: 18px 0;
  border-bottom: 1px solid #263751;
}

.job:last-child {
  border-bottom: 0;
}

.score {
  color: #36d17c;
  font-weight: 700;
}

a {
  color: #8fb5ff;
}

pre {
  white-space: pre-wrap;
  font-family: inherit;
  line-height: 1.6;
}

</style>

</head>

<body>

<header>
  <h1>🤖 Personal Career Agent</h1>
</header>

<nav>
  <button onclick="show('dashboard')">
    Dashboard
  </button>

  <button onclick="show('jobs')">
    Jobs
  </button>

  <button onclick="show('interview')">
    Interview
  </button>

  <button onclick="show('decisions')">
    Decisions
  </button>

  <button onclick="show('memory')">
    Memory
  </button>
</nav>

<main>

<section id="dashboard">

<div class="card">

<h2>Good morning 👋</h2>

<p class="muted">
Your personal career agent searches,
analyzes and prepares you for relevant
senior engineering opportunities.
</p>

</div>

<div class="stats">

<div class="stat">

<div class="number" id="jobCount">
0
</div>

<div class="muted">
Jobs found
</div>

</div>

<div class="stat">

<div class="number" id="strongCount">
0
</div>

<div class="muted">
Strong matches
</div>

</div>

<div class="stat">

<div class="number">
10+
</div>

<div class="muted">
Experience
</div>

</div>

<div class="stat">

<div class="number">
🇮🇳
</div>

<div class="muted">
Remote India
</div>

</div>

</div>

<div class="card">

<h2>🧠 Latest briefing</h2>

<pre id="report">
Loading...
</pre>

</div>

</section>

<section
  id="jobs"
  style="display:none"
>

<div class="card">

<h2>💼 Recommended jobs</h2>

<div id="jobList">
Loading...
</div>

</div>

</section>

<section
  id="interview"
  style="display:none"
>

<div class="card">

<h2>📚 Interview preparation</h2>

<p>
Daily interview questions will be generated
from the strongest matching jobs.
</p>

</div>

</section>

<section
  id="decisions"
  style="display:none"
>

<div class="card">

<h2>🤔 Agent decisions</h2>

<p>
Important decisions requiring your input
will appear here.
</p>

</div>

</section>

<section
  id="memory"
  style="display:none"
>

<div class="card">

<h2>🧠 Agent memory</h2>

<p>
Experience: 10+ years
</p>

<p>
Target: Principal / Staff / Architect /
Associate Director / Senior Engineering Manager
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

  document
    .querySelectorAll("main section")
    .forEach(
      x => x.style.display = "none"
    );

  document
    .getElementById(id)
    .style.display = "block";
}


async function load() {

  try {

    const response =
      await fetch("./data/jobs.json");

    if (!response.ok) {
      return;
    }

    const jobs =
      await response.json();

    document
      .getElementById("jobCount")
      .textContent = jobs.length;

    document
      .getElementById("strongCount")
      .textContent =
        jobs.filter(
          x => (x.score || 0) >= 70
        ).length;

    const list =
      document.getElementById("jobList");

    if (!jobs.length) {

      list.innerHTML =
        "<p class='muted'>" +
        "No jobs yet. Run the agent." +
        "</p>";

      return;
    }

    list.innerHTML =
      jobs.slice(0, 30).map(job => `

        <div class="job">

          <h3>
            ${escapeHtml(job.title || "")}
          </h3>

          <div class="muted">

            ${escapeHtml(
              job.company || ""
            )}

            ·

            ${escapeHtml(
              job.location || ""
            )}

          </div>

          <p>
            Match:
            <span class="score">
              ${job.score || 0}%
            </span>
          </p>

          <a
            href="${escapeAttr(
              job.url || "#"
            )}"
            target="_blank"
            rel="noopener"
          >
            View job →
          </a>

        </div>

      `).join("");

  } catch (error) {

    console.error(error);

  }

  try {

    const response =
      await fetch(
        "./data/latest_report.md"
      );

    if (response.ok) {

      document
        .getElementById("report")
        .textContent =
          await response.text();

    }

  } catch (error) {

    console.error(error);

  }

}


function escapeHtml(value) {

  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");

}


function escapeAttr(value) {

  return escapeHtml(value);

}


load();

</script>

</body>

</html>
EOF

# ============================================================
# PAGES WORKFLOW
# ============================================================

cat > .github/workflows/pages.yml <<'EOF'
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
          rm -rf public
          mkdir -p public/data

          cp -r site/* public/

          cp data/jobs.json public/data/

          cp data/latest_report.md \
            public/data/latest_report.md

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

# ============================================================
# DAILY AGENT WORKFLOW
# ============================================================

cat > .github/workflows/daily-agent.yml <<'EOF'
name: Career Agent Daily

on:

  workflow_dispatch:

  schedule:

    # 08:00 IST = 02:30 UTC
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

      - name: Run agent
        run: |
          PYTHONPATH=. python agent/daily.py

      - name: Commit state
        run: |

          git config user.name \
            "personal-career-agent"

          git config user.email \
            "41898282+github-actions[bot]@users.noreply.github.com"

          git add data memory

          if git diff --cached --quiet; then

            echo "No state changes."

          else

            git commit \
              -m "chore(agent): daily career update"

            git push

          fi
EOF

# ============================================================
# SECURITY TEST
# ============================================================

cat > .github/workflows/security-check.yml <<'EOF'
name: Security Check

on:
  push:
    branches:
      - main

  workflow_dispatch:

permissions:
  contents: read

jobs:

  security:

    runs-on: ubuntu-latest

    steps:

      - uses: actions/checkout@v4

      - name: Verify security policy
        run: |

          grep -q \
            "mac_access: false" \
            security/policy.yaml

          grep -q \
            "automatic_job_application: false" \
            security/policy.yaml

          grep -q \
            "gmail_access: false" \
            security/policy.yaml

          echo "Security policy passed."

      - name: Python syntax
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - run: |
          python -m compileall \
            agent jobs
EOF

# ============================================================
# README
# ============================================================

cat > README.md <<'EOF'
# Personal Career Agent

Private autonomous career assistant.

Architecture:

GitHub
→ GitHub Actions
→ OpenClaw
→ OpenRouter
→ GitHub Pages

The user's Mac is NOT an execution environment.

Security:

- No Mac access
- No local filesystem
- No SSH
- No Keychain
- No browser passwords
- No Gmail
- No automatic applications
- No automatic recruiter contact
- No automatic external messages
- No automatic spending

Applications always require human confirmation.

Target:

- Principal Software Engineer
- Staff Software Engineer
- Software Architect
- Associate Director
- Senior Engineering Manager

Experience:

10+ years

Location:

Remote India
EOF

echo
echo "=============================================="
echo "PROJECT CREATED"
echo "=============================================="
echo
echo "Next:"
echo "1. Commit files"
echo "2. Enable GitHub Pages"
echo "3. Add OpenRouter secret"
echo "4. Run Career Agent Daily"
echo
