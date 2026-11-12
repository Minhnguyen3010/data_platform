import logging
import psycopg

logger = logging.getLogger(__name__)

CREATE_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS github_commits (
    sha           TEXT PRIMARY KEY,
    message       TEXT NOT NULL,
    author_name   TEXT,
    author_email  TEXT,
    committed_at  TIMESTAMPTZ NOT NULL,
    html_url      TEXT,
    ingested_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
"""

UPSERT_SQL = """
INSERT INTO github_commits (
    sha, message, author_name, author_email, committed_at, html_url
)
VALUES (%s, %s, %s, %s, %s, %s)
ON CONFLICT (sha) DO UPDATE SET
    message = EXCLUDED.message,
    author_name = EXCLUDED.author_name,
    author_email = EXCLUDED.author_email,
    committed_at = EXCLUDED.committed_at,
    html_url = EXCLUDED.html_url;
"""

# Connect voi csdl
def get_connection(settings):
    return psycopg.connect(
        host=settings.db_host,
        port=settings.db_port,
        dbname=settings.db_name,
        user=settings.db_user,
        password=settings.db_password,
    )


def init_db(settings):
    with get_connection(settings) as conn:
        with conn.cursor() as cur:
            cur.execute(CREATE_TABLE_SQL)
    logger.info("Đã kiểm tra/tạo bảng github_commits.")


def upsert_commits(settings, records: list[dict]) -> int:
    if not records:
        logger.warning("Không có dữ liệu hợp lệ để ghi.")
        return 0

    values = [
        (
            row["sha"],
            row["message"],
            row["author_name"],
            row["author_email"],
            row["committed_at"],
            row["html_url"],
        )
        for row in records
    ]

    # psycopg connection context: commit khi thành công, rollback khi exception.
    with get_connection(settings) as conn:
        with conn.cursor() as cur:
            cur.executemany(UPSERT_SQL, values)

    logger.info("Đã upsert %d commit.", len(values))
    return len(values)
