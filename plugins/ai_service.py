"""
Open Notebook - AI Service (Python)
Persistent FastAPI server for operations that require Python:
  - Embeddings via Ollama HTTP API
  - Content extraction from URLs (trafilatura)
  - Text transformations via OpenAI-compatible API
  - Semantic search via cosine similarity

Launched by Rust backend on port 8421.
Minimal dependencies: fastapi, uvicorn, httpx, trafilatura
"""

import asyncio
import json
import logging
import math
import os
import sys
import tempfile
from typing import Optional

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger("ai_service")

app = FastAPI(title="Open Notebook AI Service", version="1.0.0")

# ---------------------------------------------------------------------------
# HTTP client (persistent connection pool)
# ---------------------------------------------------------------------------
_client: Optional[httpx.AsyncClient] = None


async def get_client() -> httpx.AsyncClient:
    global _client
    if _client is None or _client.is_closed:
        _client = httpx.AsyncClient(timeout=httpx.Timeout(120.0, connect=10.0))
    return _client


@app.on_event("shutdown")
async def shutdown_client():
    global _client
    if _client and not _client.is_closed:
        await _client.aclose()


# ===================================================================
# Request / Response models
# ===================================================================

class EmbedRequest(BaseModel):
    text: str
    model: str = "nomic-embed-text"
    ollama_url: str = "http://localhost:11434"


class EmbedResponse(BaseModel):
    embedding: list[float]
    model: str
    dimensions: int


class EmbedBatchRequest(BaseModel):
    texts: list[str]
    model: str = "nomic-embed-text"
    ollama_url: str = "http://localhost:11434"


class EmbedBatchResponse(BaseModel):
    embeddings: list[list[float]]
    model: str
    dimensions: int


class ExtractRequest(BaseModel):
    url: Optional[str] = None
    file_path: Optional[str] = None
    raw_html: Optional[str] = None


class ExtractResponse(BaseModel):
    title: Optional[str] = None
    text: Optional[str] = None
    error: Optional[str] = None


class TransformRequest(BaseModel):
    input_text: str
    prompt_template: str
    api_key: str = ""
    base_url: str = "http://localhost:11434/v1"
    model_name: str = "gemma3:4b"


class TransformResponse(BaseModel):
    output: str
    model: str


class SearchRequest(BaseModel):
    query_embedding: list[float]
    source_embeddings: list[dict]  # [{"id": "...", "embedding": [...], "text": "..."}]
    top_k: int = 10


class SearchResult(BaseModel):
    id: str
    text: str
    score: float


class SearchResponse(BaseModel):
    results: list[SearchResult]


class HealthResponse(BaseModel):
    status: str
    version: str
    python: str


# ===================================================================
# Health check
# ===================================================================

@app.get("/health", response_model=HealthResponse)
async def health():
    return HealthResponse(
        status="ok",
        version="1.0.0",
        python=f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}",
    )


# ===================================================================
# Embeddings
# ===================================================================

async def _call_ollama_embed(
    texts: list[str], model: str, ollama_url: str
) -> list[list[float]]:
    """Call Ollama /api/embed endpoint for embeddings."""
    client = await get_client()
    url = f"{ollama_url.rstrip('/')}/api/embed"

    # Ollama supports batch embed
    payload = {"model": model, "input": texts}

    try:
        resp = await client.post(url, json=payload)
        resp.raise_for_status()
        data = resp.json()
        embeddings = data.get("embeddings", [])
        if not embeddings:
            raise ValueError("Empty embeddings from Ollama")
        return embeddings
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=502, detail=f"Ollama embed error: {e.response.status_code} {e.response.text[:500]}")
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Ollama embed failed: {e}")


@app.post("/embed", response_model=EmbedResponse)
async def embed(req: EmbedRequest):
    """Generate embedding for a single text."""
    embeddings = await _call_ollama_embed([req.text], req.model, req.ollama_url)
    return EmbedResponse(
        embedding=embeddings[0],
        model=req.model,
        dimensions=len(embeddings[0]),
    )


@app.post("/embed/batch", response_model=EmbedBatchResponse)
async def embed_batch(req: EmbedBatchRequest):
    """Generate embeddings for multiple texts."""
    if not req.texts:
        return EmbedBatchResponse(embeddings=[], model=req.model, dimensions=0)

    all_embeddings = []
    # Batch in chunks of 64 to avoid overwhelming Ollama
    chunk_size = 64
    for i in range(0, len(req.texts), chunk_size):
        chunk = req.texts[i : i + chunk_size]
        batch = await _call_ollama_embed(chunk, req.model, req.ollama_url)
        all_embeddings.extend(batch)

    return EmbedBatchResponse(
        embeddings=all_embeddings,
        model=req.model,
        dimensions=len(all_embeddings[0]) if all_embeddings else 0,
    )


