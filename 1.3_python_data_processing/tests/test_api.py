import requests
import pytest

from de_project.api import fetch_commits
from de_project.exceptions import APIRequestError, RateLimitError


class FakeResponse:
    def __init__(self, status_code=200, payload=None, headers=None, text=""):
        self.status_code = status_code
        self._payload = payload if payload is not None else []
        self.headers = headers or {}
        self.text = text

    def raise_for_status(self):
        if self.status_code >= 400:
            error = requests.HTTPError(f"HTTP {self.status_code}")
            error.response = self
            raise error

    def json(self):
        return self._payload


class FakeSession:
    def __init__(self, responses=None, exceptions=None):
        self.responses = list(responses or [])
        self.exceptions = list(exceptions or [])

    def get(self, *args, **kwargs):
        if self.exceptions:
            raise self.exceptions.pop(0)
        return self.responses.pop(0)


def test_api_success():
    session = FakeSession(responses=[FakeResponse(payload=[{"sha": "abc"}])])
    result = fetch_commits(
        "https://example.com",
        session=session,
        sleep_fn=lambda _: None,
    )
    assert result == [{"sha": "abc"}]


def test_api_retries_429():
    session = FakeSession(responses=[
        FakeResponse(429, headers={"Retry-After": "0"}),
        FakeResponse(payload=[{"sha": "abc"}]),
    ])
    waits = []
    result = fetch_commits(
        "https://example.com",
        max_retries=1,
        session=session,
        sleep_fn=waits.append,
    )
    assert result == [{"sha": "abc"}]
    assert waits == [0.0]


def test_api_retries_timeout():
    session = FakeSession(
        responses=[FakeResponse(payload=[{"sha": "abc"}])],
        exceptions=[requests.Timeout("timeout")],
    )
    waits = []
    result = fetch_commits(
        "https://example.com",
        max_retries=1,
        session=session,
        sleep_fn=waits.append,
    )
    assert result == [{"sha": "abc"}]
    assert waits == [1]


def test_api_timeout_exhausted_raises_exception():
    session = FakeSession(exceptions=[
        requests.Timeout("first"),
        requests.Timeout("second"),
    ])
    with pytest.raises(APIRequestError):
        fetch_commits(
            "https://example.com",
            max_retries=1,
            session=session,
            sleep_fn=lambda _: None,
        )


def test_api_rate_limit_exhausted_raises_exception():
    session = FakeSession(responses=[
        FakeResponse(429, headers={"Retry-After": "0"}),
        FakeResponse(429, headers={"Retry-After": "0"}),
    ])
    with pytest.raises(RateLimitError):
        fetch_commits(
            "https://example.com",
            max_retries=1,
            session=session,
            sleep_fn=lambda _: None,
        )
