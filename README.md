# Open Notebook

**AI-ассистент для исследований с собственной базой знаний**

> Windows-порт (ветка `win`) оригинального проекта [lfnovo/open-notebook](https://github.com/lfnovo/open-notebook) — автор: [Luis Novo](https://github.com/lfnovo)

## ⚠️ Важно

**Полноценный .exe установщик находится в разработке и пока не готов к использованию.**

**Рабочий вариант — `run.bat`** (см. инструкцию ниже).

## Быстрый старт (Windows)

### Требования

- Windows 10 / 11
- [SurrealDB](https://surrealdb.com/install): `iwr https://windows.surrealdb.com -useb | iex`
- [uv](https://docs.astral.sh/uv/): `powershell -c "irm https://astral.sh/uv/install.ps1 | iex"`
- [Node.js](https://nodejs.org/) версии 18+

### Установка

```powershell
git clone -b win https://github.com/Zxcvb2521/open-notebook.git
cd open-notebook
.\install.bat
```

### Запуск

```powershell
.\run.bat
```

Приложение запустится в собственном окне (Edge App Mode).  
Закрыли окно — все сервисы остановились.

```powershell
.\run.bat -stop    # ручная остановка
.\start-all.bat    # классический запуск (окна видны)
```

## Файлы проекта (Windows)

| Файл | Назначение |
|---|---|
| `run.bat` | **Основной запуск** — сервисы скрыты, своё окно |
| `start-all.bat` | Классический запуск (окна видны) |
| `install.bat` | Установка зависимостей |
| `uninstall.bat` | Полное удаление |
| `install-shortcuts.bat` | Ярлыки на рабочий стол |

## Технические детали (Windows)

Open Notebook состоит из 4 компонентов, запускаемых автоматически:
1. **SurrealDB** — векторная база данных
2. **FastAPI** — REST API
3. **Worker** — фоновые задачи
4. **Frontend** — веб-интерфейс (Next.js)

Все компоненты запускаются скрыто. Приложение открывается в собственном окне через Edge App Mode (не вкладка браузера).

---

# Оригинальный README

## Возможности

- **🔒 Privacy-First**: Your data stays under your control - no cloud dependencies
- **🎯 Multi-Notebook Organization**: Manage multiple research projects seamlessly
- **📚 Universal Content Support**: PDFs, videos, audio, web pages, Office docs, and more
- **🤖 Multi-Model AI Support**: 18+ providers including OpenAI, Anthropic, Ollama, Google, LM Studio, and more
- **🎙️ Professional Podcast Generation**: Advanced multi-speaker podcasts with Episode Profiles
- **🔍 Intelligent Search**: Full-text and vector search across all your content
- **💬 Context-Aware Chat**: AI conversations powered by your research materials
- **📝 AI-Assisted Notes**: Generate insights or write notes manually

### 📚 More Installation Options

- **[With Ollama (Free Local AI)](examples/docker-compose-ollama.yml)** - Run models locally without API costs
- **[From Source (Developers)](docs/1-INSTALLATION/from-source.md)** - For development and contributions
- **[Complete Installation Guide](docs/1-INSTALLATION/index.md)** - All deployment scenarios

---

### 📖 Need Help?

- **🤖 AI Installation Assistant**: [CustomGPT to help you install](https://chatgpt.com/g/g-68776e2765b48191bd1bae3f30212631-open-notebook-installation-assistant)
- **🆘 Troubleshooting**: [5-minute troubleshooting guide](docs/6-TROUBLESHOOTING/quick-fixes.md)
- **💬 Community Support**: [Discord Server](https://discord.gg/37XJPXfz2w)
- **🐛 Report Issues**: [GitHub Issues](https://github.com/Zxcvb2521/open-notebook/issues)

---

## Provider Support Matrix

Thanks to the [Esperanto](https://github.com/lfnovo/esperanto) library, we support this providers out of the box!

| Provider     | LLM Support | Embedding Support | Speech-to-Text | Text-to-Speech |
|--------------|-------------|------------------|----------------|----------------|
| OpenAI       | ✅          | ✅               | ✅             | ✅             |
| Anthropic    | ✅          | ❌               | ❌             | ❌             |
| Groq         | ✅          | ❌               | ✅             | ❌             |
| Google (GenAI) | ✅          | ✅               | ✅             | ✅             |
| Vertex AI    | ✅          | ✅               | ❌             | ✅             |
| Ollama       | ✅          | ✅               | ❌             | ❌             |
| Perplexity   | ✅          | ❌               | ❌             | ❌             |
| ElevenLabs   | ❌          | ❌               | ✅             | ✅             |
| Deepgram     | ❌          | ❌               | ❌             | ✅             |
| Azure OpenAI | ✅          | ✅               | ✅             | ✅             |
| Mistral      | ✅          | ✅               | ✅             | ✅             |
| DeepSeek     | ✅          | ❌               | ❌             | ❌             |
| Voyage       | ❌          | ✅               | ❌             | ❌             |
| xAI          | ✅          | ❌               | ❌             | ✅             |
| OpenRouter   | ✅          | ✅               | ❌             | ❌             |
| DashScope (Qwen) | ✅          | ❌               | ❌             | ❌             |
| MiniMax      | ✅          | ❌               | ❌             | ❌             |
| OpenAI Compatible* | ✅          | ✅               | ✅             | ✅             |

*Supports LM Studio and any OpenAI-compatible endpoint

## 📖 Documentation

- **[📖 Introduction](docs/0-START-HERE/index.md)**
- **[⚡ Quick Start with OpenAI](docs/0-START-HERE/quick-start-openai.md)**
- **[🔧 Installation](docs/1-INSTALLATION/index.md)**
- **[🎯 Run It Fully Local](docs/0-START-HERE/quick-start-local.md)**
- **[📱 Interface Overview](docs/3-USER-GUIDE/interface-overview.md)**
- **[📚 Notebooks, Sources & Notes](docs/2-CORE-CONCEPTS/notebooks-sources-notes.md)**
- **[💬 Chatting Effectively](docs/3-USER-GUIDE/chat-effectively.md)**
- **[🎙️ Podcast Generation](docs/2-CORE-CONCEPTS/podcasts-explained.md)**
- **[🤖 AI Models](docs/4-AI-PROVIDERS/index.md)**
- **[🔌 MCP Integration](docs/5-CONFIGURATION/mcp-integration.md)**
- **[🔐 Security](docs/5-CONFIGURATION/security.md)**

## 🤝 Community

- 💬 **[Discord Server](https://discord.gg/37XJPXfz2w)**
- 🐛 **[GitHub Issues](https://github.com/Zxcvb2521/open-notebook/issues)**

## 📄 License

MIT
