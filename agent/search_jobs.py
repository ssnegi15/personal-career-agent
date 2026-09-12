#!/usr/bin/env python3

"""
Personal Career Agent - Job Search Worker

Purpose:
    Discover publicly available jobs matching the candidate profile.

This script:
    - Uses public web pages/endpoints only.
    - Does not require personal accounts.
    - Does not apply for jobs.
    - Does not contact recruiters.
    - Does not access email.
    - Does not access the user's Mac.
    - Does not modify GitHub workflows.
    - Does not use Adzuna.

Output:
    data/jobs.json
"""

from __future__ import annotations

import hashlib
import json
import re
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import quote_plus, urljoin, urlparse

import requests
from bs4 import BeautifulSoup


ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "data"
JOBS_FILE = DATA_DIR / "jobs.json"

DATA_DIR.mkdir(parents=True, exist_ok=True)


# ---------------------------------------------------------
# Candidate search profile
# ---------------------------------------------------------

ROLE_QUERIES = [
    "Principal Software Engineer",
    "Staff Software Engineer",
    "Software Architect",
    "Principal Engineer",
    "Staff Engineer",
    "Senior Engineering Manager",
    "Engineering Manager",
    "Associate Director Engineering",
    "Director Engineering",
    "Staff Backend Engineer",
    "Staff Platform Engineer",
]

LOCATION_TERMS = [
    "India",
    "Remote India",
    "India Remote",
    "Remote",
]


# ---------------------------------------------------------
# HTTP
# ---------------------------------------------------------

SESSION = requests.Session()

SESSION.headers.update(
    {
        "User-Agent": (
            "Mozilla/5.0 (X11; Linux x86_64) "
            "AppleWebKit/537.36 "
            "(KHTML, like Gecko) "
            "Chrome/131.0 Safari/537.36 "
            "PersonalCareerAgent/1.0"
        ),
        "Accept-Language": "en-US,en;q=0.9",
    }
)


def fetch(
    url: str,
    *,
    timeout: int = 20,
) -> requests.Response | None:
    """Fetch a public URL safely."""

    try:
        response = SESSION.get(
            url,
            timeout=timeout,
            allow_redirects=True,
        )

        if response.status_code >= 400:
            print(
                f"[WARN] HTTP {response.status_code}: {url}"
            )
            return None

        return response

    except requests.RequestException as exc:
        print(f"[WARN] Request failed: {url}: {exc}")
        return None


# ---------------------------------------------------------
# Utilities
# ---------------------------------------------------------


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def clean_text(value: str | None) -> str:
    if not value:
        return ""

    return re.sub(
        r"\s+",
        " ",
        value,
    ).strip()


def normalize_url(url: str) -> str:
    """Normalize URL for deduplication."""

    if not url:
        return ""

    parsed = urlparse(url)

    if not parsed.scheme:
        return ""

    if parsed.scheme not in {"http", "https"}:
        return ""

    # Remove fragments.
    normalized = parsed._replace(
        fragment=""
    ).geturl()

    return normalized.rstrip("/")


def job_id(
    company: str,
    title: str,
    url: str,
) -> str:
    value = "|".join(
        [
            company.strip().lower(),
            title.strip().lower(),
            normalize_url(url).lower(),
        ]
    )

    return hashlib.sha256(
        value.encode("utf-8")
    ).hexdigest()[:20]


def is_probably_job_url(url: str) -> bool:
    lowered = url.lower()

    patterns = [
        "/jobs/",
        "/job/",
        "/careers/",
        "/career/",
        "greenhouse.io/",
        "lever.co/",
        "ashbyhq.com/",
    ]

    return any(
        pattern in lowered
        for pattern in patterns
    )


def is_relevant_title(title: str) -> bool:
    title_lower = title.lower()

    positive = [
        "principal engineer",
        "principal software engineer",
        "staff engineer",
        "staff software engineer",
        "software architect",
        "solution architect",
        "technical architect",
        "engineering manager",
        "senior engineering manager",
        "principal architect",
        "staff backend",
        "staff platform",
        "director engineering",
        "associate director engineering",
    ]

    negative = [
        "intern",
        "internship",
        "junior",
        "graduate",
        "trainee",
        "entry level",
        "entry-level",
        "student",
    ]

    if any(x in title_lower for x in negative):
        return False

    return any(
        x in title_lower
        for x in positive
    )


