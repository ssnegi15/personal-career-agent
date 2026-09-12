#!/usr/bin/env bash

set -euo pipefail

echo
echo "=================================================="
echo " Personal Career Agent"
echo " Bootstrap"
echo "=================================================="
echo
echo "This script DOES NOT create GitHub workflow files."
echo "Workflows must be added separately through GitHub."
echo

# --------------------------------------------------
# ROOT DIRECTORY
# --------------------------------------------------

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$ROOT"

# --------------------------------------------------
# DIRECTORIES
# --------------------------------------------------

mkdir -p \
  agent \
  agent/prompts \
  jobs \
  data \
  memory \
  security \
  site \
  tests

# --------------------------------------------------
# SECURITY POLICY
# --------------------------------------------------

cat > security/policy.yaml <<'EOF'
security:
  execution_environment: github_actions_only

  local_machine_access: false
  mac_access: false

  filesystem_access:
    allowed:
      - repository_workspace
      - data
      - memory
    denied:
      - host_filesystem
      - user_home
      - ssh
      - keychain
      - browser_profiles

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
  self_modify_workflows: false

  external_side_effects:
    require_confirmation: true

  preference_changes:
    require_confirmation: true
EOF

# --------------------------------------------------
# CANDIDATE PROFILE
# --------------------------------------------------

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

    remote_only: true

  skills:

    - Full Stack
    - Software Architecture
    - Distributed Systems
    - Cloud
    - Backend Engineering
    - System Design
    - Technical Leadership
    - Microservices
    - API Design
    - Scalability

  career_preferences:

    seniority:
      - Principal
      - Staff
      - Architect
      - Associate Director
      - Senior Manager

    work_mode:
      - Remote

    geography:
      - India
EOF

# --------------------------------------------------
# SEARCH PREFERENCES
# --------------------------------------------------

cat > memory/preferences.yaml <<'EOF'
preferences:

  minimum_experience_years: 10

  remote_only: true

  locations:
    - Remote India

  target_roles:
    - Principal Software Engineer
    - Staff Software Engineer
    - Software Architect
    - Associate Director
    - Senior Engineering Manager

  priorities:

    architecture: high
    technical_leadership: high
    distributed_systems: high
    full_stack: high
    cloud: high
    backend: high
    system_design: high
    scalability: high

  job_search:

    duplicate_detection: true
    relevance_scoring: true
    description_analysis: true

  automatic_application: false
  recruiter_contact: false
EOF

# --------------------------------------------------
# AGENT MEMORY
# --------------------------------------------------

cat > memory/decisions.json <<'EOF'
[]
EOF

cat > memory/lessons.json <<'EOF'
[]
EOF

cat > memory/conversation.json <<'EOF'
[]
EOF

cat > memory/search_history.json <<'EOF'
[]
EOF

cat > memory/rejected_jobs.json <<'EOF'
[]
EOF

cat > memory/saved_jobs.json <<'EOF'
[]
EOF

# --------------------------------------------------
# OPENCLAW CONFIG
# --------------------------------------------------

cat > agent/openclaw.json <<'EOF'
{
  "agent": {
    "name": "Personal Career Agent"
  },

  "model": {
    "provider": "openrouter",
    "primary": "openrouter/auto"
  },

  "security": {
    "localMachineAccess": false,
    "macAccess": false,
    "hostFilesystemAccess": false,
    "sshAccess": false,
    "keychainAccess": false,
    "browserPasswordAccess": false,

    "workflowModification": false,

    "automaticApplications": false,
    "automaticRecruiterContact": false,
    "automaticExternalMessages": false,

    "externalActionsRequireConfirmation": true
  },

  "workspace": {
    "repositoryOnly": true
  },

  "career": {
    "automaticApplications": false,
    "automaticRecruiterContact": false,
    "requireConfirmationForExternalActions": true
  }
}
EOF

# --------------------------------------------------
# SYSTEM PROMPT
# --------------------------------------------------

cat > agent/prompts/system.txt <<'EOF'
You are a personal autonomous career assistant.

Your job is to help the user discover strong senior
software engineering opportunities and prepare for them.

==================================================
CANDIDATE
==================================================

Experience:
10+ years

Target roles:

- Principal Software Engineer
- Staff Software Engineer
- Software Architect
- Associate Director
- Senior Engineering Manager

Location:

Remote India

Core skills:

