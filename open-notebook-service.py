"""
Open Notebook Windows Service
Manages all 4 components as child processes.
Install:  python open-notebook-service.py install
Start:    python open-notebook-service.py start
Stop:     python open-notebook-service.py stop
Remove:   python open-notebook-service.py remove
"""

import logging
import os
import subprocess
import sys
import time

import win32serviceutil
import win32service
import win32event
import servicemanager

# ─── Logging ────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] %(levelname)s: %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("OpenNotebookService")

# ─── Paths ──────────────────────────────────────────────────────────────────
PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))
LOG_DIR = os.path.join(PROJECT_ROOT, "logs")
SURREAL_DATA = os.path.join(PROJECT_ROOT, "surreal_data")
FRONTEND_DIR = os.path.join(PROJECT_ROOT, "frontend")
ENV_FILE = os.path.join(PROJECT_ROOT, ".env")

SERVICE_NAME = "OpenNotebook"


class OpenNotebookService(win32serviceutil.ServiceFramework):
    """Windows Service for Open Notebook."""

    _svc_name_ = SERVICE_NAME
    _svc_display_name_ = "Open Notebook"
    _svc_description_ = "AI-powered research assistant - manages database, API, worker and frontend"

    def __init__(self, args):
        win32serviceutil.ServiceFramework.__init__(self, args)
        self.hWaitStop = win32event.CreateEvent(None, 0, 0, None)
        self.running = False
        self.processes = {}  # name -> subprocess.Popen

    def SvcStop(self):
        """Called when service is asked to stop."""
        self.ReportServiceStatus(win32service.SERVICE_STOP_PENDING)
        win32event.SetEvent(self.hWaitStop)
        self.running = False
        log.info("Service stopping...")

    def SvcDoRun(self):
        """Called when service starts."""
        servicemanager.LogMsg(
            servicemanager.EVENTLOG_INFORMATION_TYPE,
            servicemanager.PYS_SERVICE_STARTED,
            (self._svc_name_, ""),
        )
        log.info("Open Notebook Service starting...")
        self.running = True
        self.main()

    def start_process(self, name, cmd, cwd=None, title=None, env_extra=None):
        """Start a process and track it."""
        try:
            startupinfo = subprocess.STARTUPINFO()
            startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            startupinfo.wShowWindow = 0  # SW_HIDE

            env = os.environ.copy()
            env["PYTHONUNBUFFERED"] = "1"
            if env_extra:
                env.update(env_extra)

            log_path = os.path.join(LOG_DIR, f"{name}.log")
            os.makedirs(LOG_DIR, exist_ok=True)

            kwargs = {
                "cwd": cwd or PROJECT_ROOT,
                "stdout": open(log_path, "a", encoding="utf-8"),
                "stderr": subprocess.STDOUT,
                "startupinfo": startupinfo,
                "env": env,
                "creationflags": subprocess.CREATE_NO_WINDOW,
            }

            # Use shell for complex commands
            if isinstance(cmd, str):
                kwargs["shell"] = True

            log.info(f"  Starting {name}: {cmd[:80]}...")
            p = subprocess.Popen(cmd, **kwargs)
            self.processes[name] = p
            log.info(f"  [+] {name} started (PID {p.pid})")
            return p
        except Exception as e:
            log.error(f"  [!] Failed to start {name}: {e}")
            return None

    def stop_process(self, name):
        """Stop a tracked process."""
        p = self.processes.pop(name, None)
        if p and p.poll() is None:
            try:
                p.terminate()
                p.wait(timeout=5)
                log.info(f"  [+] {name} stopped")
            except Exception:
                try:
                    p.kill()
                    log.info(f"  [+] {name} killed")
                except Exception:
                    pass

    def wait_for_url(self, url, timeout=30, label="service"):
        """Wait until URL responds."""
        import urllib.request

        for i in range(timeout):
            if not self.running:
                return False
            try:
                r = urllib.request.urlopen(url, timeout=2)
                if r.getcode() == 200:
                    log.info(f"  [+] {label} ready ({i + 1}s)")
                    return True
            except Exception:
                pass
            time.sleep(1)
        log.warning(f"  [*] {label} did not respond within {timeout}s")
        return False

    def main(self):
        """Main service loop - manages all subprocesses."""
        os.makedirs(LOG_DIR, exist_ok=True)
        os.makedirs(SURREAL_DATA, exist_ok=True)

        try:
            # ── 1. SurrealDB ────────────────────────────────────────────
            log.info("[1/4] SurrealDB...")
            surreal_cmd = (
                f'surreal start --log info --user root --pass root '
                f'rocksdb:{SURREAL_DATA}\\mydatabase.db'
            )
            self.start_process("SurrealDB", surreal_cmd)
            self.wait_for_url("http://localhost:8000/health", timeout=20, label="SurrealDB")

            # ── 2. FastAPI ──────────────────────────────────────────────
            log.info("[2/4] FastAPI...")
            fastapi_cmd = (
                f'uv run --env-file "{ENV_FILE}" '
                f'uvicorn api.main:app --host 127.0.0.1 --port 5055'
            )
            self.start_process("FastAPI", fastapi_cmd)
            self.wait_for_url("http://localhost:5055/docs", timeout=35, label="FastAPI")

            # ── 3. Worker ───────────────────────────────────────────────
            log.info("[3/4] Worker...")
            worker_cmd = (
                f'uv run --env-file "{ENV_FILE}" '
                f'surreal-commands-worker --import-modules commands'
            )
            self.start_process("Worker", worker_cmd)

            # ── 4. Frontend (standalone production mode) ──────────────
            log.info("[4/4] Frontend...")
            frontend_cmd = "node start-server.js"
            self.start_process("Frontend", frontend_cmd, cwd=FRONTEND_DIR, env_extra={"PORT": "3000"})
            self.wait_for_url("http://localhost:3000", timeout=30, label="Frontend")

            log.info("=" * 44)
            log.info("  Open Notebook is RUNNING")
            log.info("  Frontend: http://localhost:3000")
            log.info("  API:      http://localhost:5055")
            log.info("=" * 44)

            # ── Keep alive ──────────────────────────────────────────────
            while self.running:
                # Check if any process died
                for name, p in list(self.processes.items()):
                    if p.poll() is not None:
                        log.warning(f"  [!] {name} exited (code {p.returncode})")
                        # Auto-restart the worker and frontend if they die
                        if name in ("Worker", "Frontend"):
                            log.info(f"  [*] Restarting {name}...")
                            if name == "Frontend":
                                self.start_process(name, frontend_cmd, cwd=FRONTEND_DIR, env_extra={"PORT": "3000"})
                            elif name == "Worker":
                                self.start_process(name, worker_cmd)
                time.sleep(2)

        except Exception as e:
            log.exception(f"Service error: {e}")
        finally:
            # ── Stop all processes ──────────────────────────────────────
            log.info("Stopping all services...")
            for name in ("Frontend", "Worker", "FastAPI", "SurrealDB"):
                self.stop_process(name)

            # Kill remaining by window title (safety net)
            for exe in ("surreal.exe", "uvicorn.exe", "node.exe"):
                subprocess.run(
                    f"taskkill /im {exe} /f >nul 2>&1",
                    shell=True,
                    capture_output=True,
                )

            log.info("[+] All services stopped")


if __name__ == "__main__":
    if len(sys.argv) == 1:
        servicemanager.Initialize()
        servicemanager.PrepareToHostSingle(OpenNotebookService)
        servicemanager.StartServiceCtrlDispatcher()
    else:
        win32serviceutil.HandleCommandLine(OpenNotebookService)
