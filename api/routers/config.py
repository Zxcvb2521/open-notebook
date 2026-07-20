import asyncio
import secrets
import time
import tomllib
from pathlib import Path
from typing import Optional

from fastapi import APIRouter, Request
from loguru import logger

from open_notebook.database.repository import repo_query
from open_notebook.utils.encryption import get_secret_from_env
from open_notebook.utils.version_utils import (
    compare_versions,
    get_version_from_github_async,
)

router = APIRouter()

# In-memory cache for version check results
_version_cache: dict = {
    "latest_version": None,
    "has_update": False,
    "timestamp": 0,
    "check_failed": False,
}

# Cache TTL in seconds (24 hours)
VERSION_CACHE_TTL = 24 * 60 * 60


def get_version() -> str:
    """Read version from pyproject.toml"""
    try:
        pyproject_path = Path(__file__).parent.parent.parent / "pyproject.toml"
        with open(pyproject_path, "rb") as f:
            pyproject = tomllib.load(f)
            return pyproject.get("project", {}).get("version", "unknown")
    except Exception as e:
        logger.warning(f"Could not read version from pyproject.toml: {e}")
        return "unknown"


async def get_latest_version_cached(current_version: str) -> tuple[Optional[str], bool]:
    """
    Check for the latest version from GitHub with caching.

    Returns:
        tuple: (latest_version, has_update)
        - latest_version: str or None if check failed
        - has_update: bool indicating if update is available
    """
    global _version_cache

    # Check if cache is still valid (within TTL)
    cache_age = time.time() - _version_cache["timestamp"]
    if _version_cache["timestamp"] > 0 and cache_age < VERSION_CACHE_TTL:
        logger.debug(f"Using cached version check result (age: {cache_age:.0f}s)")
        return _version_cache["latest_version"], _version_cache["has_update"]

    # Cache expired or not yet set
    if _version_cache["timestamp"] > 0:
        logger.info(f"Version cache expired (age: {cache_age:.0f}s), refreshing...")

    # Perform version check with strict error handling
    try:
        logger.info("Checking for latest version from GitHub...")

        # Fetch latest version from GitHub with 10-second timeout
        latest_version = await get_version_from_github_async(
            "https://github.com/Zxcvb2521/open-notebook", "win"
        )

        logger.info(
            f"Latest version from GitHub: {latest_version}, Current version: {current_version}"
        )

        # Compare versions
        has_update = compare_versions(current_version, latest_version) < 0

        # Cache the result
        _version_cache["latest_version"] = latest_version
        _version_cache["has_update"] = has_update
        _version_cache["timestamp"] = time.time()
        _version_cache["check_failed"] = False

        logger.info(f"Version check complete. Update available: {has_update}")

        return latest_version, has_update

    except Exception as e:
        logger.warning(f"Version check failed: {e}")

        # Cache the failure to avoid repeated attempts
        _version_cache["latest_version"] = None
        _version_cache["has_update"] = False
        _version_cache["timestamp"] = time.time()
        _version_cache["check_failed"] = True

        return None, False


async def check_database_health() -> dict:
    """
    Check if database is reachable using a lightweight query.

    Returns:
        dict with 'status' ("online" | "offline") and optional 'error'
    """
    try:
        # 2-second timeout for database health check
        result = await asyncio.wait_for(repo_query("RETURN 1"), timeout=2.0)
        if result:
            return {"status": "online"}
        return {"status": "offline", "error": "Empty result"}
    except asyncio.TimeoutError:
        logger.warning("Database health check timed out after 2 seconds")
        return {"status": "offline", "error": "Health check timeout"}
    except Exception as e:
        logger.warning(f"Database health check failed: {e}")
        return {"status": "offline", "error": str(e)}


@router.get("/config")
async def get_config(request: Request):
    """
    Get frontend configuration.

    Returns version information and health status.
    Note: The frontend determines the API URL via its own runtime-config endpoint,
    so this endpoint no longer returns apiUrl.

    Also checks for version updates from GitHub (with caching and error handling).
    """
    # Get current version
    current_version = get_version()

    # Check for updates (with caching and error handling)
    # This MUST NOT break the endpoint - wrapped in try-except as extra safety
    latest_version = None
    has_update = False

    try:
        latest_version, has_update = await get_latest_version_cached(current_version)
    except Exception as e:
        # Extra safety: ensure version check never breaks the config endpoint
        logger.error(f"Unexpected error during version check: {e}")

    # Check database health
    db_health = await check_database_health()
    db_status = db_health["status"]

    if db_status == "offline":
        logger.warning(f"Database offline: {db_health.get('error', 'Unknown error')}")

    return {
        "version": current_version,
        "latestVersion": latest_version,
        "hasUpdate": has_update,
        "dbStatus": db_status,
    }


@router.post("/config/generate-encryption-key")
async def generate_encryption_key():
    """
    Generate a random encryption key, write it to .env, and set it
    in the current process environment so it takes effect immediately.
    """
    # Check if already configured
    if get_secret_from_env("OPEN_NOTEBOOK_ENCRYPTION_KEY"):
        return {"status": "already_configured", "message": "Encryption key is already set."}

    # Generate a random 32-char alphanumeric key
    key = secrets.token_urlsafe(32)

    # Find the .env file relative to project root
    project_root = Path(__file__).parent.parent.parent
    env_path = project_root / ".env"

    if env_path.exists():
        content = env_path.read_text(encoding="utf-8")
        if "OPEN_NOTEBOOK_ENCRYPTION_KEY=" in content:
            # Replace existing (even if empty/commented)
            lines = content.splitlines()
            new_lines = []
            replaced = False
            for line in lines:
                if line.strip().startswith("OPEN_NOTEBOOK_ENCRYPTION_KEY="):
                    new_lines.append(f"OPEN_NOTEBOOK_ENCRYPTION_KEY={key}")
                    replaced = True
                else:
                    new_lines.append(line)
            if not replaced:
                new_lines.append(f"OPEN_NOTEBOOK_ENCRYPTION_KEY={key}")
            env_path.write_text("\n".join(new_lines) + "\n", encoding="utf-8")
        else:
            # Append to .env
            with open(env_path, "a", encoding="utf-8") as f:
                f.write(f"\nOPEN_NOTEBOOK_ENCRYPTION_KEY={key}\n")
    else:
        # Create .env with just the key
        env_path.write_text(f"OPEN_NOTEBOOK_ENCRYPTION_KEY={key}\n", encoding="utf-8")

    # Set in current process so it takes effect without restart
    import os
    os.environ["OPEN_NOTEBOOK_ENCRYPTION_KEY"] = key

    logger.info("Encryption key generated and written to .env")

    return {"status": "success", "message": "Encryption key generated and activated."}
