# Build stage to install requirements
FROM python:3.11-slim AS builder

WORKDIR /app

# Prevent Python from writing .pyc files and enable unbuffered logging
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Install build dependencies if needed
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

# Install dependencies to a local folder to avoid permissions issues
RUN pip install --no-cache-dir --user -r requirements.txt

# Final runner stage
FROM python:3.11-slim AS runner

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PATH=/home/appuser/.local/bin:$PATH

# Create a non-privileged user to run the app
RUN groupadd -g 10001 appuser && \
    useradd -u 10001 -g appuser -m -s /sbin/nologin appuser

# Copy installed libraries and application files
COPY --from=builder /root/.local /home/appuser/.local
COPY --chown=appuser:appuser logging_config.py /app/
COPY --chown=appuser:appuser main.py /app/

# Switch to non-root user
USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
