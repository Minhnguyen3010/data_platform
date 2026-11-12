from datetime import timezone

from de_project.transform import transform_commits


def test_transform_converts_date_to_utc():
    raw = [{
        "sha": "abc123",
        "commit": {
            "message": "Initial commit",
            "author": {
                "name": "Minh",
                "email": "minh@example.com",
                "date": "2024-01-02T03:04:05Z",
            },
        },
        "html_url": "https://github.com/psf/requests/commit/abc123",
    }]

    result = transform_commits(raw)

    assert len(result) == 1
    assert result[0]["sha"] == "abc123"
    assert result[0]["committed_at"].tzinfo == timezone.utc


def test_transform_skips_invalid_record():
    raw = [
        {
            "sha": "good",
            "commit": {
                "message": "Good commit",
                "author": {"date": "2024-01-02T03:04:05Z"},
            },
        },
        {"sha": "bad", "commit": {"message": "Missing date"}},
    ]

    result = transform_commits(raw)
    assert len(result) == 1
    assert result[0]["sha"] == "good"
