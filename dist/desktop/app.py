"""Open Notebook Desktop App"""
import os, subprocess, sys, time, threading, urllib.request, atexit, shutil, tkinter as tk
from tkinter import ttk

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOG_DIR = os.path.join(PROJECT_ROOT, "logs")
SURREAL_DATA = os.path.join(PROJECT_ROOT, "surreal_data")
FRONTEND_DIR = os.path.join(PROJECT_ROOT, "frontend")
ENV_FILE = os.path.join(PROJECT_ROOT, ".env")
APP_URL = "http://localhost:3000"

os.makedirs(LOG_DIR, exist_ok=True)
os.makedirs(SURREAL_DATA, exist_ok=True)
processes = {}
running = True

# Auto-create .env if missing
if not os.path.exists(ENV_FILE):
    env_example = ENV_FILE + ".example"
    if os.path.exists(env_example):
        import shutil
        shutil.copy2(env_example, ENV_FILE)
        # Fix host and generate key
        with open(ENV_FILE, "r", encoding="utf-8") as f:
            c = f.read()
        c = c.replace("change-me-to-a-secret-string", os.urandom(16).hex())
        c = c.replace("ws://surrealdb:8000/rpc", "ws://localhost:8000/rpc")
        with open(ENV_FILE, "w", encoding="utf-8") as f:
            f.write(c)
        print(f"[.] Created .env from .env.example")
    else:
        with open(ENV_FILE, "w", encoding="utf-8") as f:
            f.write(f'OPEN_NOTEBOOK_ENCRYPTION_KEY={os.urandom(16).hex()}\n')
            f.write(f'SURREAL_URL=ws://localhost:8000/rpc\n')
            f.write(f'SURREAL_USER=root\n')
            f.write(f'SURREAL_PASSWORD=root\n')
            f.write(f'SURREAL_NAMESPACE=open_notebook\n')
            f.write(f'SURREAL_DATABASE=open_notebook\n')
        print(f"[.] Created minimal .env")

# ─── Splash Window ──────────────────────────────────────────────────────────
class Splash:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("Starting Open Notebook...")
        self.root.geometry("480x200")
        self.root.resizable(False, False)
        self.root.configure(bg="#1e1e2e")
        
        # Center on screen
        self.root.update_idletasks()
        w = self.root.winfo_width(); h = self.root.winfo_height()
        sw = self.root.winfo_screenwidth(); sh = self.root.winfo_screenheight()
        self.root.geometry(f"{w}x{h}+{(sw-w)//2}+{(sh-h)//2}")
        
        self.frame = tk.Frame(self.root, bg="#1e1e2e", padx=30, pady=20)
        self.frame.pack(fill="both", expand=True)
        
        tk.Label(self.frame, text="Open Notebook", font=("Segoe UI", 18, "bold"),
            fg="#ffffff", bg="#1e1e2e").pack(pady=(0,5))
        tk.Label(self.frame, text="Starting services...", font=("Segoe UI", 10),
            fg="#a0a0b0", bg="#1e1e2e").pack()
        
        self.progress = ttk.Progressbar(self.frame, mode="indeterminate", length=400)
        self.progress.pack(pady=20)
        self.progress.start(10)
        
        self.status_var = tk.StringVar(value="Initializing...")
        tk.Label(self.frame, textvariable=self.status_var,
            font=("Segoe UI", 9), fg="#c0c0d0", bg="#1e1e2e", wraplength=420).pack()
        
        self.root.after(100, self._poll)
    
    def _poll(self):
        """Check if we should close."""
        try: self.root.update()
        except: pass
        self.root.after(100, self._poll)
    
    def set_status(self, msg):
        self.status_var.set(msg)
    
    def close(self):
        self.running = False
        try: self.root.destroy()
        except: pass

splash = Splash()

# ─── Background Service Thread ──────────────────────────────────────────────
def log(msg):
    splash.set_status(msg)
    print(f"[{time.strftime('%H:%M:%S')}] {msg}")

def start_proc(name, args, cwd=None, shell=False):
    log_path = os.path.join(LOG_DIR, f"{name}.log")
    try:
        p = subprocess.Popen(args, cwd=cwd or PROJECT_ROOT,
            stdout=open(log_path, "a", encoding="utf-8", errors="replace"),
            stderr=subprocess.STDOUT,
            creationflags=subprocess.CREATE_NO_WINDOW, shell=shell)
        processes[name] = p
        return p
    except Exception as e:
        log(f"Error starting {name}: {e}")
        return None

