import logging
from pathlib import Path

from dotenv import load_dotenv

from de_project.config import load_settings
from de_project.pipeline import run_pipeline


def main():
    load_dotenv()
    log_dir = Path(__file__).resolve().parents[1] / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
        handlers=[
            logging.StreamHandler(),
            logging.FileHandler(log_dir / "ingestion.log", encoding="utf-8"),
        ],
    )

    settings = load_settings()

    try:
        result = run_pipeline(settings)
        print("Pipeline result:", result)
    except Exception:
        logging.exception("Pipeline thất bại.")
        raise


if __name__ == "__main__":
    main()
