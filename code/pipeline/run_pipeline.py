"""
Sales Intelligence Pipeline Runner
Orchestrates the SQL files in the correct order:
  1. schema.sql
  2. load_raw_data.sql
  3. validate_raw_data.sql  (gate: abort if checks fail)
  4. transform_data.sql

Run from the project root:
    python code/pipeline/run_pipeline.py
"""
from pathlib import Path
import os
import sys

# code/pipeline/run_pipeline.py -> parents[1] = code/, parents[2] = project root
CODE_DIR = Path(__file__).resolve().parents[1]
PROJECT_ROOT = CODE_DIR.parent

# Make `utils` importable no matter where the script is launched from
if str(CODE_DIR) not in sys.path:
    sys.path.insert(0, str(CODE_DIR))

from utils.helpers import MySqlManager

# Paths relative to code/
STEPS = [
    ("sql/ddl/schema.sql", "Create schema and tables", False),
    ("sql/dml/load_raw_data.sql", "Load raw CSV data", False),
    ("sql/dml/validate_raw_data.sql", "Validate raw data", True),
    ("sql/dml/transform_data.sql", "Transform to star schema", True),
]

RAW_FILES = [
    "olist_customers_dataset.csv",
    "olist_geolocation_dataset.csv",
    "olist_orders_dataset.csv",
    "olist_order_items_dataset.csv",
    "olist_order_payments_dataset.csv",
    "olist_order_reviews_dataset.csv",
    "olist_products_dataset.csv",
    "olist_sellers_dataset.csv",
    "product_category_name_translation.csv",
]


def resolve_raw_data_dir() -> Path:
    """RAW_DATA_DIR from .env if set, otherwise <project root>/data/raw."""
    raw_dir = os.getenv("RAW_DATA_DIR")
    path = Path(raw_dir) if raw_dir else PROJECT_ROOT / "data" / "raw"
    if not path.is_absolute():
        path = PROJECT_ROOT / path
    return path.resolve()


def main():
    db = MySqlManager()  # also loads .env
    logger = db.logger

    raw_dir = resolve_raw_data_dir()
    missing = [f for f in RAW_FILES if not (raw_dir / f).exists()]
    if missing:
        logger.error(f"Missing CSV files in {raw_dir}: {', '.join(missing)}")
        sys.exit(1)

    # MySQL expects forward slashes in LOAD DATA paths, including on Windows
    replacements = {"{RAW_DATA_DIR}": raw_dir.as_posix()}

    conn = db.connect_to_mysql()
    if not conn:
        logger.error("Unable to connect to MySQL. Aborting.")
        sys.exit(1)

    try:
        for rel_path, description, capture in STEPS:
            filepath = CODE_DIR / rel_path

            try:
                results = db.execute_sql_file(
                    conn,
                    filepath,
                    logger,
                    capture_results=capture,
                    replacements=replacements,
                )
            except Exception:
                logger.critical(f"Pipeline aborted at step: {description}")
                sys.exit(1)

            # Validation gate — stop the pipeline if raw data checks fail
            if "validate" in rel_path.lower():
                if not db.run_validation(results, logger):
                    logger.critical("Validation failed. Aborting pipeline.")
                    sys.exit(1)

            # Log the star-schema row counts from the final SELECT
            if "transform" in rel_path.lower():
                db.log_transform_summary(results, logger)

        logger.info("=" * 50)
        logger.info("Pipeline completed successfully.")

    finally:
        if conn.is_connected():
            conn.close()


if __name__ == "__main__":
    main()
