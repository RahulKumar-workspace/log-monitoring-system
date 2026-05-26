import os
import logging
import uuid
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from prometheus_fastapi_instrumentator import Instrumentator

from logging_config import setup_logging

# Load configurations from environment variables
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
LOG_FILE = os.getenv("LOG_FILE", None)
APP_NAME = os.getenv("APP_NAME", "log-monitoring-backend")
CORS_ORIGINS = os.getenv("CORS_ORIGINS", "*").split(",")

# Initialize structured logging
setup_logging(LOG_LEVEL, LOG_FILE)
logger = logging.getLogger("backend")

# Create FastAPI instance
app = FastAPI(
    title="Cloud-Native DevOps log-monitoring-backend",
    description="FastAPI service serving as the log & metrics source for our observability pipeline.",
    version="1.0.0"
)

# Enable CORS middleware to allow the Vite React frontend to communicate with the API
app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize Prometheus instrumentation
# This automatically registers standard HTTP metrics (duration, count, status)
instrumentator = Instrumentator(
    should_group_status_codes=False,
    should_ignore_untemplated=True,
    should_respect_env_var=True,
    env_var_name="ENABLE_METRICS",
)
instrumentator.instrument(app).expose(app, endpoint="/metrics")

@app.on_event("startup")
async def startup_event():
    logger.info("Application starting up", extra={"app_name": APP_NAME, "log_level": LOG_LEVEL})

@app.on_event("shutdown")
async def shutdown_event():
    logger.info("Application shutting down")

@app.get("/health")
def health_check():
    """
    Health check endpoint for Kubernetes liveness/readiness probes.
    """
    logger.debug("Health check requested")
    return {
        "status": "healthy",
        "app_name": APP_NAME,
        "environment": os.getenv("ENVIRONMENT", "development"),
        "timestamp": os.getenv("CURRENT_TIME", "2026-05-26T02:05:48+05:30")
    }

@app.get("/generate-log")
def generate_log(
    level: str = Query(..., description="Log level: info, warning, or error"),
    message: str = Query(None, description="Optional custom log message")
):
    """
    Generates a structured JSON log at the specified severity level.
    """
    correlation_id = str(uuid.uuid4())
    log_msg = message or f"Simulated log action for level '{level}' triggered by user request."
    
    extra_data = {
        "correlation_id": correlation_id,
        "triggered_by": "api_request",
        "path": "/generate-log",
        "level_requested": level
    }

    if level.lower() == "info":
        logger.info(log_msg, extra=extra_data)
        return {"status": "success", "level": "info", "message": log_msg, "correlation_id": correlation_id}
        
    elif level.lower() == "warning":
        logger.warning(log_msg, extra=extra_data)
        return {"status": "success", "level": "warning", "message": log_msg, "correlation_id": correlation_id}
        
    elif level.lower() == "error":
        # Simulate a caught exception for richer logs
        try:
            # Division by zero to force an error context
            _ = 1 / 0
        except ZeroDivisionError as e:
            logger.error(f"{log_msg} - Exception caught: {str(e)}", exc_info=True, extra=extra_data)
            
        return {
            "status": "error_logged",
            "level": "error",
            "message": log_msg,
            "correlation_id": correlation_id,
            "error_detail": "ZeroDivisionError simulated"
        }
        
    else:
        logger.warning(f"Invalid log level requested: {level}", extra={"correlation_id": correlation_id})
        raise HTTPException(
            status_code=400,
            detail="Invalid log level. Please specify 'info', 'warning', or 'error'."
        )
