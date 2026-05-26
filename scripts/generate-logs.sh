#!/bin/bash

# Telemetry Generator for Observability Testing
# Sends randomized HTTP requests to the FastAPI backend to populate Grafana/Prometheus/Loki.

set -e

# Default parameters
BACKEND_URL="${1:-http://localhost:8000}"
COUNT="${2:-100}" # Total logs to generate
DELAY="${3:-0.3}" # Sleep delay between requests in seconds

# Array of severities
SEVERITIES=("info" "warning" "error")

# Array of typical system events to simulate random messages
INFO_MESSAGES=(
  "User logged in successfully"
  "Database query cache hit"
  "Payment payload validation passed"
  "Session token renewed"
  "Data backup synchronization completed"
  "Cron job clean_sessions ran successfully"
)
WARN_MESSAGES=(
  "Database connection pool pool_size reached 80% capacity"
  "Disk space utilisation on node-3 is at 78%"
  "API response latency threshold exceeded limit: 450ms"
  "Invalid login attempt detected for user: test_account"
  "Email delivery queue timeout: retrying"
)
ERR_MESSAGES=(
  "Database connection timeout on master node"
  "Payment gateway failed: API connection refused"
  "OutOfMemory exception in task queue worker-2"
  "Critical filesystem write error on /data partition"
  "Internal Server Error - Zero division simulation"
)

echo "=========================================================="
echo "    Observability Telemetry Generator Triggered           "
echo "    Sending $COUNT requests to $BACKEND_URL               "
echo "=========================================================="

# Check if curl is available
if ! command -v curl &> /dev/null; then
    echo "Error: curl command is required. Please install curl."
    exit 1
fi

for ((i=1; i<=COUNT; i++))
do
  # Select a random severity (info has 60% probability, warning 30%, error 10%)
  RAND=$((RANDOM % 100))
  if [ $RAND -lt 60 ]; then
    LEVEL="info"
    MSG_IDX=$((RANDOM % ${#INFO_MESSAGES[@]}))
    MSG="${INFO_MESSAGES[$MSG_IDX]}"
  elif [ $RAND -lt 90 ]; then
    LEVEL="warning"
    MSG_IDX=$((RANDOM % ${#WARN_MESSAGES[@]}))
    MSG="${WARN_MESSAGES[$MSG_IDX]}"
  else
    LEVEL="error"
    MSG_IDX=$((RANDOM % ${#ERR_MESSAGES[@]}))
    MSG="${ERR_MESSAGES[$MSG_IDX]}"
  fi

  # URL encode the message
  ENCODED_MSG=$(echo "$MSG" | od -An -tx1 | tr ' ' % | tr -d '\n')
  
  echo -ne "[$i/$COUNT] Triggering log level [$LEVEL] -> "
  
  # Trigger health check once in a while (every 10 requests)
  if [ $((i % 10)) -eq 0 ]; then
    echo -ne "Also checking /health -> "
    curl -s -o /dev/null -w "Health Status: %{http_code}\n" "$BACKEND_URL/health"
  else
    # Request backend to log this message
    RESPONSE=$(curl -s "$BACKEND_URL/generate-log?level=$LEVEL&message=$ENCODED_MSG")
    echo "$RESPONSE"
  fi

  sleep $DELAY
done

echo -e "\n✔ Done! Telemetry generated. Check Grafana dashboard for real-time visualizations."
