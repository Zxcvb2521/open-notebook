#!/usr/bin/env python3
"""
Open Notebook - Install Python AI Service dependencies.
Run once: python plugins/install.py
"""
import subprocess
import sys
from pathlib import Path

def main():
    req = Path(__file__).parent / "requirements.txt"
    print(f"Installing dependencies from {req}...")
    subprocess.check_call([
        sys.executable, "-m", "pip", "install", "-r", str(req), "--quiet"
    ])
    print("Done. AI service dependencies installed.")

if __name__ == "__main__":
    main()
