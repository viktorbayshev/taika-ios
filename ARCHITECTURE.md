# taika — architecture contract

this doc is the **source of truth** for how we build taika.

## goals

- keep the codebase predictable, refactorable, and investor‑readable
- prevent “quick hacks” that break the design system and managers
- make cursor/ai coding safe by giving **hard boundaries**

## rules (moved to a separate file)

All coding rules, layer guardrails, and Cursor playbook now live in **RULES.md**.
ARCHITECTURE.md intentionally contains only architecture and technical debt.

---

## 9) AppShell contract — concrete behavior

## 9b) known tech debt (write down, do not "let ai guess")

this section exists to make cursor/ai changes safer. **ai will not reliably infer debt/intent from the codebase**, so we explicitly list what is "temporary", "legacy", or "to be refactored".

### course (CourseView / CourseDS)

- **no dedicated CourseManager yet** (logic is split across `CourseView` + `CourseNavigator` + `CourseSearch`).
  - impact: cursor may push more business logic into views.
  - rule: until `CourseManager` exists, keep business decisions in helper subsystems (`CourseNavigator`, `CourseSearch`) and keep `CourseView` as wiring only.

- **CourseDS contains a large legacy internal styling surface (`CD*` components).**
  - impact: risk of growing a second design system inside Course.
  - rule: new visuals should be expressed via `CardDS` + `AppDS`; only touch `CD*` when removing legacy code.

### navigation

- `AppShell.navigationDestination` currently handles **only** `.lessons(courseId:)`.
  - impact: `.lesson(courseId:lessonId:)` routes can fall back to the dev “missing destination” screen.
  - release requirement: implement remaining destinations or remove unused routes from `NavigationIntent.Route`.

### speaker (v0 / free version)

- verdict pipeline is **v0/stubbed** (no external ai integration).
  - requirement: verdict must be based on measurable similarity (recognized text vs reference), not UI state.
  - requirement: persist successful attempts (per phrase) so cards don’t reset to “empty” after leaving the screen.

### indices & progress

- confirm the **0-based index contract** end-to-end:
  - `steps.json` → `StepData` → `ProgressManager.learnedSteps` → `UserSession.lastStepByLesson` → `SpeakerManager` queue building.
  - impact: off-by-one breaks speaker queue and learned tracking.

### previews / swiftui stability

- `ForEach` must use stable **unique** ids. duplicates will break Previews (`SwiftUICore: Invalid Configuration`).
  - rule: never generate ids at render time; ids must come from models.

### tabs (root screens)
- **tab 0 — Main** → `MainView()`
- **tab 1 — Courses** → `CourseView()` (root of course flow)
- **tab 2 — Speaker** → conditional:
  - if `ProManager.isPro == true` → `SpeakerView()`
  - else → `PROView(courseId: "__speaker__")`, and on close the app returns to tab 0.
- **tab 3 — Favorites** → `FavoriteView()`
- **tab 4 — Profile** → `ProfileView()`

### navigation stack ownership
- `AppShell` is the **only** owner of `NavigationStack(path: $nav.path)`.
- No feature view creates its own `NavigationStack`.
- All navigation must go through `NavigationIntent`.

### tab switching rule (hard)
- When `selectedTab` changes, `nav.path` **must be cleared** (`nav.reset()` or equivalent).
- Tab change behaves like “go to root of that tab”.

### header behavior
- If `nav.path.isEmpty` → show `AppHeader`.
- If `nav.path.notEmpty` → show `AppBackHeader` (pop last route).
- Any screen may hide the header via `.shellHeaderHidden(true)` preference.
- Preference rule: **last writer wins**; affects both root tabs and pushed routes.

### injected environment objects (singletons)
- `ThemeManager.shared`
- `FavoriteManager.shared`
- `OverlayPresenter.shared`
- `NavigationIntent.shared`
- `ProManager.shared`

### preload contract
- On first appear, `AppShell` must start detached tasks for:
  - `StepData.shared.preload()`
  - `LessonsData.shared.preload()`
- Preload must not block UI rendering.

### overlay pattern
- All full-screen modals should prefer `OverlayPresenter` pattern (blur + dim + glass card) instead of bottom sheets.