- Full Stack
- Software Architecture
- Distributed Systems
- Cloud
- Backend Engineering
- System Design
- Technical Leadership
- Microservices
- API Design
- Scalability

==================================================
PRIMARY RESPONSIBILITIES
==================================================

1. Find relevant public job opportunities.

2. Analyze complete job descriptions.

3. Determine whether a job is genuinely relevant.

4. Score each opportunity.

5. Remove duplicate jobs.

6. Identify suspicious or low-quality listings.

7. Explain why each job matches.

8. Identify skill gaps.

9. Identify likely interview topics.

10. Generate daily interview questions.

11. Generate strong model answers.

12. Generate follow-up questions.

13. Compare opportunities.

14. Learn from user decisions.

15. Improve future searches.

16. Ask the user when an important decision is needed.

==================================================
DECISION MAKING
==================================================

You are expected to make decisions about:

- relevance
- ranking
- duplicates
- search terminology
- job priority
- interview topics
- skill gaps
- which jobs deserve attention

Do not ask unnecessary questions.

Make reasonable decisions yourself.

Ask the user only when the decision materially affects
their career-search strategy or requires authorization.

==================================================
LEARNING
==================================================

Observe:

- jobs the user saves
- jobs the user rejects
- jobs the user considers relevant
- jobs the user considers irrelevant
- user answers to agent questions
- user corrections
- interview performance feedback

Use these signals to improve future recommendations.

Never silently change major preferences.

==================================================
REQUIRED CONFIRMATION
==================================================

Ask before:

- changing target seniority
- changing location strategy
- changing remote preference
- changing major career priorities
- applying for a job
- contacting a recruiter
- sending an external message
- performing another external side effect

==================================================
NEVER DO
==================================================

Never:

- access the user's Mac
- access the user's local filesystem
- access SSH keys
- access Keychain
- access browser passwords
- access Gmail
- access private email
- access personal accounts
- apply automatically
- contact recruiters automatically
- send external messages automatically
- spend money

Never claim that an application was submitted unless
the user explicitly performed that action.

Never claim that a recruiter was contacted unless
that action actually happened.

==================================================
EXECUTION ENVIRONMENT
==================================================

You are intended to run inside a temporary GitHub
Actions Linux environment.

Treat the repository as your only workspace.

Do not attempt to access anything outside the repository.

==================================================
OUTPUT
==================================================

Every daily run should attempt to produce:

1. Top job opportunities
2. Match score
3. Match explanation
4. Skill gaps
5. Interview topics
6. Daily interview questions
7. Model answers
8. Follow-up questions
9. Market observations
10. Decisions requiring the user
11. Suggested improvements to the search strategy

Keep the output practical and concise.

Prioritize quality over quantity.
EOF

# --------------------------------------------------
# JOB SCORING
# --------------------------------------------------

cat > jobs/scoring.py <<'EOF'
ROLE_WEIGHTS = {
    "principal software engineer": 40,
    "staff software engineer": 39,
    "software architect": 38,
    "associate director": 37,
    "senior engineering manager": 36,
    "engineering manager": 32
}

KEYWORDS = {
    "architecture": 5,
    "system design": 5,
    "distributed systems": 5,
    "scalability": 5,
    "cloud": 4,
    "aws": 4,
    "azure": 4,
    "gcp": 4,
    "kubernetes": 4,
    "microservices": 4,
    "full stack": 4,
    "technical leadership": 5,
    "platform": 3,
    "backend": 3,
    "api": 2
}


def score(job):

    title = job.get("title", "").lower()

    description = job.get(
        "description",
        ""
    ).lower()

    location = job.get(
        "location",
        ""
    ).lower()

    total = 0

    # Role match
    for role, weight in ROLE_WEIGHTS.items():

        if role in title:

            total += weight

            break

    # Skill match
    for keyword, weight in KEYWORDS.items():

        if keyword in description:

            total += weight

    # Location
    if "remote" in location:
        total += 8

    if "india" in location:
        total += 8

    if "remote" in description:
        total += 5

    if "india" in description:
        total += 5

    # Negative signals
    if "relocation required" in description:
        total -= 25

    if "onsite only" in description:
        total -= 25

    if "0-3 years" in description:
        total -= 20

    return max(
        0,
        min(100, total)
    )
EOF

cat > jobs/__init__.py <<'EOF'
EOF

# --------------------------------------------------
# JOB DATABASE
# --------------------------------------------------

cat > data/jobs.json <<'EOF'
[]
EOF

