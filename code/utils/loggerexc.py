import logging
from pathlib import Path


"""
Logger function
"""

def get_logger(name: str) -> logging.Logger:
    logger = logging.getLogger(name)

    if logger.handlers:
        return logger

    logger.setLevel(logging.INFO)

    log_dir = Path("logs")
    log_dir.mkdir(exist_ok=True)

    formatter = logging.Formatter(
        "%(asctime)s | %(levelname)s | %(name)s | %(message)s"
    )

    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)

    file_handler = logging.FileHandler(log_dir / "app.log")
    file_handler.setFormatter(formatter)

    logger.addHandler(console_handler)
    logger.addHandler(file_handler)

    return logger



"""
Exceptions
"""
class SalesIntelError(Exception):
    """Base exception for all sales intelligence platform errors."""

    def __init__(self, message: str, details: dict | None = None):
        super().__init__(message)
        self.message = message
        self.details = details or {}

    def __str__(self) -> str:
        if self.details:
            return f"{self.message} | Details: {self.details}"
        return self.message


class DataIngestionError(SalesIntelError):
    """Raised when raw data ingestion fails."""


class DataValidationError(SalesIntelError):
    """Raised when input data is invalid or incomplete."""


class TransformationError(SalesIntelError):
    """Raised when feature engineering or transformation fails."""


class DatabaseError(SalesIntelError):
    """Raised when database operations fail."""