## 10) open questions to finalize (fill later)

- loaders for course packs (exact entry points + which folder is the canonical source at runtime)
- app shell → session bootstrap: where `UserSession` is created and where `ProManager.start(session:)` is called
- `AppShell.navigationDestination` coverage: implement destinations for `.lesson(...)` / `.course(...)` or remove unused routes from `Route`
- speaker v0 without integration: define the exact “verdict” contract + persistence (what we store, where we store it)
- index contract audit: confirm 0-based indices across `steps.json` → `StepData` → `ProgressManager` → `SpeakerManager`

---
## 🇷🇺 архитектура taika (русская версия)

### цель документа

Этот файл — **единый источник правды** о том, как мы строим приложение taika.

### главные принципы (жёсткие правила)

1. **DS рисует весь UI.**  
   Все визуальные компоненты живут в `*DS.swift`. Там нет логики, навигации и сохранения данных.

2. **View только собирает экран.**  
   `*View.swift` связывает DS с менеджерами и передаёт события пользователя.

3. **Manager владеет логикой.**  
   В `*Manager.swift` решается, *что должно произойти* и как меняется состояние.

4. **Data — только модели.**  
   `*Data.swift` содержит структуры, decoding и идентификаторы.

5. **Один источник правды.**  
   Никаких дублирующих кэшей и скрытого состояния во View.

6. **Нет дублирования DS.**  
   Все визуальные паттерны живут в `Theme/` и переиспользуются.

7. **Тяжёлые вычисления — вне ViewBuilder.**  
   Фильтры, сортировки и маппинги делаем в Manager.

8. **Нет навигации по тапу на всю карточку.**  
   Только через явные действия (`onPrimaryTap`, кнопки).

9. **Никаких дебаг-маркеров и мёртвого кода.**

---

### структура репозитория

- `taika/` — корень Xcode-проекта и исходный код
- `steps/`, `lessons/`, `taikafm/`, `taika_basa_course/` — контент и JSON-паки курсов
- `DOCS/` — продуктовая и техническая документация

Внутри `taika/` код разбит по модулям:

- `Theme/` — дизайн-система и оболочка приложения
- `Main/` — главный экран
- `Course/` — список курсов
- `Lessons/` — список уроков
- `Steps/` — карточки шагов
- `HomeTask/` — игры и домашки
- `Favorites/` — избранное
- `Profile/` — профиль и статистика
- `PRO/` — подписка и платные фичи
- `Speaker/` — произношение
- `Session/` — сессия пользователя и прогресс
- `Resources/` — контент и общие ресурсы
- `Welcome/` — онбординг

---

### паттерн работы фичи

Каждая фича следует цепочке:

**Data → Manager → View → DS**

- Data: модели и идентификаторы
- Manager: бизнес-логика и состояние
- View: сборка экрана и проброс событий
- DS: чистый визуал без логики

---

### ключевые модули

**курсы → уроки → шаги**
- `CourseData`, `LessonsData`, `StepData`
- `CourseManager`, `LessonsManager`, `StepManager`
- `CourseView`, `LessonsView`, `StepView`
- `CourseDS`, `LessonsDS`, `StepDS`

**компонент course (текущая реализация / файлы)**

- `CourseData.swift` — `CourseData.shared`, читает `taika_basa_course.json` из бандла; декодинг устойчив к строкам вместо чисел/булей.
- `CourseNavigator.swift` — порядок курсов/уроков и переходы next/end; уроки ищем по шаблону `"{courseId}_l{n}"`, `n=1...99`, дырки до первого найденного пропускаем, после — стоп на первом пропуске.
- `CourseSearch.swift` — локальный поиск по курсам/урокам (скоринг: title > subtitle > description), без сохранения и сайд‑эффектов.
- `CourseAnimation.swift` — хелперы анимаций; хранит `lastOpenedCourseId` в `UserDefaults`.
- `CourseDS.swift` — визуал экрана курсов; файл большой и местами «внутренняя мини‑дс» (CD*). новые паттерны НЕ добавляем — постепенно сводим к `CardDS` и `AppDS`.
- `CourseView.swift` — сборка и wiring; никаких тяжёлых маппингов внутри `ViewBuilder`.

