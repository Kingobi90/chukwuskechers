#!/usr/bin/env python3
"""Startup script for SMAC Warehouse Management System."""
import uvicorn
import sys
import os

# Add the project root to the Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

if __name__ == "__main__":
    print("=" * 60)
    print("🚀 Starting SMAC Warehouse Management System")
    print("=" * 60)
    print("\n📦 Backend API: http://localhost:8000")
    print("🌐 New SMAC UI: http://localhost:8000")
    print("🏚️  Old Warehouse UI: http://localhost:8000/warehouse")
    print("\n" + "=" * 60 + "\n")
    
    uvicorn.run(
        "backend.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )
