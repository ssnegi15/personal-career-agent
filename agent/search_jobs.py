#!/usr/bin/env python3

"""
Personal Career Agent - Job Search Worker

Discovers public remote jobs and writes them to:

    data/jobs.json

Current source:
    Remote OK public JSON feed

No:
    - Adzuna
    - login
    - API key
    - applications
    - recruiter contact
    - email
    - private accounts
"""

from __future__ import annotations

import hashlib
import json
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import requests


# =========================================================
# PATHS
# =========================================================

ROOT = Path(__file__).resolve().parents[1]

DATA_DIR = ROOT / "data"
JOBS_FILE = DATA_DIR / "jobs.json"

DATA_DIR.mkdir(parents=True, exist_ok=True)


# =========================================================
# SEARCH CONFIGURATION
# =========================================================

REMOTE_OK_URL = "https://remoteok.com/api"

MAX_JOBS = 250


TARGET_ROLES = [
    "principal software engineer",
    "staff software engineer",
    "principal engineer",
    "staff engineer",
    "software architect",
    "technical architect",
    "solution architect",
    "principal architect",
    "senior engineering manager",
    "engineering manager",
    "associate director engineering",
    "director engineering",
    "staff backend engineer",
    "staff platform engineer",
]


TECHNICAL_TERMS = [
    "software architecture",
    "architecture",
    "distributed systems",
    "system design",
    "microservices",
    "scalability",
    "cloud",
    "backend",
    "api",
    "platform",
    "technical leadership",
    "engineering leadership",
]


NEGATIVE_TERMS = [
    "intern",
    "internship",
    "junior",
    "entry level",
    "entry-level",
    "graduate",
    "trainee",
    "student",
]


# =========================================================
# HTTP
# =========================================================

SESSION = requests.Session()

SESSION.headers.update(
    {
        "User-Agent": (
            "PersonalCareerAgent/1.0 "
            "(automated personal job search)"
        ),
        "Accept": "application/json",
    }
)


# =========================================================
# HELPERS
# =========================================================


def now_iso() -> str:
    return datetime.now(
        timezone.utc
    ).isoformat()


def clean_text(value: Any) -> str:
    if value is None:
        return ""

    value = str(value)

    return re.sub(
        r"\s+",
        " ",
        value,
    ).strip()


def normalize_url(url: str) -> str:
    url = clean_text(url)

    if not url:
        return ""

    # Remove trailing slash.
    url = url.rstrip("/")

    return url


def make_id(
    company: str,
    title: str,
    url: str,
) -> str:

    raw = "|".join(
        [
            company.lower().strip(),
            title.lower().strip(),
            url.lower().strip(),
        ]
    )

    return hashlib.sha256(
        raw.encode("utf-8")
    ).hexdigest()[:20]


# =========================================================
# RELEVANCE
# =========================================================


def is_target_role(
    title: str,
) -> bool:

    title = title.lower()

    for negative in NEGATIVE_TERMS:
        if negative in title:
            return False

    return any(
        role in title
        for role in TARGET_ROLES
    )


def calculate_score(
    title: str,
    location: str,
    description: str,
) -> int:

    title_lower = title.lower()

    text = " ".join(
        [
            title,
            location,
            description,
        ]
    ).lower()

    score = 0

    # -----------------------------------------------------
    # Seniority
    # -----------------------------------------------------

    if "principal" in title_lower:
        score += 30

    elif "staff" in title_lower:
        score += 30

    elif "architect" in title_lower:
        score += 28

    elif "senior engineering manager" in title_lower:
        score += 30

    elif "engineering manager" in title_lower:
        score += 23

    elif "associate director" in title_lower:
        score += 28

    elif "director" in title_lower:
        score += 25

    # -----------------------------------------------------
    # Technical relevance
    # -----------------------------------------------------

    matches = 0

    for term in TECHNICAL_TERMS:
        if term in text:
            matches += 1

    score += min(
        matches * 4,
        28,
    )

    # -----------------------------------------------------
    # Remote / India
    # -----------------------------------------------------

    if (
        "india" in text
        and "remote" in text
    ):
        score += 35

    elif "remote" in text:
        score += 25

    elif "india" in text:
        score += 15

    return min(
        score,
        100,
    )


# =========================================================
# EXISTING JOBS
# =========================================================


def load_existing_jobs() -> list[dict[str, Any]]:

    if not JOBS_FILE.exists():
        return []

    try:

        with JOBS_FILE.open(
            "r",
            encoding="utf-8",
        ) as f:

            data = json.load(f)

        if isinstance(
            data,
            list,
        ):
            return data

    except Exception as exc:

        print(
            f"[WARN] Could not read jobs.json: {exc}"
        )

    return []