def remote_relevance(
    title: str,
    location: str,
    description: str,
) -> int:
    text = " ".join(
        [
            title,
            location,
            description,
        ]
    ).lower()

    if (
        "remote india" in text
        or "india remote" in text
    ):
        return 100

    if (
        "remote" in text
        and "india" in text
    ):
        return 95

    if "remote" in text:
        return 75

    if "india" in text:
        return 55

    return 20


def calculate_score(
    title: str,
    location: str,
    description: str,
) -> int:
    score = 0

    title_lower = title.lower()
    text = (
        title
        + " "
        + location
        + " "
        + description
    ).lower()

    # Seniority.
    if "principal" in title_lower:
        score += 30
    elif "staff" in title_lower:
        score += 30
    elif "architect" in title_lower:
        score += 25
    elif "senior engineering manager" in title_lower:
        score += 30
    elif "engineering manager" in title_lower:
        score += 22
    elif "director" in title_lower:
        score += 25

    # Technical relevance.
    technical_terms = [
        "distributed systems",
        "system design",
        "microservices",
        "architecture",
        "scalability",
        "cloud",
        "backend",
        "api",
        "platform",
        "technical leadership",
    ]

    matched = sum(
        1
        for term in technical_terms
        if term in text
    )

    score += min(
        matched * 4,
        30,
    )

    # Remote preference.
    remote_score = remote_relevance(
        title,
        location,
        description,
    )

    score += round(
        remote_score * 0.4
    )

    return min(
        score,
        100,
    )


# ---------------------------------------------------------
# Existing data
# ---------------------------------------------------------


def load_existing_jobs() -> list[dict[str, Any]]:
    if not JOBS_FILE.exists():
        return []

    try:
        with JOBS_FILE.open(
            "r",
            encoding="utf-8",
        ) as f:
            data = json.load(f)

        if isinstance(data, list):
            return data

        print(
            "[WARN] jobs.json is not a list. "
            "Starting with empty data."
        )

    except (
        json.JSONDecodeError,
        OSError,
    ) as exc:
        print(
            f"[WARN] Could not read jobs.json: {exc}"
        )

    return []


# ---------------------------------------------------------
# Job record
# ---------------------------------------------------------


def make_job(
    *,
    title: str,
    company: str,
    location: str,
    url: str,
    source: str,
    description: str,
) -> dict[str, Any] | None:

    title = clean_text(title)
    company = clean_text(company)
    location = clean_text(location)
    description = clean_text(description)
    url = normalize_url(url)

    if not title or not url:
        return None

    if not is_relevant_title(title):
        return None

    if not is_probably_job_url(url):
        return None

    return {
        "id": job_id(
            company,
            title,
            url,
        ),
        "title": title,
        "company": company or "Unknown",
        "location": location or "Unknown",
        "remote_status": (
            "remote"
            if "remote" in (
                title
                + " "
                + location
                + " "
                + description
            ).lower()
            else "unknown"
        ),
        "url": url,
        "source": source,
        "description": description[:12000],
        "discovered_at": now_iso(),
        "relevance_score": calculate_score(
            title,
            location,
            description,
        ),
    }


# ---------------------------------------------------------
# Greenhouse
# ---------------------------------------------------------


GREENHOUSE_COMPANIES = [
    # Add public Greenhouse board tokens here over time.
    #
    # Example:
    # "companyname",
]


def search_greenhouse() -> list[dict[str, Any]]:
    jobs: list[dict[str, Any]] = []

    for token in GREENHOUSE_COMPANIES:
        url = (
            "https://boards-api.greenhouse.io/v1/boards/"
            f"{quote_plus(token)}/jobs?content=true"
        )

        print(
            f"[Greenhouse] {token}"
        )

        response = fetch(url)

        if response is None:
            continue

        try:
            payload = response.json()
        except ValueError:
            continue

        for item in payload.get(
            "jobs",
            [],
        ):
            title = item.get(
                "title",
                "",
            )

            location_data = item.get(
                "location",
                {},
            )

            if isinstance(
                location_data,
                dict,
            ):
                location = location_data.get(
                    "name",
                    "",
                )
            else:
                location = str(
                    location_data
                )

            url = item.get(
                "absolute_url",
                "",
            )

            description = BeautifulSoup(
                item.get(
                    "content",
                    "",
                ),
                "html.parser",
            ).get_text(
                " ",
                strip=True,
            )

            job = make_job(
                title=title,
                company=token,
                location=location,
                url=url,
                source="greenhouse",
                description=description,
            )

            if job:
                jobs.append(job)

    return jobs


# ---------------------------------------------------------
# Lever
# ---------------------------------------------------------


