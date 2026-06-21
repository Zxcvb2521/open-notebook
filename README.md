# Open Notebook

**AI-ассистент для исследований с собственной базой знаний**

> Windows-порт (ветка `win`) оригинального проекта [lfnovo/open-notebook](https://github.com/lfnovo/open-notebook)

## ⚠️ Важно

**Полноценный .exe установщик находится в разработке и пока не готов к использованию.**

**Рабочий вариант — `run.bat`** (см. инструкцию ниже).

## Возможности

- Загружайте статьи, PDF, видео — AI анализирует содержание
- Создавайте заметки с автоматической векторизацией
- Ищите по собственной базе знаний семантически
- Генерируйте подкасты из материалов
- Работает полностью локально

## Быстрый старт

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

## Файлы проекта

| Файл | Назначение |
|---|---|
| `run.bat` | **Основной запуск** — сервисы скрыты, своё окно |
| `start-all.bat` | Классический запуск (окна видны) |
| `install.bat` | Установка зависимостей |
| `uninstall.bat` | Полное удаление |
| `install-shortcuts.bat` | Ярлыки на рабочий стол |

## Технические детали

Open Notebook состоит из 4 компонентов, запускаемых автоматически:
1. **SurrealDB** — векторная база данных
2. **FastAPI** — REST API
3. **Worker** — фоновые задачи
4. **Frontend** — веб-интерфейс (Next.js)

Все компоненты запускаются скрыто. Приложение открывается в собственном окне через Edge App Mode (не вкладка браузера).

## Лицензия

MIT
