import logging

from de_project.api import fetch_commits
from de_project.db import init_db, upsert_commits
from de_project.transform import transform_commits

logger = logging.getLogger(__name__)


def run_pipeline(settings, session=None, sleep_fn=None) -> dict:
    logger.info("===== Bắt đầu ingestion =====")

    # Goi API
    raw_records = fetch_commits(
        api_url=settings.api_url,
        per_page=settings.api_per_page,
        max_retries=settings.api_max_retries,
        timeout=settings.api_timeout,
        session=session,
        **({"sleep_fn": sleep_fn} if sleep_fn else {}),
    )

    # Transform du lieu
    clean_records = transform_commits(raw_records)
    # Tao bang trong csdl
    init_db(settings)
    # Them du lieu - Chong trung lap
    loaded = upsert_commits(settings, clean_records)
    
    result = {
        "fetched": len(raw_records),
        "valid": len(clean_records),
        "upserted": loaded,
        "skipped": len(raw_records) - len(clean_records),
    }
    logger.info("Pipeline hoàn tất: %s", result)
    return result
