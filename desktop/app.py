"""
Open Notebook - Windows Launcher
Starts all services, opens Edge app, stops on close.
"""
import subprocess
import sys
import os
import time
import urllib.request
import signal
import traceback
import winreg

def get_root():
    if getattr(sys, 'frozen', False):
        exe_dir = os.path.dirname(os.path.abspath(sys.executable))
        if os.path.basename(exe_dir).lower() == "dist":
            return os.path.dirname(exe_dir)
        return exe_dir
    return os.path.dirname(os.path.abspath(__file__))

def find_in_registry(name):
    """Try to find an executable path from Windows registry (Uninstall keys)."""
    try:
        for root_key in [winreg.HKEY_CURRENT_USER, winreg.HKEY_LOCAL_MACHINE]:
            for sub in [r"Software\Microsoft\Windows\CurrentVersion\Uninstall",
                        r"Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"]:
                try:
                    key = winreg.OpenKey(root_key, sub)
                    i = 0
                    while True:
                        try:
                            subkey_name = winreg.EnumKey(key, i)
                            subkey = winreg.OpenKey(key, subkey_name)
                            try:
                                loc, _ = winreg.QueryValueEx(subkey, "InstallLocation")
                                if loc and os.path.isdir(loc):
                                    exe = os.path.join(loc, name)
                                    if os.path.isfile(exe):
                                        return exe
                            except: pass
                            winreg.CloseKey(subkey)
                        except OSError:
                            break
                        i += 1
                    winreg.CloseKey(key)
                except: pass
    except: pass
    return None

def find_exe(name, extra_dirs=None):
    """Find an executable by name using PATH, registry, and common locations."""
    # extra_dirs first (project-specific paths take priority)
    if extra_dirs:
        for d in extra_dirs:
            candidate = os.path.join(d, name)
            if os.path.isfile(candidate):
                return candidate
    # Registry lookup
    found = find_in_registry(name)
    if found:
        return found
    dirs = []
    for base in [os.environ.get("LOCALAPPDATA", ""), os.environ.get("PROGRAMFILES", ""),
                 os.environ.get("PROGRAMFILES(X86)", ""), os.environ.get("HOME", "")]:
        if base:
            dirs.append(os.path.join(base, name))
            for sub in [name, "Microsoft", "Google", "nodejs", "SurrealDB", ".local\\bin"]:
                dirs.append(os.path.join(base, sub, name))
    # PATH lookup
    for p in os.environ.get("PATH", "").split(";"):
        candidate = os.path.join(p.strip(), name)
        if os.path.isfile(candidate):
            return candidate
    # Common full paths
    candidates = [
        r"C:\Program Files\nodejs\npm.cmd",
        r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
        r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    ]
    for c in candidates:
        if os.path.isfile(c):
            return c
    return name  # return bare name, let subprocess try PATH

ROOT = get_root()
UV = find_exe("uv.exe", [
    os.path.expanduser("~\\.local\\bin"),
    os.path.expanduser("~\\AppData\\Local\\uv"),
]) or "uv"
SURREAL = find_exe("surreal.exe", [
    os.path.expanduser("~\\AppData\\Local\\SurrealDB"),
]) or "surreal"
NPM = find_exe("npm.cmd", [
    r"C:\Program Files\nodejs",
]) or find_exe("npm", [
    r"C:\Program Files\nodejs",
]) or "npm.cmd"
EDGE = find_exe("msedge.exe") or find_exe("chrome.exe") or ""
PROCS = []
NO_WINDOW = subprocess.CREATE_NO_WINDOW
LOG_FILE = os.path.join(ROOT, "logs", "launcher.log")

def log(msg):
    print(msg)
    try:
        os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(f"{time.strftime('%H:%M:%S')} {msg}\n")
    except: pass

def wait_port(port, timeout=40):
    for i in range(timeout):
        try:
            urllib.request.urlopen(f"http://localhost:{port}/", timeout=2)
            return True
        except:
            time.sleep(1)
    return False

