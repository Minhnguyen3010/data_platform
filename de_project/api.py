import logging
import time
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime

import requests

from de_project.exceptions import APIRequestError, DataValidationError, RateLimitError

logger = logging.getLogger(__name__)


def _retry_delay(response, attempt: int) -> float:
    retry_after = response.headers.get("Retry-After")
    if retry_after:
        try:
            return max(float(retry_after), 0.0)
        except ValueError:
            try:
                retry_at = parsedate_to_datetime(retry_after)
                return max(
                    (retry_at - datetime.now(timezone.utc)).total_seconds(),
                    0.0,
                )
            except (TypeError, ValueError):
                pass

    if response.headers.get("X-RateLimit-Remaining") == "0":
        reset = response.headers.get("X-RateLimit-Reset")
        if reset:
            try:
                return max(float(reset) - time.time(), 0.0)
            except ValueError:
                pass

    return min(2 ** attempt, 60)

# Goi API 
def fetch_commits(
    api_url: str,
    per_page: int = 30,
    max_retries: int = 3,
    timeout: int = 15,
    session=None,
    sleep_fn=time.sleep,
) -> list[dict]:
    session = session or requests.Session()
    headers = {
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "python-de-ingestion-learning-project",
    }

     # Vong lap retry : max_retries = 3 + 1 = 4 
    for attempt in range(max_retries + 1):
        try:
            # Goi API
            response = session.get(
                api_url,
                params={"per_page": per_page},
                headers=headers,
                timeout=timeout,
            )

            
            rate_limited = response.status_code == 429 or (
                response.status_code == 403
                and (
                    response.headers.get("X-RateLimit-Remaining") == "0"
                    or "rate limit" in response.text.lower()
                )
            )

            if rate_limited:
                if attempt >= max_retries:
                    raise RateLimitError(
                        "GitHub API vẫn giới hạn request sau các lần retry."
                    )
                delay = _retry_delay(response, attempt)
                logger.warning(
                    "API rate limit HTTP %s; retry sau %.1f giây.",
                    response.status_code,
                    delay,
                )
                sleep_fn(delay)
                continue

            response.raise_for_status()
            payload = response.json() # Chuyen response sang json

            if not isinstance(payload, list):
                raise DataValidationError("API response phải là JSON array.")

            logger.info("Đã nhận %d commit từ API.", len(payload))
            return payload

        except (requests.Timeout, requests.ConnectionError) as exc:
            if attempt >= max_retries:
                logger.exception("API timeout/connection error sau nhiều lần thử.")
                raise APIRequestError(
                    "Không thể gọi API sau nhiều lần thử."
                ) from exc

            delay = min(2 ** attempt, 30)
            logger.warning("API timeout/mất kết nối; retry sau %.1f giây.", delay)
            sleep_fn(delay)

        except requests.HTTPError:
            logger.exception("API trả về HTTP error không thuộc nhóm retry.")
            raise

    raise APIRequestError("Không thể lấy dữ liệu từ API.")
