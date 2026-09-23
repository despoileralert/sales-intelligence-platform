from utils.loggerexc import *
import time, os
import mysql.connector
from dotenv import load_dotenv
from mysql.connector import Error

load_dotenv()

class MySqlManager:
    def __init__(self):
        # No "database" here: schema.sql creates sales_intelligence and runs
        # USE on the same connection, so the first run works on an empty server.
        self.config = {
            "host": os.getenv("DB_HOST", "127.0.0.1"),
            "port": int(os.getenv("DB_PORT", "3306")),
            "user": os.getenv("DB_USER"),
            "password": os.getenv("DB_PASSWORD"),
        }
        self.attempts = 3
        self.delay = 2
        self.logger = get_logger("mysqlLogger")


    def connect_to_mysql(self):
        # Reconnection routine with a progressive delay between attempts
        for attempt in range(1, self.attempts + 1):
            try:
                return mysql.connector.connect(**self.config, allow_local_infile=True)
            except (mysql.connector.Error, IOError) as err:
                if attempt == self.attempts:
                    self.logger.error("Failed to connect after %d attempts: %s", self.attempts, err)
                    return None
                self.logger.warning(
                    "Connection failed: %s. Retrying (%d/%d)...",
                    err,
                    attempt,
                    self.attempts - 1,
                )
                time.sleep(self.delay ** attempt)
        return None


    def execute_sql_file(
        self,
        conn,
        filepath: Path,
        logger,
        capture_results: bool = False,
        replacements: dict | None = None,
    ):
        """
        Execute a multi-statement SQL file using an open connection.

        replacements: optional {placeholder: value} map applied to the SQL text
                      before execution, e.g. {"{RAW_DATA_DIR}": "C:/data/raw"}.

        Returns a list of result-sets if capture_results=True, else True on success.
        """
        if not filepath.exists():
            raise FileNotFoundError(f"SQL file not found: {filepath}")

        sql = filepath.read_text(encoding="utf-8")
        if not sql.strip():
            self.logger.warning(f"Empty SQL file: {filepath}")
            return [] if capture_results else True

        for placeholder, value in (replacements or {}).items():
            sql = sql.replace(placeholder, value)

        self.logger.info(f"Executing: {filepath.name} ({filepath})")

        results = []
        try:
            with conn.cursor() as cursor:
                # mysql-connector-python 9.2+ runs multi-statement strings
                # natively (the old multi=True flag was removed). Walk every
                # result with nextset(): rows must be fetched to keep the
                # protocol in sync, and errors in later statements surface here.
                cursor.execute(sql)
                while True:
                    if cursor.with_rows:
                        rows = cursor.fetchall()
                        if capture_results:
                            results.append(rows)
                    # INSERT / LOAD / DDL statements return no rows and are
                    # skipped, so captured results line up with SELECTs only.
                    if not cursor.nextset():
                        break

            conn.commit()
            self.logger.info(f"Success: {filepath.name}")
            return results if capture_results else True

        except Exception as e:
            conn.rollback()
            self.logger.error(f"Failed: {filepath.name} - {e}")
            raise


    def run_validation(self, results, logger):
        """
        validate_raw_data.sql returns 6 result-sets:
            [0] row counts (informational)
            [1..5] checks that must be 0
        """
        if not results or len(results) < 2:
            self.logger.error("Validation returned incomplete results.")
            return False

        # 1. Log row counts
        self.logger.info("--- Raw table row counts ---")
        for row in results[0]:
            self.logger.info(f"  {row[0]}: {row[1]}")

        # 2. Gate on the remaining checks
        passed = True
        self.logger.info("--- Validation checks ---")
        for result_set in results[1:]:
            for row in result_set:
                check_name = row[0]
                failed_count = row[1]
                if failed_count > 0:
                    self.logger.error(f"  FAIL: {check_name} = {failed_count}")
                    passed = False
                else:
                    self.logger.info(f"  PASS: {check_name}")
        return passed


    def log_transform_summary(self, results, logger):
        """
        The last captured result-set in transform_data.sql is the row-count summary.
        """
        if not results:
            return
        summary = results[-1]
        self.logger.info("--- Post-transform table row counts ---")
        for row in summary:
            self.logger.info(f"  {row[0]}: {row[1]}")