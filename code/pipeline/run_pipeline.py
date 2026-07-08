"""
Sales Intelligence Pipeline Runner
Orchestrates the SQL files in the correct order:
  1. schema.sql
  2. load_raw_data.sql
  3. validate_raw_data.sql  (gate: abort if checks fail)
  4. transform_data.sql
"""
# relative to this file's folder (code/)
STEPS = [
    ("sql/ddl/schema.sql", "Create schema and tables", False),
    ("sql/dml/load_raw_data.sql", "Load raw CSV data", False),
    ("sql/dml/validate_raw_data.sql", "Validate raw data", True),
    ("sql/dml/transform_data.sql", "Transform to star schema", True),
]

from utils.helpers import MySqlManager
from pathlib import Path
import sys

def main():
    db = MySqlManager()
    conn = db.connect_to_mysql()
    if not conn:
        db.logger.error("Unable to connect to MySQL. Aborting.")
        sys.exit(1)

    logger = db.logger
    base_dir = Path(__file__).resolve().parent  # code/ folder

    try:
        for rel_path, description, capture in STEPS:
            filepath = base_dir / rel_path

            try:
                results = db.execute_sql_file(
                    conn, filepath, logger, capture_results=capture
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