**speaker (произношение)**
- `SpeakerManager` — состояние и вердикт
- `SpeakerRecorder` — запись аудио
- `SpeakerAPI` — анализ (может быть заглушкой)
- `SpeakerView` — сборка экрана
- `SpeakerDS` — визуал

**app shell (корень приложения)**
- `AppShell` — единственное место, где живёт `NavigationStack` и таббар.
- `NavigationIntent.path` — стек навигации.
- правило: при смене таба стек очищается.
- хедер: на корне (`path` пустой) — `AppHeader`, внутри навигации — `AppBackHeader`.
- экраны могут скрывать хедер через `.shellHeaderHidden(true)`.

**Theme (дизайн-система)**
- `ThemeDesign` — базовые токены (отступы, радиусы, шрифты, тени, материалы).
- `AppDS` — атомарные UI-элементы (кнопки, чипы, иконки, типографика, заливки).
- `CardDS` — шаблоны карточек (курсы, уроки, шаги, мини-прогресс).
- правило: любые новые элементы сначала появляются в DS, а уже потом используются во View.

---

### состояние speaker (коротко)

- `idle` — можно слушать эталон и начать запись
- `recording` — идёт запись
- `analyzing` — анализ аудио
- `result` — показ результата

Правило: **только Manager меняет фазу.**

---

### работа с Cursor

При кодинге в Cursor:

1. сначала выбираем слой (DS / View / Manager / Data)
2. правим только в своём слое
3. делаем микро-патчи
4. не создаём новые файлы без согласования
5. выносим сложные View в подкомпоненты
6. в `ForEach` — только стабильные уникальные ID
7. не оставляем в коде мусорные маркеры типа `` и временный дебаг (`print`) — удаляем сразу

---

### git-процесс (минимальный)

- новая ветка на каждый эпик:
  `feature/<epic-name>`
- маленькие коммиты:
  - `speaker: fix queue`
  - `speaker-ds: simplify player panel`
- merge в `main` через PR.

---

### техдолг (фиксируем явно, ai сам не догадается)

этот блок нужен, чтобы cursor/ai **не придумывал архитектуру по коду** и не разносил костыли дальше.

**course (CourseView / CourseDS)**

- **отдельного `CourseManager` пока нет** — логика разнесена между `CourseView` + `CourseNavigator` + `CourseSearch`.
  - риск: cursor будет пихать бизнес-логику во view.
  - правило: пока нет `CourseManager`, бизнес-решения держим в хелперах (`CourseNavigator`, `CourseSearch`), а `CourseView` — только wiring.

- **в `CourseDS` много легаси-компонентов `CD*` (мини-дс внутри course).**
  - риск: разрастание второй дизайн-системы.
  - правило: новые паттерны выражаем через `CardDS` + `AppDS`; `CD*` трогаем только чтобы убирать легаси.

**навигация**

- `AppShell.navigationDestination` сейчас обрабатывает **только** `.lessons(courseId:)`.
  - риск: `.lesson(courseId:lessonId:)` падает в dev-экран “missing destination”.
  - к релизу: либо добавить destinations, либо удалить неиспользуемые route’ы.

**speaker (v0 / free версия)**

- пайплайн вердикта сейчас **v0/заглушка** (без внешней ai-интеграции).
  - требование: verdict должен считаться по измеримой похожести (recognized text vs reference), а не по состоянию ui.
  - требование: сохранять успешные попытки по фразам, чтобы карточки не сбрасывались в “пусто” после выхода со спикера.

**индексы и прогресс**

- подтвердить контракт **0-based индексов** сквозняком:
  - `steps.json` → `StepData` → `ProgressManager.learnedSteps` → `UserSession.lastStepByLesson` → очередь `SpeakerManager`.
  - риск: off-by-one ломает очередь и learned.

**swiftui previews / стабильность**

- `ForEach` обязан иметь стабильные **уникальные** id. дубли ломают канву (SwiftUICore: Invalid Configuration).
  - правило: не генерировать id в рендере; id только из моделей.

---
