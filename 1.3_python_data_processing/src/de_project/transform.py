import logging
from datetime import datetime, timezone

logger = logging.getLogger(__name__)


# Transform datetime
def parse_datetime(value: str) -> datetime:
    if not isinstance(value, str) or not value:
        raise ValueError("Ngày tháng bị thiếu hoặc không phải chuỗi.")

    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)

    return parsed.astimezone(timezone.utc)


def transform_commits(raw_records: list[dict]) -> list[dict]:
    cleaned = []

    for index, item in enumerate(raw_records):
        try:
            sha = item["sha"]
            commit = item["commit"]
            message = commit["message"]
            author = commit.get("author") or {}
            committed_at = parse_datetime(author["date"]) # Transform datetime

            if not sha or not message:
                raise ValueError("Thiếu SHA hoặc commit message.")

            cleaned.append({
                "sha": sha,
                "message": message,
                "author_name": author.get("name"),
                "author_email": author.get("email"),
                "committed_at": committed_at,
                "html_url": item.get("html_url"),
            })

        except (KeyError, TypeError, ValueError) as exc:
            logger.warning("Bỏ qua record index=%d: %s", index, exc)

    logger.info(
        "Transform: %d hợp lệ / %d nhận được.",
        len(cleaned),
        len(raw_records),
    )
    return cleaned
