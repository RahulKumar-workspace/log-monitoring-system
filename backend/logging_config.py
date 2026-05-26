import logging
import sys
import json
from datetime import datetime

class JsonFormatter(logging.Formatter):
    """
    Custom formatter that outputs log records as structured JSON.
    This is highly useful for log aggregators like Loki or Fluent Bit.
    """
    def format(self, record):
        # Base log record fields
        log_record = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "level": record.levelname,
            "message": record.getMessage(),
            "logger": record.name,
            "filename": record.filename,
            "lineno": record.lineno,
        }
        
        # Include exception tracebacks if present
        if record.exc_info:
            log_record["exception"] = self.formatException(record.exc_info)
            
        # Merge extra attributes if passed in the 'extra' dictionary
        # Excluding standard attributes
        standard_attrs = {
            'args', 'asctime', 'created', 'exc_info', 'exc_text', 'filename',
            'funcName', 'levelname', 'levelno', 'lineno', 'module',
            'msecs', 'message', 'msg', 'name', 'pathname', 'process',
            'processName', 'relativeCreated', 'stack_info', 'thread', 'threadName'
        }
        extra_attrs = {k: v for k, v in record.__dict__.items() if k not in standard_attrs}
        if extra_attrs:
            log_record["extra"] = extra_attrs

        return json.dumps(log_record)

def setup_logging(log_level: str = "INFO", log_file: str = None):
    """
    Configures the root logger to output structured JSON to stdout (and optionally a file).
    """
    # Parse string log level to standard logging constants
    numeric_level = getattr(logging, log_level.upper(), None)
    if not isinstance(numeric_level, int):
        numeric_level = logging.INFO

    root_logger = logging.getLogger()
    root_logger.setLevel(numeric_level)

    # Avoid duplicate handlers if setup is called multiple times
    if root_logger.hasHandlers():
        root_logger.handlers.clear()

    # Configure handler for standard output (stdout)
    stdout_handler = logging.StreamHandler(sys.stdout)
    stdout_handler.setFormatter(JsonFormatter())
    root_logger.addHandler(stdout_handler)
    
    # Configure file handler if file path is provided
    if log_file:
        try:
            # Ensure the directory exists
            import os
            os.makedirs(os.path.dirname(log_file), exist_ok=True)
            file_handler = logging.FileHandler(log_file)
            file_handler.setFormatter(JsonFormatter())
            root_logger.addHandler(file_handler)
        except Exception as e:
            root_logger.error(f"Failed to initialize file logger: {str(e)}")
    
    # Optional: silence noisy library loggers (like uvicorn access logs)
    # or keep them so Fluent Bit gathers everything.
    # We will set uvicorn logs to also output JSON or let FastAPI handle it.
    logging.getLogger("uvicorn.error").setLevel(numeric_level)
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING) # reduce noise
