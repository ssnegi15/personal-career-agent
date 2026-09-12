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