# =========================================================
# REMOTE OK
# =========================================================


def fetch_remote_ok() -> list[dict[str, Any]]:

    print(
        "[Remote OK] Fetching public job feed..."
    )

    try:

        response = SESSION.get(
            REMOTE_OK_URL,
            timeout=30,
        )

        response.raise_for_status()

        data = response.json()

    except Exception as exc:

        print(
            f"[ERROR] Remote OK request failed: {exc}"
        )

        return []

    if not isinstance(
        data,
        list,
    ):

        print(
            "[ERROR] Unexpected Remote OK response."
        )

        return []

    jobs: list[
        dict[str, Any]
    ] = []

    for item in data:

        if not isinstance(
            item,
            dict,
        ):
            continue

        # Remote OK includes metadata objects.
        if not item.get("position"):
            continue

        title = clean_text(
            item.get(
                "position"
            )
        )

        company = clean_text(
            item.get(
                "company"
            )
        )

        location = clean_text(
            item.get(
                "location"
            )
        )

        description = clean_text(
            item.get(
                "description"
            )
        )

        url = clean_text(
            item.get(
                "url"
            )
        )

        if not url:
            continue

        # -------------------------------------------------
        # Target senior roles only.
        # -------------------------------------------------

        if not is_target_role(
            title
        ):
            continue

        # -------------------------------------------------
        # Remote requirement.
        # -------------------------------------------------

        combined = " ".join(
            [
                title,
                location,
                description,
            ]
        ).lower()

        if "remote" not in combined:
            continue

        score = calculate_score(
            title,
            location,
            description,
        )

        jobs.append(
            {
                "id": make_id(
                    company,
                    title,
                    url,
                ),
                "title": title,
                "company": company or "Unknown",
                "location": location or "Remote",
                "remote_status": "remote",
                "url": normalize_url(url),
                "source": "remoteok",
                "description": description[
                    :15000
                ],
                "discovered_at": now_iso(),
                "relevance_score": score,
            }
        )

    return jobs


# =========================================================
# DEDUPLICATION
# =========================================================


def merge_jobs(
    existing: list[dict[str, Any]],
    discovered: list[dict[str, Any]],
) -> list[dict[str, Any]]:

    by_url: dict[
        str,
        dict[str, Any],
    ] = {}

    # Existing jobs first.
    for job in existing:

        if not isinstance(
            job,
            dict,
        ):
            continue

        url = normalize_url(
            job.get(
                "url",
                "",
            )
        )

        if not url:
            continue

        by_url[
            url.lower()
        ] = job

    # New jobs overwrite/update existing
    # records with the same URL.
    for job in discovered:

        url = normalize_url(
            job.get(
                "url",
                "",
            )
        )

        if not url:
            continue

        key = url.lower()

        if key in by_url:

            old = by_url[key]

            merged = {
                **old,
                **job,
            }

            by_url[key] = merged

        else:

            by_url[key] = job

    jobs = list(
        by_url.values()
    )

    # Highest relevance first.
    jobs.sort(
        key=lambda job: int(
            job.get(
                "relevance_score",
                0,
            )
            or 0
        ),
        reverse=True,
    )

    return jobs[:MAX_JOBS]


# =========================================================
# SAVE
# =========================================================


def save_jobs(
    jobs: list[dict[str, Any]],
) -> None:

    with JOBS_FILE.open(
        "w",
        encoding="utf-8",
    ) as f:

        json.dump(
            jobs,
            f,
            indent=2,
            ensure_ascii=False,
        )

        f.write("\n")


# =========================================================
# MAIN
# =========================================================


def main() -> None:

    print(
        "=========================================="
    )

    print(
        "Personal Career Agent - Job Search"
    )

    print(
        "=========================================="
    )

    existing = load_existing_jobs()

    print(
        f"Existing jobs: {len(existing)}"
    )

    discovered = fetch_remote_ok()

    print(
        f"Relevant jobs discovered: "
        f"{len(discovered)}"
    )

    jobs = merge_jobs(
        existing,
        discovered,
    )

    save_jobs(
        jobs
    )

    print(
        f"Total jobs in jobs.json: "
        f"{len(jobs)}"
    )

    # -----------------------------------------------------
    # Validate JSON after writing.
    # -----------------------------------------------------

    with JOBS_FILE.open(
        "r",
        encoding="utf-8",
    ) as f:

        json.load(f)

    print(
        "data/jobs.json validated successfully."
    )


if __name__ == "__main__":
    main()
