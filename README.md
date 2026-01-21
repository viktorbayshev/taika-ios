# taika — thai language learning app (ios)

---
## 🇬🇧 english

### overview

taika is an ai-assisted app for learning thai, designed primarily for russian-speaking users who want practical, spoken thai with a modern, minimal, and playful experience.

the product combines structured courses, step-based drills, and an experimental **speaker** feature that allows users to record their pronunciation and compare it with a native reference.

### positioning

taika is positioned as a **hybrid between a language course and an audio product** — closer to spotify/apple music in feel than to a traditional textbook.

it is not just “learn thai” — it is **learn thai by speaking, listening, and playing with sound**, in a beautiful, calm, and highly polished interface.

key positioning pillars:
- conversation-first (speech over grammar)
- audio-first (sound as the main learning medium)
- mobile-first (designed for daily micro-sessions)
- design-first (clean, minimal, consistent ui)
- nomad-friendly (useful for real life in thailand)

### competitors (honest landscape)
main references we compare ourselves to:
- **utalk** — strong audio-based learning, very good UX, but feels rigid, corporate, and repetitive over time.
- **duolingo** — great gamification, but weak spoken thai, slow progression, and shallow real-life utility.
- **pimsleur** — excellent audio pedagogy, but old-school UI and not mobile-native in experience.
- **hello talk / tandem** — great for practice with people, but chaotic and not structured for beginners.

### why taika is better (our edge)
compared to competitors, taika aims to be:
- more **beautiful and cohesive** in visual identity
- more **focused on real spoken thai**
- more **modern in audio interaction** (speaker + player-like experience)
- more **friendly to russian-speaking users**
- more **integrated with thai culture and lifestyle**

### unique features (our “secret sauce”)
- **speaker mode** — record, compare, and train pronunciation directly on each step.
- **player-like interaction** — treat phrases like tracks in a music app.
- **json-driven curriculum** — flexible, expandable, and easy to evolve.
- **custom design system** — consistent visuals across cards, courses, and speaker.
- **free vs pro balance** — core learning free; advanced tools and games for pro.

### vision
- teach usable spoken thai, not grammar for its own sake
- feel more like a music or audio product than a textbook
- keep the interface simple, stylish, and consistent with a custom design system
- support both free and pro usage modes

### tech stack
- swift + swiftui
- json-driven content (courses, lessons, steps)
- modular design system (appds, cardds, courseds, speakerds)
- manager layer for business logic and state
- git + github for version control

### documentation (source of truth)
- `ARCHITECTURE.md` — app architecture + module contracts + known tech debt.
- `RULES.md` — non‑negotiable guardrails + cursor playbook + safe/high‑risk files.

when working with cursor, always provide both files first.

### project structure (high level)
```
taika/
  ├── taika/                # main app source
  │   ├── theme/            # design system (ds)
  │   ├── course/           # courses + lessons ui
  │   ├── speaker/          # pronunciation feature
  │   ├── session/          # user state & persistence
  │   └── data/             # json content
  └── taika.xcodeproj
```

### how to run locally
1. open `taika.xcodeproj` in xcode.
2. select an iphone simulator (ios 18.2 recommended).
3. press **run**.
4. for swiftui previews, ensure command line tools are set to:
   `/applications/xcode.app/contents/developer`
5. if previews freeze, see RULES.md → preview & build hygiene.

### status
- mvp in active development
- core learning flow mostly complete
- speaker feature under refinement
- pro features and games still in progress

---
## 🇷🇺 русский

### обзор проекта

taika — это приложение с элементами ai для изучения тайского языка, ориентированное прежде всего на русскоязычных пользователей, которым важен живой разговорный тайский, современный минималистичный дизайн и лёгкий игровой опыт.

продукт сочетает структурированные курсы, пошаговые упражнения и экспериментальную функцию **speaker**, которая позволяет записывать своё произношение и сравнивать его с эталонной записью носителя языка.

### позиционирование

taika позиционируется как **гибрид языкового курса и аудио-продукта** — ближе к spotify/apple music по ощущению, чем к классическому учебнику.

это не просто «учим тайский» — это **учим тайский через речь, звук и игру с аудио**, в красивом, спокойном и продуманном интерфейсе.

ключевые столпы позиционирования:
- разговор прежде всего (речь важнее грамматики)
- звук как основной носитель обучения
- мобильность и короткие ежедневные сессии
- сильный дизайн и айдентика
- полезность для реальной жизни в таиланде

### конкуренты (честный взгляд)
наши главные ориентиры и сравнения:
- **utalk** — очень сильный аудио-подход и удобство, но ощущается жёстким, корпоративным и однообразным.
- **duolingo** — отличная геймификация, но слабый разговорный тайский и медленный прогресс.
- **pimsleur** — мощная методика аудио-обучения, но устаревший интерфейс.
- **hello talk / tandem** — полезно для практики с людьми, но хаотично и неструктурированно для новичков.

### почему taika лучше (наше преимущество)
по сравнению с конкурентами мы стремимся быть:
- более **эстетичными и цельными** визуально
- более **заточенными под живой разговорный тайский**
- более **современными в работе со звуком** (speaker + плеерный опыт)
- более **удобными для русскоязычных пользователей**
- более **интегрированными в тайскую культуру и образ жизни**

### наши фишки
- **speaker mode** — запись и тренировка произношения прямо внутри шага.
- **плеерный опыт** — фразы ощущаются как треки в музыкальном приложении.
- **гибкая программа на json** — легко масштабировать и обновлять.
- **собственная дизайн-система** — единый стиль карточек, курсов и спикера.
- **баланс free/pro** — базовое обучение бесплатно, продвинутые инструменты и игры — для pro.

### видение
- учить **живому разговорному тайскому**, а не академической грамматике ради грамматики
- ощущаться скорее как аудио-продукт (плеер, музыка, звук), чем как учебник
- сохранять простой, стильный и последовательный дизайн на базе собственной дизайн-системы
- поддерживать режимы **free** и **pro**

### технологии
- swift + swiftui
- контент в json (курсы, уроки, шаги)
- модульная дизайн-система (appds, cardds, courseds, speakerds)
- слой менеджеров для бизнес-логики и состояния
- git + github для контроля версий

### документация (источник правды)
- `ARCHITECTURE.md` — архитектура приложения + контракты модулей + техдолг.
- `RULES.md` — жёсткие правила + playbook для cursor + список safe/high‑risk файлов.

при работе в cursor всегда сначала передаём оба файла.

### структура проекта (высокий уровень)
```
taika/
  ├── taika/                # основной код приложения
  │   ├── theme/            # дизайн-система (ds)
  │   ├── course/           # ui курсов и уроков
  │   ├── speaker/          # модуль произношения
  │   ├── session/          # состояние пользователя
  │   └── data/             # контент в json
  └── taika.xcodeproj
```

### как запустить локально
1. открыть `taika.xcodeproj` в xcode.
2. выбрать любой iphone-симулятор (рекомендуется ios 18.2).
3. нажать **run**.
4. для корректной работы swiftui previews убедиться, что command line tools указывают на:
   `/applications/xcode.app/contents/developer`
5. если канва зависает — см. RULES.md → preview & build hygiene.

### статус
- mvp активно разрабатывается
- основной учебный поток почти готов
- функция speaker находится в доработке
- игры и pro-функции в процессе реализации

---
## contact / контакты
created by viktor bayshev.