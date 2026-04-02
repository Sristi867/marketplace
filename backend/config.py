"""
Database configuration for ElectroMarket
Edit these values to match your MySQL setup
"""
import os

DB_CONFIG = {
    "host":     os.getenv("DB_HOST", "localhost"),
    "user":     os.getenv("DB_USER", "root"),
    "password": os.getenv("DB_PASS", ""),        # ← put your MySQL password here
    "database": "electromarket",
    "charset":  "utf8mb4",
}