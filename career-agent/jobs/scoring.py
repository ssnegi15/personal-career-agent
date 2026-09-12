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
