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
