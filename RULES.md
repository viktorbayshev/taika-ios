# taika — development rules (guardrails)

## core architecture contract

1) **ds owns all visuals**  
   - design system (appds, cardds, courseds, speakerds) draws every pixel.  
   - no ui styling or “mini-ds” inside views.

2) **view = assembly + wiring only**  
   - views assemble components, wire state, and handle navigation.  
   - no business logic in views.

3) **managers = business logic + state**  
   - all domain rules, transformations, queues, and persistence live in managers.

4) **single source per component**  
   - one canonical ds implementation per ui element.  
   - no visual duplicates in other layers.

5) **precompute before viewbuilder**  
   - derive data outside body / viewbuilder.  
   - views receive ready-to-render models.

6) **navigation rule**  
   - primary cta triggers navigation **only via onPrimaryTap**.  
   - no full-card navigation gestures.

7) **no debug artifacts in production code**  
   - no markers like , prints, or temporary hacks in main.

8) **micro-patches by default**  
   - prefer small, focused changes over big rewrites.  
   - one task → one commit.

9) **layer discipline**  
   - if a change belongs to another layer, stop and move it there.  
   - never “quick fix in view just to make it work.”

10) **preview safety**  
   - previews must be lightweight and stable.  
   - avoid heavy tasks, network, or long animations in #Preview.

11) **naming discipline**  
   - clear, consistent names; avoid abbreviations unless project-standard.

12) **composition over duplication**  
   - reuse ds components; extract instead of copy-paste.

13) **testing mindset**  
   - every logic change should be manually verifiable on device.

14) **honesty rule**  
   - never claim a fix is done if behavior is uncertain or partially working.

---
## speaker-specific guardrails

- **speaker manager = source of truth** for current lesson, queue, and phase.
- **recorder contract**: `start()` must either return a valid url or a clear error.
- **verdict logic lives in manager**, not in ds or view.
- **ds shows state; it never decides it.**

---

## workflow

- cursor → code changes  
- xcode → build + canvas + simulator check  
- git → commit per task  
- github → push after each meaningful step.

---
## cursor playbook (how to brief cursor)

When starting any Cursor session, paste these two files first:
- `ARCHITECTURE.md`
- `RULES.md`

Then say explicitly:
> "Follow ARCHITECTURE.md as the system design and RULES.md as non‑negotiable guardrails. Do not invent new patterns outside them."

### what cursor is allowed to change
- files inside the **relevant module only** (e.g., Speaker changes stay within Speaker/*).  
- ds files **only for visuals**; manager files **only for logic**; views **only for wiring**.
- small, incremental patches (micro-patches).

### what cursor must never do
- move business logic into views or ds.
- style UI directly inside views.
- generate random UUIDs in render paths.
- add temporary prints/markers and leave them behind.
- refactor multiple modules in one change.

### how to request changes from cursor
Use one of these templates:
- **Fix:** "Apply a micro-patch in <File.swift> that does X. Do not touch other files."
- **Design:** "Change visuals only in <DS file>. Keep public contracts intact."
- **Logic:** "Change behavior only in <Manager.swift>. Views/DS untouched."

---
## git workflow (strict)

- work on a short-lived feature branch:
  `git checkout -b feat/<task>` or `fix/<task>`
- one logical task = one commit.
- commit message format:
  `type(scope): short description`
  examples:
  - `fix(speaker): stabilize recorder start()`
  - `feat(course): add nextLesson advance rule`
- push after each meaningful step:
  `git push -u origin <branch>`
- keep `main` always buildable.

---
## preview & build hygiene

- if Xcode canvas freezes:
  1) clean build folder: **Product → Clean Build Folder**
  2) restart Xcode
  3) reopen the file with #Preview
- never rely on Previews alone — always verify on simulator/device.

---
## ids & collections (non-negotiable)

- every `ForEach` must use a **stable model id** that lives in data (not generated in view).
- duplicates are a bug and must be fixed in the data source or manager, not hidden in the view.

---
## ownership map (quick guide for cursor)

- **Theme / AppDS / CardDS** → visuals only
- **Course / Lessons / Steps / Speaker Managers** → business logic + queues + persistence
- **Views (CourseView, LessonsView, StepView, SpeakerView)** → wiring + navigation only
- **AppShell / NavigationIntent** → routing only

---
## files guidance for cursor (what is safe vs high-risk)

### usually safe to touch (with micro‑patches)
- **Speaker/**
  - SpeakerManager.swift
  - SpeakerRecorder.swift
  - SpeakerDS.swift (visuals only)
  - SpeakerView.swift (wiring only)
- **Course/**
  - CourseView.swift (wiring only)
  - CourseDS.swift (visuals only)
  - CourseNavigator.swift
  - CourseSearch.swift
- **Lessons/**
  - LessonsManager.swift
  - LessonsView.swift (wiring only)
- **Steps/**
  - StepManager.swift
  - StepView.swift (wiring only)
- **Theme/**
  - AppDS.swift, CardDS.swift, ThemeDesign.swift (visuals only)

### high-risk files (change only with explicit instruction)
- AppShell.swift
- NavigationIntent.swift
- UserSession.swift
- ProgressManager.swift
- ProManager.swift
- OverlayPresenter.swift
- StepData.swift

### rule for high-risk files
- changes must be **tiny, justified, and reviewed in isolation**;
- never mix with unrelated fixes;
- prefer 1 file = 1 commit.