# ===================================================================
# Content extraction from URLs
# ===================================================================

@app.post("/extract", response_model=ExtractResponse)
async def extract(req: ExtractRequest):
    """Extract readable text from a URL or HTML."""
    try:
        import trafilatura
    except ImportError:
        return ExtractResponse(error="trafilatura not installed. Run: pip install trafilatura")

    try:
        if req.raw_html:
            text = trafilatura.extract(req.raw_html, include_links=False, include_tables=True)
            title = trafilatura.extract(
                req.raw_html,
                output_format="json",
                include_links=False,
                favor_precision=False,
            )
            # Try to get title from HTML
            title_text = None
            try:
                from html.parser import HTMLParser

                class TitleParser(HTMLParser):
                    def __init__(self):
                        super().__init__()
                        self.in_title = False
                        self.title = ""

                    def handle_starttag(self, tag, attrs):
                        if tag == "title":
                            self.in_title = True

                    def handle_endtag(self, tag):
                        if tag == "title":
                            self.in_title = False

                    def handle_data(self, data):
                        if self.in_title:
                            self.title += data

                tp = TitleParser()
                tp.feed(req.raw_html)
                title_text = tp.title.strip() if tp.title.strip() else None
            except Exception:
                pass

            return ExtractResponse(title=title_text, text=text)

        if req.url:
            client = await get_client()
            resp = await client.get(
                req.url,
                headers={"User-Agent": "Mozilla/5.0 (compatible; OpenNotebook/1.0)"},
                follow_redirects=True,
            )
            resp.raise_for_status()
            html = resp.text

            text = trafilatura.extract(
                html,
                include_links=False,
                include_tables=True,
                favor_recall=True,
            )

            # Extract title
            title_text = None
            try:
                from html.parser import HTMLParser

                class TitleParser2(HTMLParser):
                    def __init__(self):
                        super().__init__()
                        self.in_title = False
                        self.title = ""

                    def handle_starttag(self, tag, attrs):
                        if tag == "title":
                            self.in_title = True

                    def handle_endtag(self, tag):
                        if tag == "title":
                            self.in_title = False

                    def handle_data(self, data):
                        if self.in_title:
                            self.title += data

                tp2 = TitleParser2()
                tp2.feed(html)
                title_text = tp2.title.strip() if tp2.title.strip() else None
            except Exception:
                pass

            return ExtractResponse(title=title_text, text=text)

        if req.file_path:
            # Read local file
            path = os.path.abspath(req.file_path)
            if not os.path.exists(path):
                return ExtractResponse(error=f"File not found: {path}")

            with open(path, "r", encoding="utf-8", errors="replace") as f:
                content = f.read()

            text = trafilatura.extract(
                content,
                include_links=False,
                include_tables=True,
                favor_recall=True,
            )
            return ExtractResponse(text=text)

        return ExtractResponse(error="No url, file_path, or raw_html provided")

    except httpx.HTTPStatusError as e:
        return ExtractResponse(error=f"HTTP error: {e.response.status_code}")
    except Exception as e:
        return ExtractResponse(error=str(e))


# ===================================================================
# Text transformation via LLM
# ===================================================================

@app.post("/transform", response_model=TransformResponse)
async def transform(req: TransformRequest):
    """Apply a prompt template to input text via OpenAI-compatible API."""
    client = await get_client()

    url = f"{req.base_url.rstrip('/')}/chat/completions"

    messages = [
        {"role": "system", "content": req.prompt_template},
        {"role": "user", "content": req.input_text},
    ]

    payload = {
        "model": req.model_name,
        "messages": messages,
        "temperature": 0.3,
        "max_tokens": 4096,
    }

    headers = {}
    if req.api_key:
        headers["Authorization"] = f"Bearer {req.api_key}"

    try:
        resp = await client.post(url, json=payload, headers=headers)
        resp.raise_for_status()
        data = resp.json()
        content = data["choices"][0]["message"]["content"]
        return TransformResponse(output=content, model=req.model_name)
    except httpx.HTTPStatusError as e:
        raise HTTPException(
            status_code=502,
            detail=f"LLM API error: {e.response.status_code} {e.response.text[:500]}",
        )
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"LLM API failed: {e}")


# ===================================================================
# Semantic search (cosine similarity in pure Python)
# ===================================================================

