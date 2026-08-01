use std::net::TcpListener;
use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use std::sync::Mutex;
use std::time::{Duration, Instant};

/// Embedded copy of the AI service plugin. Compiled into the binary so the
/// app works after installation even when plugins/ai_service.py is not
/// present next to the exe (e.g. Program Files install from the NSIS bundle).
const EMBEDDED_AI_SERVICE: &str =
    include_str!(concat!(env!("CARGO_MANIFEST_DIR"), "/../plugins/ai_service.py"));

/// Check if a port is available for binding
fn is_port_available(port: u16) -> bool {
    TcpListener::bind(format!("127.0.0.1:{}", port)).is_ok()
}

pub struct AiService {
    child: Mutex<Option<Child>>,
    port: u16,
    base_url: String,
    plugin_path: PathBuf,
    started_at: Mutex<Option<Instant>>,
}

impl AiService {
    pub fn new(app_dir: PathBuf) -> Self {
        // Try ports 8421, 8422, 8423 to find an available one
        let port = [8421, 8422, 8423]
            .into_iter()
            .find(|&p| is_port_available(p))
            .unwrap_or(8421);

        log::info!("AI Service will run on port {}", port);

        // Ensure plugins dir exists in app_data
        let plugins_dir = app_dir.join("plugins");
        let _ = std::fs::create_dir_all(&plugins_dir);

        // Write the embedded AI service plugin into app_data/plugins/
        let plugin_path = plugins_dir.join("ai_service.py");
        let write_result = std::fs::write(&plugin_path, EMBEDDED_AI_SERVICE);
        match write_result {
            Ok(_) => log::info!("Wrote embedded AI plugin to {:?}", plugin_path),
            Err(e) => {
                log::warn!("Failed to write embedded AI plugin to {:?}: {}", plugin_path, e);
                // Fallback: try to copy from source locations
                if let Some(source) = Self::find_source_plugin(&app_dir) {
                    if let Err(e) = std::fs::copy(&source, &plugin_path) {
                        log::warn!("Fallback copy of AI plugin also failed: {}", e);
                    } else {
                        log::info!("Copied AI plugin from {:?} to {:?}", source, plugin_path);
                    }
                }
            }
        }

        Self {
            child: Mutex::new(None),
            port,
            base_url: format!("http://127.0.0.1:{}", port),
            plugin_path,
            started_at: Mutex::new(None),
        }
    }

    /// Find the source ai_service.py relative to the running exe
    fn find_source_plugin(app_dir: &PathBuf) -> Option<PathBuf> {
        let exe = std::env::current_exe().ok()?;
        let exe_dir = exe.parent()?;

        // Строим кандидатов с разной глубиной parent()
        // target/release/ → project root = 3 уровня: release→target→src-tauri→project
        let project_root = exe_dir
            .parent()?.parent()?.parent()?; // release → target → src-tauri → project
        let project_root2 = exe_dir
            .parent()?.parent()?.parent()?.parent()?; // запасной вариант (+1 уровень)

        let candidates = vec![
            // Относительно проекта (правильно: 3 уровня от release)
            project_root.join("plugins").join("ai_service.py"),
            // Запасной (+1 уровень)
            project_root2.join("plugins").join("ai_service.py"),
            // Рядом с exe (для bundled-сборки)
            exe_dir.join("plugins").join("ai_service.py"),
            // В app_data
            app_dir.join("plugins").join("ai_service.py"),
        ];

        for c in candidates {
            if c.exists() {
                log::info!("Found source AI plugin: {:?}", c);
                return Some(c);
            }
        }
        None
    }

    /// Start the Python service as a persistent background process
    pub fn start(&self) -> Result<(), String> {
        // Check if already running
        if self.is_healthy_sync() {
            log::info!("AI service already running on port {}", self.port);
            return Ok(());
        }

        // Check plugin exists
        if !self.plugin_path.exists() {
            let msg = format!("AI service plugin not found: {:?}", self.plugin_path);
            log::error!("{}", msg);
            return Err(msg);
        }

        // Find Python
        let python = Self::find_python()?;
        log::info!("Using Python: {}", python);

        // Build command
        let mut cmd = Command::new(&python);
        cmd.arg(self.plugin_path.to_str().unwrap_or_default())
            .env("AI_SERVICE_PORT", self.port.to_string())
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());

        // Run the Python service WITHOUT a visible console window on Windows.
        // Without this flag a PowerShell/cmd window pops up next to the app.
        #[cfg(windows)]
        {
            use std::os::windows::process::CommandExt;
            const CREATE_NO_WINDOW: u32 = 0x0800_0000;
            cmd.creation_flags(CREATE_NO_WINDOW);
        }

