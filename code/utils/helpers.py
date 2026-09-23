from utils.loggerexc import *
import time, os
import mysql.connector
from dotenv import load_dotenv
from mysql.connector import Error

load_dotenv()

class MySqlManager:
    def __init__(self):
        self.config = {
            "host": os.getenv('DB_HOST'),
            "port": os.getenv('DB_PORT'),
            "user": os.getenv('DB_USER'),
            "password": os.getenv('DB_PASSWORD'),
            "database": os.getenv('DB_SCHEMA')
        }
        self.attempts = 3
        self.delay = 2
        self.logger = get_logger("mysqlLogger")


    def connect_to_mysql(self):    
        attempt = 1
        # Implement a reconnection routine
        while attempt < self.attempts + 1:
            try:
                return mysql.connector.connect(**self.config, allow_local_infile = True)
            except (mysql.connector.Error, IOError) as err:
                if (self.attempts is attempt):
                    # Attempts to reconnect failed; returning None
                    self.logger.info("Failed to connect, exiting without a connection: %s", err)
                    return None
                self.logger.info(
                    "Connection failed: %s. Retrying (%d/%d)...",
                    err,
                    attempt,
                    self.attempts-1,
                )
                # progressive reconnect delay
                time.sleep(self.delay ** attempt)
                attempt += 1
        return None


    def execute_sql_file(self, conn, filepath: Path, logger, capture_results: bool = False):
        """
        Execute a multi-statement SQL file using an open connection.
        Returns a list of result-sets if capture_results=True, else True on success.
        """
        if not filepath.exists():
            raise FileNotFoundError(f"SQL file not found: {filepath}")

        sql = filepath.read_text(encoding="utf-8")
        if not sql.strip():
            self.logger.warning(f"Empty SQL file: {filepath}")
            return [] if capture_results else True

        self.logger.info(f"Executing: {filepath.name} ({filepath})")

        results = []
        try:
            with conn.cursor() as cursor:
                # multi=True is required for files with more than one statement.
                # We must iterate every result to clear the protocol state.
                for result in cursor.execute(sql, multi=True):
                    if result.with_rows and capture_results:
                        results.append(result.fetchall())
                    # INSERT / LOAD / DDL statements yield no rows and are
                    # consumed by the iterator but not captured.

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