# --------------------------------------------------
# DAILY REPORT
# --------------------------------------------------

cat > data/latest_report.md <<'EOF'
# Personal Career Agent

## Status

The agent has not completed its first run yet.

Once GitHub Actions runs the agent, this file will
contain the latest career briefing.
EOF

# --------------------------------------------------
# DAILY AGENT FALLBACK
# --------------------------------------------------

cat > agent/daily.py <<'EOF'
import json
from pathlib import Path
from datetime import datetime, timezone

from jobs.scoring import score


ROOT = Path(__file__).resolve().parent.parent

JOBS_FILE = ROOT / "data" / "jobs.json"

REPORT_FILE = ROOT / "data" / "latest_report.md"


def load_jobs():

    if not JOBS_FILE.exists():
        return []

    try:

        return json.loads(
            JOBS_FILE.read_text(
                encoding="utf-8"
            )
        )

    except Exception:

        return []


def save_jobs(jobs):

    JOBS_FILE.write_text(
        json.dumps(
            jobs,
            indent=2,
            ensure_ascii=False
        ),
        encoding="utf-8"
    )


def generate_report(jobs):

    lines = []

    lines.append(
        "# Daily Career Briefing"
    )

    lines.append("")

    lines.append(
        f"Generated: "
        f"{datetime.now(timezone.utc).isoformat()}"
    )

    lines.append("")

    lines.append(
        f"Jobs available: {len(jobs)}"
    )

    lines.append("")

    if not jobs:

        lines.append(
            "No jobs have been collected yet."
        )

        lines.append("")

        lines.append(
            "The OpenClaw job-search pipeline "
            "will populate this data."
        )

    else:

        lines.append(
            "## Top Opportunities"
        )

        lines.append("")

        for index, job in enumerate(
            jobs[:20],
            start=1
        ):

            lines.append(
                f"### {index}. "
                f"{job.get('title', 'Unknown')}"
            )

            lines.append("")

            lines.append(
                f"**Company:** "
                f"{job.get('company', 'Unknown')}"
            )

            lines.append("")

            lines.append(
                f"**Location:** "
                f"{job.get('location', 'Unknown')}"
            )

            lines.append("")

            lines.append(
                f"**Match:** "
                f"{job.get('score', 0)}%"
            )

            lines.append("")

            lines.append(
                f"**Job:** "
                f"{job.get('url', '')}"
            )

            lines.append("")

    REPORT_FILE.write_text(
        "\n".join(lines),
        encoding="utf-8"
    )


def main():

    jobs = load_jobs()

    for job in jobs:

        job["score"] = score(job)

    jobs.sort(
        key=lambda item:
            item.get("score", 0),
        reverse=True
    )

    save_jobs(jobs)

    generate_report(jobs)

    print(
        REPORT_FILE.read_text(
            encoding="utf-8"
        )
    )


if __name__ == "__main__":
    main()
EOF

# --------------------------------------------------
# WEBSITE
# --------------------------------------------------

cat > site/index.html <<'EOF'
<!DOCTYPE html>

<html lang="en">

<head>

<meta charset="UTF-8">

<meta
  name="viewport"
  content="width=device-width, initial-scale=1.0"
>

<title>Personal Career Agent</title>

<style>

* {
  box-sizing: border-box;
}

body {
  margin: 0;
  background: #07111f;
  color: #edf4ff;
  font-family:
    Inter,
    system-ui,
    -apple-system,
    BlinkMacSystemFont,
    sans-serif;
}

header {
  padding: 22px;
  background: #0c1728;
  border-bottom: 1px solid #22334f;
}

header h1 {
  margin: 0;
  font-size: 23px;
}

header p {
  margin: 7px 0 0;
  color: #8ea2bc;
}

nav {
  display: flex;
  gap: 8px;
  padding: 13px 22px;
  background: #0a1423;
  border-bottom: 1px solid #22334f;
  overflow-x: auto;
}

nav button {
  border: 1px solid #2a3b59;
  background: #16253a;
  color: white;
  border-radius: 8px;
  padding: 9px 14px;
  cursor: pointer;
}

main {
  max-width: 1200px;
  margin: auto;
  padding: 25px;
}

.card {
  background: #0d1a2d;
  border: 1px solid #243653;
  border-radius: 14px;
  padding: 22px;
  margin-bottom: 18px;
}