        log::info!("Starting AI service: {} {}", python, self.plugin_path.display());

        let mut child = cmd.spawn().map_err(|e| format!("Failed to start AI service: {}", e))?;

        // Read stderr in background for diagnostics
        if let Some(stderr) = child.stderr.take() {
            std::thread::spawn(move || {
                use std::io::Read;
                let mut reader = std::io::BufReader::new(stderr);
                let mut buf = [0u8; 1024];
                loop {
                    match reader.read(&mut buf) {
                        Ok(0) => break,
                        Ok(n) => {
                            let msg = String::from_utf8_lossy(&buf[..n]);
                            log::info!("[AI service stderr] {}", msg.trim());
                        }
                        Err(_) => break,
                    }
                }
            });
        }

        // Wait for it to become healthy
        let start = Instant::now();
        let timeout = Duration::from_secs(30);
        loop {
            if start.elapsed() > timeout {
                let _ = self.stop();
                return Err("AI service failed to start within 30 seconds".to_string());
            }
            std::thread::sleep(Duration::from_millis(500));
            if self.is_healthy_sync() {
                break;
            }
        }

        // Store child handle
        {
            let mut guard = self.child.lock().map_err(|e| e.to_string())?;
            *guard = Some(child);
        }
        {
            let mut guard = self.started_at.lock().map_err(|e| e.to_string())?;
            *guard = Some(Instant::now());
        }

        log::info!("AI service started on port {}", self.port);
        Ok(())
    }

    /// Stop the Python service
    pub fn stop(&self) -> Result<(), String> {
        let mut guard = self.child.lock().map_err(|e| e.to_string())?;
        if let Some(ref mut child) = *guard {
            let _ = child.kill();
            let _ = child.wait();
        }
        *guard = None;

        let mut guard = self.started_at.lock().map_err(|e| e.to_string())?;
        *guard = None;

        log::info!("AI service stopped");
        Ok(())
    }

    /// Check if service is healthy (synchronous, for startup polling)
    fn is_healthy_sync(&self) -> bool {
        let url = format!("{}/health", self.base_url);
        // Use std::net for simple sync check without reqwest::blocking
        match std::net::TcpStream::connect(format!("127.0.0.1:{}", self.port)) {
            Ok(_) => true,
            Err(_) => false,
        }
    }

    /// Check if service is healthy
    pub async fn is_healthy(&self) -> bool {
        let url = format!("{}/health", self.base_url);
        match reqwest::Client::builder()
            .timeout(Duration::from_secs(3))
            .build()
        {
            Ok(client) => match client.get(&url).send().await {
                Ok(resp) => resp.status().is_success(),
                Err(_) => false,
            },
            Err(_) => false,
        }
    }

    /// Call a service endpoint
    pub async fn call(
        &self,
        method: &str,
        path: &str,
        body: Option<&serde_json::Value>,
    ) -> Result<serde_json::Value, String> {
        let url = format!("{}{}", self.base_url, path);

        // Ensure service is running
        if !self.is_healthy().await {
            self.start()?;
        }

        let client = reqwest::Client::builder()
            .timeout(Duration::from_secs(120))
            .build()
            .map_err(|e| format!("HTTP client: {}", e))?;

        let mut req_builder = match method {
            "GET" => client.get(&url),
            "POST" => client.post(&url),
            _ => return Err(format!("Unsupported method: {}", method)),
        };

        if let Some(body) = body {
            req_builder = req_builder.json(body);
        }

        let response = req_builder.send().await
            .map_err(|e| format!("AI service request failed: {}", e))?;

        let status = response.status();
        let body_text = response.text().await
            .map_err(|e| format!("Failed to read AI service response: {}", e))?;

        if !status.is_success() {
            return Err(format!("AI service error {}: {}", status, body_text.chars().take(500).collect::<String>()));
        }

        serde_json::from_str(&body_text)
            .map_err(|e| format!("Invalid JSON from AI service: {} (body: {})", e, body_text.chars().take(200).collect::<String>()))
    }

    /// Get the base URL for external use
    pub fn base_url(&self) -> &str {
        &self.base_url
    }

    fn find_python() -> Result<String, String> {
        let candidates = ["python", "python3", "py"];
        for candidate in candidates {
            if Command::new(candidate)
                .arg("--version")
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .status()
                .is_ok()
            {
                return Ok(candidate.to_string());
            }
        }
        Err("Python not found on PATH".to_string())
    }
}

impl Drop for AiService {
    fn drop(&mut self) {
        let _ = self.stop();
    }
}