def stop_all():
    global running
    if not running: return
    running = False
    for name in ("Frontend", "Worker", "FastAPI", "SurrealDB"):
        p = processes.pop(name, None)
        if p and p.poll() is None:
            try: p.terminate(); p.wait(3)
            except: pass
    for exe in ("surreal.exe", "uvicorn.exe"):
        subprocess.run(f"taskkill /im {exe} /f >nul 2>&1", shell=True)
    subprocess.run('taskkill /fi "WINDOWTITLE eq Frontend" /f >nul 2>&1', shell=True)

def wait_url(url, timeout=40, label=""):
    for i in range(timeout):
        try:
            r = urllib.request.urlopen(url, timeout=3)
            if r.getcode() == 200:
                log(f"{label} ready ({i+1}s)"); return True
        except: pass
        if i % 5 == 0:
            splash.set_status(f"Waiting for {label} ({i+1}s)...")
        time.sleep(1)
    log(f"{label} timeout - check logs")
    # Show last log lines
    log_path = os.path.join(LOG_DIR, f"{label}.log")
    if os.path.exists(log_path):
        with open(log_path, encoding="utf-8", errors="replace") as f:
            lines = f.readlines()[-5:]
        splash.set_status(f"{label} failed. Check logs.")
        for line in lines:
            print(f"  {line.strip()}")
    return False

def run_services():
    log("Preparing...")
    subprocess.run("taskkill /im surreal.exe /f >nul 2>&1", shell=True)
    lock = os.path.join(SURREAL_DATA, "mydatabase.db", "LOCK")
    if os.path.exists(lock): os.remove(lock)
    
    log("Starting SurrealDB...")
    surrealdb = r"C:\Users\Evgenyi\AppData\Local\SurrealDB\surreal.exe"
    start_proc("SurrealDB", [surrealdb, "start", "--log", "info",
        "--user", "root", "--pass", "root", f"rocksdb:{SURREAL_DATA}\\mydatabase.db"])
    if not wait_url("http://localhost:8000/health", 25, "SurrealDB"):
        stop_all(); return
    
    log("Starting FastAPI...")
    start_proc("FastAPI", ['cmd.exe', '/c', f'cd /d {PROJECT_ROOT.replace(chr(92),"/")} && uv run --env-file {ENV_FILE.replace(chr(92),"/")} uvicorn api.main:app --host 127.0.0.1 --port 5055'],
        shell=False)
    if not wait_url("http://localhost:5055/docs", 60, "FastAPI"):
        stop_all(); return
    
    log("Starting Worker...")
    start_proc("Worker", ['cmd.exe', '/c', f'cd /d {PROJECT_ROOT.replace(chr(92),"/")} && uv run --env-file {ENV_FILE.replace(chr(92),"/")} surreal-commands-worker --import-modules commands'],
        shell=False)
    
    log("Starting Frontend...")
    start_proc("Frontend", ['cmd.exe', '/c', f'cd /d {FRONTEND_DIR.replace(chr(92),"/")} && npm run dev'], shell=False)
    wait_url(APP_URL, 30, "Frontend")
    
    log("All services ready!")
    
    # Open Edge app mode
    edge_paths = [
        r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
    ]
    edge = None
    for p in edge_paths:
        if os.path.exists(p): edge = p; break
    if not edge:
        edge = shutil.which("msedge") or shutil.which("chrome")
    
    if edge:
        subprocess.Popen([edge, f"--app={APP_URL}", "--no-first-run",
            f"--user-data-dir={os.path.join(PROJECT_ROOT, '.edge_profile')}"],
            creationflags=subprocess.CREATE_NO_WINDOW)
        log("App window opened")
    else:
        import webbrowser
        webbrowser.open(APP_URL)
    
    time.sleep(2)
    splash.close()

# ─── Main ────────────────────────────────────────────────────────────────────
atexit.register(stop_all)

t = threading.Thread(target=run_services, daemon=True)
t.start()

try:
    splash.root.mainloop()
except:
    pass

stop_all()
