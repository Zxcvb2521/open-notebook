# Open Notebook v1.13.0 — Windows (Native, No Docker)

## Описание релиза

**Open Notebook** — AI-ассистент для исследований с собственной базой знаний. Это нативная Windows-сборка оригинального проекта [lfnovo/open-notebook](https://github.com/lfnovo/open-notebook), запускаемая без Docker.

### Что нового в v1.13.0

**Новые провайдеры AI:**
- Cohere, Deepgram STT, PPQ, Novita, oMLX (Esperanto), Anthropic Compatible
- OpenRouter — поддержка Text-to-Speech и Speech-to-Text
- ElevenLabs — обновлённые модели в обнаружении

**Исправления:**
- Каскадное удаление чат-сессий при удалении ноутбука
- Исправлен IME-лаг в длинных диалогах
- Прокси не ломает внутренний SurrealDB WebSocket
- Модели корректно запоминаются после очистки
- Vertex credentials (project/location)

**Windows-специфичное:**
- 🚀 **Splash screen** — окно прогресса при запуске (больше не нужно гадать, запускается ли приложение)
- 🖥️ **Скрытый запуск** — `run-silent.vbs` запускает все сервисы без CMD окна
- 🔧 **Автозавершение** — при закрытии окна Edge все сервисы автоматически останавливаются
- 📦 **Portable** — автоматическое обнаружение путей к SurrealDB, uv, npm, Edge

### Зависимости
- [SurrealDB](https://surrealdb.com/) — установите и добавьте в PATH
- [uv](https://github.com/astral-sh/uv) — Python package manager
- [Node.js](https://nodejs.org/) 18+
- Microsoft Edge (для App Mode окна)

### Быстрый старт

1. Скачайте и распакуйте архив
2. Запустите `install.bat` (одноразово — установит зависимости)
3. Запустите `run-silent.vbs` — появится splash screen, затем окно приложения

### Альтернативные способы запуска

| Файл | Описание |
|------|----------|
| `run-silent.vbs` | 🌟 Тихий запуск с splash screen |
| `run.bat` | Интерактивный запуск с логами в консоли |
| `OpenNotebook.exe` | Standalone лаунчер (в папке `dist/`) |

### Структура проекта

```
Open_Notebook/
├── run-silent.vbs      ← Запуск без окон (рекомендуется)
├── run.bat             ← Запуск с логами
├── launch.ps1          ← Splash screen + старт сервисов
├── stop-watcher.ps1    ← Фоновый мониторинг Edge
├── install.bat         ← Установка зависимостей
├── update.bat          ← Обновление из GitHub
├── stop-all.ps1        ← Остановка всех сервисов
├── OpenNotebook.exe    ← Standalone лаунчер
├── frontend/           ← Next.js фронтенд
├── open_notebook/      ← Python бэкенд
├── api/                ← FastAPI endpoints
└── surreal_data/       ← База данных SurrealDB
```

### Обновление

Запустите `update.bat` — скрипт скачает последние изменения из GitHub и обновит зависимости.

### Лицензия

MIT License — как и оригинальный проект.

---

**Сборка для Windows:** [Zxcvb2521/open-notebook (ветка `win`)](https://github.com/Zxcvb2521/open-notebook/tree/win)
