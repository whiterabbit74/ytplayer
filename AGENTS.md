# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Communication

Всегда отвечай на русском языке.

## Проект

MusicPlay — персональный веб-плеер для YouTube. Не для широкой аудитории.

## MCP серверы

- **context7** — актуальная документация библиотек. Используй `use context7` при работе с библиотеками.
- **pencil** — визуальный дизайн прямо в IDE (Pencil.dev). Используй для макетов и прототипов.

## Команда (агенты)

Вызывай нужного агента через slash-команду:

| Команда | Роль | Зона ответственности |
|---------|------|---------------------|
| `/frontend` | Фронтенд-разработчик | React, TypeScript, Tailwind, shadcn/ui, YouTube IFrame API |
| `/backend` | Бэкенд-разработчик | Node.js, API, YouTube Data API, БД, авторизация |
| `/tester` | QA-инженер | Vitest, Playwright, тест-планы, поиск багов |
| `/pm` | Проджект-менеджер | Декомпозиция, приоритизация, координация, бэклог |
| `/designer` | UI/UX дизайнер | Макеты в Pencil, дизайн-система, темы, UX-флоу |
| `/devops` | DevOps-инженер | Docker, CI/CD, сборка, деплой, инфраструктура |
| `/architect` | Архитектор / Тех.лид | Архитектура, код-ревью, технические решения, ADR |

Каждый агент имеет набор скилов из skills.sh (`.agents/skills/`) и самостоятельно решает, когда их использовать.

## i18n (мультиязычность)

- Легковесная своя реализация: React Context + типизированные JSON-файлы
- Языки: русский (по умолчанию), казахский, английский
- Файлы: `client/src/i18n/` — `types.ts`, `index.ts`, `I18nProvider.tsx`, `locales/{ru,en,kk}.ts`
- Хук: `useTranslation()` возвращает `{ t, locale, setLocale }`
- Плюрализация: суффиксы `_one/_few/_many`, функция `pluralize()`
- Интерполяция: `{{key}}` в строках
- Определение языка: localStorage → navigator.language → "ru"
- UI: компонент `LanguageSwitcher.tsx` (флаг + DropdownMenu)

## Скилы (skills.sh)

Установлены в `.agents/skills/`. Ключевые по ролям:

**Фронтенд:** vercel-react-best-practices, react-dev, react-patterns, shadcn-ui, tailwind-css-patterns, responsive-design, frontend-design
**Бэкенд:** nodejs-backend-patterns, api-design-principles, database-schema-designer, auth-implementation-patterns, error-handling-patterns
**Тестирование:** webapp-testing, qa-test-planner, e2e-testing-patterns, javascript-testing-patterns
**Дизайн:** visual-design-foundations, interaction-design, design-system-patterns, canvas-design, theme-factory
**DevOps:** deployment-pipeline-design, github-actions-templates, gitops-workflow, secrets-management
**Архитектура:** architecture-patterns, c4-architecture, code-review-excellence, security-review
