import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    api_url: str
    api_per_page: int
    api_max_retries: int
    api_timeout: int
    db_host: str
    db_port: int
    db_name: str
    db_user: str
    db_password: str


def load_settings() -> Settings:
    return Settings(
        api_url=os.getenv(
            "API_URL",
            "https://api.github.com/repos/psf/requests/commits",
        ),
        api_per_page=int(os.getenv("API_PER_PAGE", "30")),
        api_max_retries=int(os.getenv("API_MAX_RETRIES", "3")),
        api_timeout=int(os.getenv("API_TIMEOUT", "15")),
        db_host=os.getenv("POSTGRES_HOST", "localhost"),
        db_port=int(os.getenv("POSTGRES_PORT", "5432")),
        db_name=os.getenv("POSTGRES_NAME", "data_platform"),
        db_user=os.getenv("POSTGRES_USER", "data_platform"),
        db_password=os.getenv("POSTGRES_PASSWORD", ""),
    )
