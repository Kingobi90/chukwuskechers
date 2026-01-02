#!/bin/bash

# Warehouse Server Auto-Restart Script
# This script monitors the server and restarts it if it crashes

PROJECT_DIR="/Users/obinna.c/CascadeProjects/chukwu"
LOG_DIR="$PROJECT_DIR/logs"
PID_FILE="$PROJECT_DIR/server.pid"

cd "$PROJECT_DIR"

# Function to start the server
start_server() {
    echo "[$(date)] Starting warehouse server..."
    source venv/bin/activate
    uvicorn backend.main:app --host 0.0.0.0 --port 8000 > "$LOG_DIR/warehouse.log" 2> "$LOG_DIR/warehouse.error.log" &
    echo $! > "$PID_FILE"
    echo "[$(date)] Server started with PID: $(cat $PID_FILE)"
}

# Function to check if server is running
is_server_running() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            # Check if it's actually responding
            if curl -s http://localhost:8000/health > /dev/null 2>&1; then
                return 0
            fi
        fi
    fi
    return 1
}

# Function to stop the server
stop_server() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        echo "[$(date)] Stopping server (PID: $PID)..."
        kill "$PID" 2>/dev/null
        rm -f "$PID_FILE"
    fi
}

# Trap to handle script termination
trap 'echo "[$(date)] Stopping monitor..."; stop_server; exit 0' SIGINT SIGTERM

echo "[$(date)] Starting warehouse server monitor..."
echo "Press Ctrl+C to stop"

# Initial start
start_server

# Monitor loop
while true; do
    sleep 10
    
    if ! is_server_running; then
        echo "[$(date)] Server is down! Restarting..."
        stop_server
        sleep 2
        start_server
    fi
done