LEVER_COMPANIES = [
    # Add public Lever company slugs here.
]


def search_lever() -> list[dict[str, Any]]:
    jobs: list[dict[str, Any]] = []

    for company in LEVER_COMPANIES:
        url = (
            "https://api.lever.co/v0/postings/"
            f"{quote_plus(company)}"
            "?mode=json"
        )

        print(
            f"[Lever] {company}"
        )

        response = fetch(url)

        if response is None:
            continue

        try:
            payload = response.json()
        except ValueError:
            continue

        if not isinstance(
            payload,
            list,
        ):
            continue

        for item in payload:
            title = item.get(
                "text",
                "",
            )

            categories = item.get(
                "categories",
                {},
            )

            if not isinstance(
                categories,
                dict,
            ):
                categories = {}

            location = categories.get(
                "location",
                "",
            )

            description = clean_text(
                item.get(
                    "descriptionPlain",
                    "",
                )
            )

            url = item.get(
                "hostedUrl",
                "",
            )

            job = make_job(
                title=title,
                company=company,
                location=location,
                url=url,
                source="lever",
                description=description,
            )

            if job:
                jobs.append(job)

    return jobs


# ---------------------------------------------------------
# Public company career pages
# ---------------------------------------------------------


COMPANY_CAREER_PAGES = [
    # Add public company career pages here.
    #
    # {
    #     "company": "Example",
    #     "url": "https://example.com/careers",
    # },
]


def search_company_pages() -> list[dict[str, Any]]:
    jobs: list[dict[str, Any]] = []

    for company_data in COMPANY_CAREER_PAGES:
        company = company_data["company"]
        url = company_data["url"]

        print(
            f"[Company] {company}: {url}"
        )

        response = fetch(url)

        if response is None:
            continue

        soup = BeautifulSoup(
            response.text,
            "html.parser",
        )

        for link in soup.find_all(
            "a",
            href=True,
        ):
            title = clean_text(
                link.get_text(
                    " ",
                    strip=True,
                )
            )

            if not is_relevant_title(title):
                continue

            href = normalize_url(
                urljoin(
                    response.url,
                    link["href"],
                )
            )

            if not href:
                continue

            job = make_job(
                title=title,
                company=company,
                location="",
                url=href,
                source="company-careers",
                description="",
            )

            if job:
                jobs.append(job)

    return jobs


# ---------------------------------------------------------
# Deduplication
# ---------------------------------------------------------


def merge_jobs(
    existing: list[dict[str, Any]],
    discovered: list[dict[str, Any]],
) -> list[dict[str, Any]]:

    merged: dict[str, dict[str, Any]] = {}

    for job in existing + discovered:
        if not isinstance(
            job,
            dict,
        ):
            continue

        url = normalize_url(
            str(
                job.get(
                    "url",
                    "",
                )
            )
        )

        if not url:
            continue

        key = url.lower()

        if key not in merged:
            merged[key] = job
        else:
            # Prefer the newer record if it contains
            # more description information.
            old = merged[key]

            if len(
                str(
                    job.get(
                        "description",
                        "",
                    )
                )
            ) > len(
                str(
                    old.get(
                        "description",
                        "",
                    )
                )
            ):
                merged[key] = {
                    **old,
                    **job,
                }

    jobs = list(
        merged.values()
    )

    jobs.sort(
        key=lambda x: int(
            x.get(
                "relevance_score",
                0,
            )
            or 0
        ),
        reverse=True,
    )

    return jobs


# ---------------------------------------------------------
# Save
# ---------------------------------------------------------


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


# ---------------------------------------------------------
# Main
# ---------------------------------------------------------


def main() -> None:
    print(
        "========================================"
    )
    print(
        "Personal Career Agent - Job Search"
    )
    print(
        "========================================"
    )

    existing = load_existing_jobs()

    print(
        f"Existing jobs: {len(existing)}"
    )

    discovered: list[
        dict[str, Any]
    ] = []

    # Public structured job-board APIs.
    discovered.extend(
        search_greenhouse()
    )

    time.sleep(1)

    discovered.extend(
        search_lever()
    )

    time.sleep(1)

    # Public company career pages.
    discovered.extend(
        search_company_pages()
    )

    print(
        f"New jobs discovered: "
        f"{len(discovered)}"
    )

    jobs = merge_jobs(
        existing,
        discovered,
    )

    save_jobs(jobs)

    print(
        f"Total jobs in data/jobs.json: "
        f"{len(jobs)}"
    )

    # Basic validation.
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
