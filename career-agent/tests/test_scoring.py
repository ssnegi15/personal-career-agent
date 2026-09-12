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