.stats {
  display: grid;
  grid-template-columns:
    repeat(auto-fit, minmax(180px, 1fr));
  gap: 14px;
}

.stat {
  background: #101f35;
  border-radius: 12px;
  padding: 18px;
}

.number {
  font-size: 30px;
  font-weight: 700;
}

.muted {
  color: #91a4bd;
}

.job {
  border-bottom: 1px solid #263751;
  padding: 18px 0;
}

.job:last-child {
  border-bottom: 0;
}

.score {
  color: #39d17f;
  font-weight: 700;
}

a {
  color: #8fb5ff;
}

pre {
  white-space: pre-wrap;
  line-height: 1.6;
  font-family: inherit;
}

.warning {
  color: #ffc857;
}

</style>

</head>

<body>

<header>

<h1>🤖 Personal Career Agent</h1>

<p>
Principal · Staff · Architect · Associate Director ·
Senior Engineering Manager
</p>

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

Your personal career agent searches for relevant
senior engineering opportunities, analyzes them,
and prepares you for interviews.

</p>

</div>

<div class="stats">

<div class="stat">

<div
  class="number"
  id="jobCount"
>
0
</div>

<div class="muted">
Jobs
</div>

</div>

<div class="stat">

<div
  class="number"
  id="strongCount"
>
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
Years experience
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

<h2>🎯 Daily Interview Preparation</h2>

<p class="muted">

Interview questions and model answers generated
from your strongest opportunities will appear here.

</p>

</div>

</section>

<section
  id="decisions"
  style="display:none"
>

<div class="card">

<h2>🤔 Decisions</h2>

<p class="muted">

When the agent needs your input, decisions will
appear here.

</p>

</div>

</section>

<section
  id="memory"
  style="display:none"
>

<div class="card">

<h2>🧠 Agent Memory</h2>

<p>
Experience: 10+ years
</p>

<p>
Target roles:
Principal / Staff / Architect /
Associate Director / Senior Engineering Manager
</p>

<p>
Location: Remote India
</p>

<p>
Automatic applications:
<strong>Disabled</strong>
</p>

<p>
Recruiter contact:
<strong>Disabled</strong>
</p>

</div>

</section>

</main>

<script>

function show(id) {

  document
    .querySelectorAll("main section")
    .forEach(
      section =>
        section.style.display = "none"
    );

  document
    .getElementById(id)
    .style.display = "block";
}


function escapeHtml(value) {

  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}


async function loadJobs() {

  try {

    const response =
      await fetch("./data/jobs.json");

    if (!response.ok) {
      throw new Error("jobs unavailable");
    }

    const jobs =
      await response.json();

    document
      .getElementById("jobCount")
      .textContent =
        jobs.length;

    document
      .getElementById("strongCount")
      .textContent =
        jobs.filter(
          job => (job.score || 0) >= 70
        ).length;

    const list =
      document.getElementById("jobList");

    if (!jobs.length) {

      list.innerHTML =
        "<p class='muted'>" +
        "No jobs collected yet. " +
        "Run the agent." +
        "</p>";

      return;
    }

    list.innerHTML =
      jobs
        .slice(0, 30)
        .map(job => {

          const title =
            escapeHtml(
              job.title || "Unknown"
            );

          const company =
            escapeHtml(
              job.company || "Unknown"
            );

          const location =
            escapeHtml(
              job.location || "Unknown"
            );

          const score =
            job.score || 0;

          const url =
            escapeHtml(
              job.url || "#"
            );

          return `

            <div class="job">

              <h3>${title}</h3>

              <div class="muted">

                ${company}
                ·
                ${location}

              </div>

              <p>

                Match:

                <span class="score">
                  ${score}%
                </span>

              </p>

              <a
                href="${url}"
                target="_blank"
                rel="noopener noreferrer"
              >
                View job →
              </a>

            </div>

          `;

        })
        .join("");

  }

  catch (error) {

    console.error(error);

  }
}


async function loadReport() {

  try {

    const response =
      await fetch(
        "./data/latest_report.md"
      );

    if (!response.ok) {
      return;
    }

    document
      .getElementById("report")
      .textContent =
        await response.text();

  }

  catch (error) {

    console.error(error);

  }
}


loadJobs();

loadReport();

</script>

</body>

</html>
EOF

# --------------------------------------------------
# TESTS
# --------------------------------------------------

cat > tests/test_scoring.py <<'EOF'
from jobs.scoring import score


