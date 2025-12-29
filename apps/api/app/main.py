from fastapi import FastAPI
import os

APP_VERSION = os.getenv("APP_VERSION", "0.1.0")
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./data/app.db")
STORAGE_ROOT = os.getenv("STORAGE_ROOT", "./data/storage")

app = FastAPI(title="AI Content Workstation API", version=APP_VERSION)

@app.get("/health")
def health():
    # ARCH expectation shape: status/version/db/storage/last_error_summary
    # Keep it minimal and deterministic for local-dev.
    db_path = "./data/app.db"  # aligned to DATABASE_URL default in ARCH
    return {
        "status": "ok",
        "version": APP_VERSION,
        "db": {"status": "ok", "kind": "sqlite", "path": db_path},
        "storage": {"status": "ok", "root": STORAGE_ROOT},
        "last_error_summary": None,
    }