def start_surreal():
    lock = os.path.join(ROOT, "surreal_data", "mydatabase.db", "LOCK")
    if os.path.exists(lock):
        try: os.remove(lock)
        except: pass
    
    cmd = [SURREAL, "start", "--log", "info", "--user", "root", "--pass", "root",
           f"rocksdb:{ROOT}\\surreal_data\\mydatabase.db"]
    log(f"  CMD: {' '.join(cmd)}")
    p = subprocess.Popen(cmd, creationflags=NO_WINDOW, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    PROCS.append(p)
    log("  Waiting for SurrealDB...")
    if wait_port(8000):
        log("  [+] SurrealDB ready")
        return True
    log("  [!] SurrealDB failed")
    return False

def start_fastapi():
    cmd = [UV, "run", "--env-file", ".env", "uvicorn", "api.main:app", "--host", "127.0.0.1", "--port", "5055"]
    log(f"  CMD: {' '.join(cmd)}")
    p = subprocess.Popen(cmd, cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    PROCS.append(p)
    log("  Waiting for FastAPI...")
    if wait_port(5055):
        log("  [+] FastAPI ready")
        return True
    log("  [!] FastAPI failed")
    return False

def start_worker():
    cmd = [UV, "run", "--env-file", ".env", "surreal-commands-worker", "--import-modules", "commands"]
    log(f"  CMD: {' '.join(cmd)}")
    p = subprocess.Popen(cmd, cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    PROCS.append(p)
    log("  [+] Worker started")
    return True

def start_frontend():
    cmd = [NPM, "run", "dev"]
    log(f"  CMD: {' '.join(cmd)}")
    p = subprocess.Popen(cmd, cwd=os.path.join(ROOT, "frontend"), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    PROCS.append(p)
    log("  Waiting for Frontend...")
    if wait_port(3000, 30):
        log("  [+] Frontend ready")
        return True
    log("  [!] Frontend failed")
    return False

def cleanup(*args):
    log("\nStopping services...")
    for p in PROCS:
        try: p.kill()
        except: pass
    for name in ["surreal.exe", "uvicorn.exe", "surreal-commands-worker.exe"]:
        subprocess.run(["taskkill", "/f", "/im", name], capture_output=True)
    log("Done.")

def main():
    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)
    
    # Clear old log
    try: os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
    except: pass
    with open(LOG_FILE, "w") as f: f.write("=== Launcher started ===\n")
    
    log("============================================")
    log("  Open Notebook - Starting...")
    log("============================================")
    log(f"  ROOT: {ROOT}")
    log(f"  UV: {UV}")
    log(f"  SURREAL: {SURREAL}")
    log(f"  NPM: {NPM}")
    log(f"  EDGE: {EDGE}")
    log(f"  File exists: uv={os.path.exists(UV)}, surreal={os.path.exists(SURREAL)}, edge={os.path.exists(EDGE)}")
    log("")
    
    try:
        log("[1/4] SurrealDB...")
        if not start_surreal():
            input("Press Enter to exit..."); return
        
        log("[2/4] FastAPI...")
        if not start_fastapi():
            input("Press Enter to exit..."); return
        
        log("[3/4] Worker...")
        start_worker()
        
        log("[4/4] Frontend...")
        if not start_frontend():
            input("Press Enter to exit..."); return
        
        log("")
        log("============================================")
        log("  Open Notebook is RUNNING!")
        log("  Frontend: http://localhost:3000")
        log("  API:      http://localhost:5055")
        log("============================================")
        log("")
        log("  Opening app window...")
        
        edge = subprocess.Popen(
            [EDGE, "--app", "http://localhost:3000", 
             f"--user-data-dir={ROOT}\\.edge_profile",
             "--no-first-run", "--disable-features=msEdgeFirstRunExperience"],
            creationflags=NO_WINDOW
        )
        PROCS.append(edge)
        
        log("  Close the app window to stop all services.")
        
        while edge.poll() is None:
            time.sleep(1)
    except Exception as e:
        log(f"ERROR: {e}")
        log(traceback.format_exc())
    finally:
        cleanup()

if __name__ == "__main__":
    main()