def test_principal_remote_job():

    job = {
        "title":
            "Principal Software Engineer",

        "location":
            "Remote India",

        "description":
            """
            Architecture, distributed systems,
            cloud, system design and leadership.
            """
    }

    result = score(job)

    assert result > 70


def test_relocation_penalty():

    job = {
        "title":
            "Principal Software Engineer",

        "location":
            "Bangalore",

        "description":
            """
            Relocation required.
            Architecture and distributed systems.
            """
    }

    result = score(job)

    assert result < 70
EOF

# --------------------------------------------------
# GITIGNORE
# --------------------------------------------------

cat > .gitignore <<'EOF'
__pycache__/
*.pyc
.pytest_cache/

.env
.env.*
*.key
*.pem

.DS_Store

openclaw-workspace/
EOF

# --------------------------------------------------
# README
# --------------------------------------------------

cat > README.md <<'EOF'
# Personal Career Agent

Personal autonomous career-search and interview assistant.

## Architecture

GitHub
→ GitHub Actions
→ OpenClaw
→ OpenRouter
→ GitHub repository
→ GitHub Pages

## Candidate

10+ years experience.

Target roles:

- Principal Software Engineer
- Staff Software Engineer
- Software Architect
- Associate Director
- Senior Engineering Manager

Preferred location:

Remote India

## Security

The agent is designed to execute in GitHub Actions.

It must NOT:

- access the user's Mac
- access the local filesystem
- access SSH
- access Keychain
- access browser passwords
- access Gmail
- send external messages automatically
- contact recruiters automatically
- apply automatically
- spend money
- modify GitHub workflow files

External actions require human confirmation.

## Important

This bootstrap intentionally DOES NOT create files
under `.github/workflows/`.

Workflow files should be managed separately.

## Model

OpenRouter is used as the model provider.

No local Ollama installation is required.

## Website

The `site/` directory contains the GitHub Pages
frontend.

## Data

`data/` contains generated career-agent output.

## Memory

`memory/` contains agent preferences and learning state.
EOF

# --------------------------------------------------
# VALIDATION
# --------------------------------------------------

echo
echo "Running validation..."
echo

python3 -m py_compile \
  agent/daily.py \
  jobs/scoring.py

echo
echo "Checking required files..."
echo

REQUIRED_FILES=(

  "agent/daily.py"
  "agent/openclaw.json"
  "agent/prompts/system.txt"

  "jobs/__init__.py"
  "jobs/scoring.py"

  "data/jobs.json"
  "data/latest_report.md"

  "memory/profile.yaml"
  "memory/preferences.yaml"
  "memory/decisions.json"
  "memory/lessons.json"
  "memory/conversation.json"
  "memory/search_history.json"
  "memory/rejected_jobs.json"
  "memory/saved_jobs.json"

  "security/policy.yaml"

  "site/index.html"

  "README.md"
  ".gitignore"

)

for file in "${REQUIRED_FILES[@]}"; do

  if [ ! -f "$file" ]; then

    echo "ERROR: Missing $file"

    exit 1

  fi

done

# --------------------------------------------------
# ENSURE NO WORKFLOWS WERE CREATED
# --------------------------------------------------

if [ -d ".github/workflows" ]; then

  echo
  echo "Checking workflow directory..."

  if find .github/workflows \
      -type f \
      -print \
      | grep -q .; then

    echo
    echo "WARNING:"
    echo "Existing workflow files were found."
    echo "This bootstrap did not create them."

  fi

fi

# --------------------------------------------------
# COMPLETE
# --------------------------------------------------

echo
echo "=================================================="
echo " BOOTSTRAP COMPLETE"
echo "=================================================="
echo
echo "Created:"
echo
echo "  agent/"
echo "  jobs/"
echo "  data/"
echo "  memory/"
echo "  security/"
echo "  site/"
echo "  tests/"
echo
echo "NOT created:"
echo
echo "  .github/workflows/*"
echo
echo "This prevents the GitHub App workflow-permission"
echo "error you encountered."
echo
echo "Next:"
echo
echo "  1. Commit/push these files."
echo "  2. Do NOT push workflow files with this script."
echo "  3. Ensure the two workflow files already exist"
echo "     in GitHub."
echo "  4. Add OPENROUTER_API_KEY to GitHub Secrets."
echo "  5. Run Career Agent Daily."
echo
echo "Your Mac is not part of the agent execution model."
echo
echo "=================================================="
echo
