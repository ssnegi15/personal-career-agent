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
