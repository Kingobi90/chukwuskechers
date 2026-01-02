#!/bin/bash

# Stop the warehouse server and monitor

PROJECT_DIR="/Users/obinna.c/CascadeProjects/chukwu"
PID_FILE="$PROJECT_DIR/server.pid"

echo "Stopping warehouse server..."

# Kill the monitor script
pkill -f "start_server.sh"

# Kill uvicorn processes
pkill -f "uvicorn backend.main:app"

# Remove PID file
rm -f "$PID_FILE"

echo "Server stopped."