def _cosine_similarity(a: list[float], b: list[float]) -> float:
    """Compute cosine similarity between two vectors."""
    dot = sum(x * y for x, y in zip(a, b))
    norm_a = math.sqrt(sum(x * x for x in a))
    norm_b = math.sqrt(sum(x * x for x in b))
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return dot / (norm_a * norm_b)


@app.post("/search", response_model=SearchResponse)
async def search(req: SearchRequest):
    """Find most similar embeddings to a query embedding."""
    scored = []
    for item in req.source_embeddings:
        emb = item.get("embedding", [])
        if not emb:
            continue
        score = _cosine_similarity(req.query_embedding, emb)
        scored.append(
            SearchResult(
                id=item.get("id", ""),
                text=item.get("text", ""),
                score=round(score, 6),
            )
        )

    scored.sort(key=lambda x: x.score, reverse=True)
    return SearchResponse(results=scored[: req.top_k])


# ===================================================================
# Split text into chunks (for embedding)
# ===================================================================

class ChunkRequest(BaseModel):
    text: str
    chunk_size: int = 1000
    chunk_overlap: int = 200


class ChunkResponse(BaseModel):
    chunks: list[str]
    count: int


@app.post("/chunk", response_model=ChunkResponse)
async def chunk_text(req: ChunkRequest):
    """Split text into overlapping chunks for embedding."""
    text = req.text
    if not text:
        return ChunkResponse(chunks=[], count=0)

    chunks = []
    start = 0
    while start < len(text):
        end = start + req.chunk_size
        chunk = text[start:end]
        if chunk.strip():
            chunks.append(chunk.strip())
        start += req.chunk_size - req.chunk_overlap
        if start + req.chunk_overlap >= len(text):
            break

    return ChunkResponse(chunks=chunks, count=len(chunks))


# ===================================================================
# Process source (full pipeline: extract -> chunk -> embed -> store)
# ===================================================================

class ProcessSourceRequest(BaseModel):
    source_id: str
    url: Optional[str] = None
    file_path: Optional[str] = None
    raw_text: Optional[str] = None
    embedding_model: str = "nomic-embed-text"
    ollama_url: str = "http://localhost:11434"
    chunk_size: int = 1000
    chunk_overlap: int = 200


class ProcessSourceResponse(BaseModel):
    source_id: str
    title: Optional[str] = None
    text_length: int
    chunks_count: int
    embedded: bool
    error: Optional[str] = None


@app.post("/process_source", response_model=ProcessSourceResponse)
async def process_source(req: ProcessSourceRequest):
    """Full pipeline: extract text, chunk, embed, return chunks with embeddings."""
    text = req.raw_text

    if not text and req.url:
        ext = await extract(ExtractRequest(url=req.url))
        if ext.error:
            return ProcessSourceResponse(
                source_id=req.source_id,
                text_length=0,
                chunks_count=0,
                embedded=False,
                error=ext.error,
            )
        text = ext.text
        if ext.title:
            # Update title in response (caller should use it)
            pass

    if not text and req.file_path:
        ext = await extract(ExtractRequest(file_path=req.file_path))
        if ext.error:
            return ProcessSourceResponse(
                source_id=req.source_id,
                text_length=0,
                chunks_count=0,
                embedded=False,
                error=ext.error,
            )
        text = ext.text

    if not text:
        return ProcessSourceResponse(
            source_id=req.source_id,
            text_length=0,
            chunks_count=0,
            embedded=False,
            error="No text content to process",
        )

    # Chunk
    chunk_resp = await chunk_text(
        ChunkRequest(text=text, chunk_size=req.chunk_size, chunk_overlap=req.chunk_overlap)
    )

    # Embed
    try:
        embed_resp = await embed_batch(
            EmbedBatchRequest(
                texts=chunk_resp.chunks,
                model=req.embedding_model,
                ollama_url=req.ollama_url,
            )
        )
        embedded = True
    except Exception as e:
        log.warning(f"Embedding failed: {e}")
        embedded = False

    return ProcessSourceResponse(
        source_id=req.source_id,
        text_length=len(text),
        chunks_count=chunk_resp.count,
        embedded=embedded,
    )


# ===================================================================
# Main
# ===================================================================

if __name__ == "__main__":
    import uvicorn

    port = int(os.environ.get("AI_SERVICE_PORT", "8421"))
    log.info(f"Starting Open Notebook AI Service on port {port}")
    uvicorn.run(app, host="127.0.0.1", port=port, log_level="info")
