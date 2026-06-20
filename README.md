# Open Notebook

**AI-ассистент для исследований с собственной базой знаний**

> Windows-порт (ветка `win`) оригинального проекта [lfnovo/open-notebook](https://github.com/lfnovo/open-notebook)

## Возможности

- Загружайте статьи, PDF, видео — AI анализирует содержание
- Создавайте заметки с автоматической векторизацией
- Ищите по собственной базе знаний семантически (не просто по словам)
- Генерируйте подкасты из материалов
- Работает полностью локально (данные не уходят в облако)

## Быстрый старт

### Требования

- Windows 10 / 11
- [SurrealDB](https://surrealdb.com/install) — установить через PowerShell (администратор):
  ```powershell
  iwr https://windows.surrealdb.com -useb | iex
  ```
- [uv](https://docs.astral.sh/uv/getting-started/installation/) — установить:
  ```powershell
  powershell -c "irm https://astral.sh/uv/install.ps1 | iex"
  ```
- [Node.js](https://nodejs.org/) — версия 18+

### Установка

```powershell
# 1. Клонировать репозиторий
git clone https://github.com/Zxcvb2521/open-notebook.git
cd open-notebook
git checkout win

# 2. Установить зависимости
.\install.bat

# 3. (Опционально) Создать ярлыки на рабочем столе
.\install-shortcuts.bat
```

### Запуск

```powershell
.\run.bat
```

Приложение запустится в собственном окне (Edge App Mode).  
Закрыли окно — все сервисы остановились.

Для ручной остановки:

```powershell
.\run.bat -stop
```

## Управление как Windows Service

Для автозапуска при старте системы (требуются права администратора):

```powershell
.\install-service.bat
```

После этого сервис будет запускаться автоматически.  
Управление: `net start OpenNotebook` / `net stop OpenNotebook`.

Удаление сервиса:

```powershell
.\uninstall-service.bat
```

## Файлы проекта

| Файл | Назначение |
|---|---|
| `run.bat` | **Основной запуск** — сервисы скрыты, своё окно |
| `start-all.bat` | Классический запуск (окна видны) |
| `install.bat` | Установка зависимостей |
| `uninstall.bat` | Полное удаление |
| `install-shortcuts.bat` | Ярлыки на рабочий стол |
| `install-service.bat` | Установка как Windows Service |
| `uninstall-service.bat` | Удаление Windows Service |

## Что внутри

Open Notebook состоит из 4 компонентов, которые запускаются автоматически:

1. **SurrealDB** — база данных (векторная + графовая)
2. **FastAPI** — REST API сервер
3. **Worker** — фоновые задачи (обработка источников, эмбеддинги)
4. **Frontend** — веб-интерфейс (Next.js)

Все компоненты запускаются скрыто и управляются из единого окна.

## Отличия Windows-версии

- ✅ Полностью нативный запуск (без Docker, без WSL)
- ✅ Все сервисы скрыты — не отвлекают
- ✅ Своё окно через Edge App Mode — не вкладка браузера
- ✅ Автоочистка — закрыл окно, всё остановилось
- ✅ Windows Service — автозапуск при старте системы
- ✅ Исправлены миграции для SurrealDB 3.x
- ✅ Русскоязычные сценарии установки и запуска
