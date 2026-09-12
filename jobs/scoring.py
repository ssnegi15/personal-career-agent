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
