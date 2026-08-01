use std::path::PathBuf;
use std::sync::Arc;
use super::service::AiService;

pub struct AIManager {
    pub service: Arc<AiService>,
}

impl AIManager {
    pub fn new(app_dir: PathBuf) -> Self {
        let service = Arc::new(AiService::new(app_dir));

        // Try to start the service in background
        if let Err(e) = service.start() {
            log::warn!("AI service not started (will auto-start on first use): {}", e);
        }

        Self { service }
    }

    /// Stop the Python AI service (called on app exit).
    pub fn stop(&self) {
        let _ = self.service.stop();
    }

    pub fn is_available(&self) -> bool {
        // Will auto-start on first call
        true
    }

    /// Call the Python AI service for embeddings
    pub async fn embed(
        &self,
        text: &str,
        model: &str,
        ollama_url: &str,
    ) -> Result<Vec<f64>, String> {
        let request = serde_json::json!({
            "text": text,
            "model": model,
            "ollama_url": ollama_url,
        });

        let response = self.service.call("POST", "/embed", Some(&request)).await?;

        response.get("embedding")
            .and_then(|v| v.as_array())
            .map(|arr| arr.iter().filter_map(|v| v.as_f64()).collect())
            .ok_or_else(|| "No embedding in response".to_string())
    }

    /// Batch embed multiple texts
    pub async fn embed_batch(
        &self,
        texts: &[String],
        model: &str,
        ollama_url: &str,
    ) -> Result<Vec<Vec<f64>>, String> {
        let request = serde_json::json!({
            "texts": texts,
            "model": model,
            "ollama_url": ollama_url,
        });

        let response = self.service.call("POST", "/embed/batch", Some(&request)).await?;

        response.get("embeddings")
            .and_then(|v| v.as_array())
            .map(|arr| {
                arr.iter()
                    .filter_map(|v| {
                        v.as_array().map(|a| a.iter().filter_map(|x| x.as_f64()).collect())
                    })
                    .collect()
            })
            .ok_or_else(|| "No embeddings in response".to_string())
    }

    /// Extract content from a URL using Python's trafilatura
    pub async fn extract_url(&self, url: &str) -> Result<(Option<String>, Option<String>), String> {
        let request = serde_json::json!({
            "url": url,
        });

        let response = self.service.call("POST", "/extract", Some(&request)).await?;

        if let Some(error) = response.get("error").and_then(|v| v.as_str()) {
            return Err(error.to_string());
        }

        let title = response.get("title").and_then(|v| v.as_str()).map(|s| s.to_string());
        let text = response.get("text").and_then(|v| v.as_str()).map(|s| s.to_string());

        Ok((title, text))
    }

    /// Extract content from a file
    pub async fn extract_file(&self, file_path: &str) -> Result<Option<String>, String> {
        let request = serde_json::json!({
            "file_path": file_path,
        });

        let response = self.service.call("POST", "/extract", Some(&request)).await?;

        if let Some(error) = response.get("error").and_then(|v| v.as_str()) {
            return Err(error.to_string());
        }

        Ok(response.get("text").and_then(|v| v.as_str()).map(|s| s.to_string()))
    }

    /// Apply a text transformation via LLM
    pub async fn transform(
        &self,
        input_text: &str,
        prompt_template: &str,
        api_key: &str,
        base_url: &str,
        model_name: &str,
    ) -> Result<String, String> {
        let request = serde_json::json!({
            "input_text": input_text,
            "prompt_template": prompt_template,
            "api_key": api_key,
            "base_url": base_url,
            "model_name": model_name,
        });

        let response = self.service.call("POST", "/transform", Some(&request)).await?;

        response.get("output")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string())
            .ok_or_else(|| "No output in transform response".to_string())
    }

    /// Split text into chunks for embedding
    pub async fn chunk_text(
        &self,
        text: &str,
        chunk_size: usize,
        chunk_overlap: usize,
    ) -> Result<Vec<String>, String> {
        let request = serde_json::json!({
            "text": text,
            "chunk_size": chunk_size,
            "chunk_overlap": chunk_overlap,
        });

        let response = self.service.call("POST", "/chunk", Some(&request)).await?;

        response.get("chunks")
            .and_then(|v| v.as_array())
            .map(|arr| arr.iter().filter_map(|v| v.as_str().map(|s| s.to_string())).collect())
            .ok_or_else(|| "No chunks in response".to_string())
    }

    /// Semantic search: find similar embeddings
    pub async fn search_embeddings(
        &self,
        query_embedding: &[f64],
        source_embeddings: &serde_json::Value,
        top_k: usize,
    ) -> Result<serde_json::Value, String> {
        let request = serde_json::json!({
            "query_embedding": query_embedding,
            "source_embeddings": source_embeddings,
            "top_k": top_k,
        });

        self.service.call("POST", "/search", Some(&request)).await
    }

    /// Full pipeline: extract -> chunk -> embed
    pub async fn process_source(
        &self,
        source_id: &str,
        url: Option<&str>,
        file_path: Option<&str>,
        raw_text: Option<&str>,
        embedding_model: &str,
        ollama_url: &str,
    ) -> Result<serde_json::Value, String> {
        let request = serde_json::json!({
            "source_id": source_id,
            "url": url,
            "file_path": file_path,
            "raw_text": raw_text,
            "embedding_model": embedding_model,
            "ollama_url": ollama_url,
        });

        self.service.call("POST", "/process_source", Some(&request)).await
    }
}
