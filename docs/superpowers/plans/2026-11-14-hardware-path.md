# Hardware Path Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A public git repo of Org files holding a 36-week hardware curriculum with progress tracking, published to GitHub Pages as a site with a progress dashboard.

**Architecture:** Org files in `plan/` are the only source of truth. `publish.el` (Emacs Lisp, run in batch) exports them with `org-publish` and generates `index.html` from week TODO states and `Build` checkboxes. A GitHub Action runs the same build and deploys to Pages; `make site` does it locally.

**Tech Stack:** Emacs 31 locally / Emacs 30.1 in CI, Org mode (`ox-html`, `ox-publish`), ERT for tests, GNU Make, GitHub Actions (`purcell/setup-emacs`, `actions/upload-pages-artifact`, `actions/deploy-pages`), plain CSS.

**Spec:** `docs/superpowers/specs/2026-11-14-hardware-path-design.md`

## Global Constraints

- Org is the single source of truth; the site never needs data not in the Org files.
- Each phase file starts with `#+TODO: TODO DOING | DONE SKIPPED`.
- Week = top-level heading `* <STATE> Week N: <title>` with a `:PROPERTIES:` drawer containing `:WEEK: N`, `:CUSTOM_ID: week-NN` (two-digit), and `:OPTIONAL: t` only for optional weeks. No cookie on the week heading.
- Week subheadings, in order, none with TODO states: `** Learn`, `** Build [/]`, `** Parts`, `** Checkpoint`, `** Notes`. `Notes` has four `***` children: `Expected`, `Measured`, `Different and why`, `Next`.
- `Checkpoint` = question, then `#+begin_details` … `#+end_details` whose first line is `#+html: <summary>Check your answer</summary>`.
- Each phase file ends with `* Phase review` (no TODO state) of "Can you…?" questions.
- `plan/09-capstone.org` has no TODO keywords and no checkboxes.
- Progress: weeks done = DONE count; total = weeks minus SKIPPED. Current week = first DOING, else first TODO, in file then heading order. Next action = first unticked `- [ ]` under that week's `Build`.
- Learn sections: short framing paragraph + specific named sources (spec "Depth"). Every URL must resolve (HTTP 2xx/3xx).
- Board: Raspberry Pi Pico 2 WH. No branded kit assumed. Parts listed per week; note 3.3 V compatibility.
- `org-html-html5-fancy` = t, `org-html-doctype` = "html5". No JS frameworks. CSS supports light and dark (`prefers-color-scheme`) and phone width.
- Week numbering and phases exactly as the spec's Curriculum section (36 weeks; phase 5 = 20–25, 6 = 26–28, 7 = 29–32, 8 = 33–36).
- Commits: no `Co-Authored-By` trailer, no "Generated with Claude" line (user's global instruction).
- Public repo `systemhalted/hardware-path`, default branch `main`.

## Review Focus

1. A week whose `Build` has no unticked items while its state is TODO → next action shows "Mark this week DONE" rather than nothing or an error. (Task 1 test `hp-next-action-all-ticked`.)
2. Every week DONE/SKIPPED → dashboard shows a "Plan complete" state, no current-week card, no error. (Task 2 test `hp-dashboard-complete`.)
3. A DOING week after an earlier TODO week → the DOING week is current. (Task 1 test `hp-current-week-prefers-doing`.)
4. Non-week top-level headings (`Phase review`, intro text) and `09-capstone.org` → never counted. (Task 1 test `hp-collect-ignores-non-weeks`.)
5. Titles containing `&`, `<`, `"` → escaped in dashboard HTML. (Task 2 test `hp-dashboard-escapes`.)

---

### Task 1: Progress model and structure checker

**Files:**
- Create: `publish.el` (progress + checker functions only in this task)
- Create: `test/fixtures/phase-sample.org`, `test/hp-test.el`
- Create: `Makefile`, `.gitignore` (`_site/`)

**Interfaces:**
- Produces (all in `publish.el`, prefix `hp-`):
  - `(hp-collect-weeks FILE)` → list of plists `(:file :title :week :id :state :optional :build-done :build-total :next-item)`; `:state` is a string ("TODO" "DOING" "DONE" "SKIPPED"); `:next-item` is the first unticked Build item text or nil.
  - `(hp-phase-summary FILE)` → plist `(:file :title :done :total :weeks)`; `:title` from `#+TITLE:`.
  - `(hp-current-week WEEKS)` → week plist or nil.
  - `(hp-next-action WEEK)` → string: `:next-item`, or `"Mark this week DONE"` when all Build items are ticked.
  - `(hp-check-file FILE)` → list of error strings (empty = OK), enforcing the Global Constraints' week structure, `#+TODO` line, `#+TITLE`, Checkpoint details block, `Phase review` at end.
  - `hp-phase-files` → sorted `plan/0[1-8]-*.org`.
- Makefile targets: `test` (`emacs -Q --batch -L . -l test/hp-test.el -f ert-run-tests-batch-and-exit`), `check` (runs `hp-check-file` on every phase file, non-zero exit on errors), `site`, `clean`.

- [ ] **Step 1:** Write `test/fixtures/phase-sample.org`: `#+TITLE: Phase 9: Sample`, three weeks (week 1 DONE with 2/2 ticked; week 2 TODO with 1/3 ticked; week 3 SKIPPED, `:OPTIONAL: t`), a `* Phase review` heading, all subheadings per Global Constraints. Also `test/fixtures/phase-bad.org` missing `** Parts` in one week and missing the details block.
- [ ] **Step 2:** Write ERT tests in `test/hp-test.el`:
  - `hp-collect-weeks-basic`: 3 weeks; week 2 has `:build-done 1 :build-total 3 :state "TODO" :id "week-02"`.
  - `hp-collect-ignores-non-weeks`: no plist titled "Phase review".
  - `hp-phase-summary-excludes-skipped`: `:done 1 :total 2`.
  - `hp-current-week-prefers-doing`: given weeks (TODO w2, DOING w3) → w3; given (DONE, TODO w2) → w2; all DONE → nil.
  - `hp-next-action-all-ticked`: TODO week with 2/2 → "Mark this week DONE"; week 2 → its second item text.
  - `hp-check-good`: `(hp-check-file "test/fixtures/phase-sample.org")` → nil.
  - `hp-check-bad`: result mentions "Parts" and "details".
- [ ] **Step 3:** Run `make test`. Expected: FAIL (functions undefined).
- [ ] **Step 4:** Implement the functions in `publish.el`. Parse with `org-element-parse-buffer` inside `with-temp-buffer` + `org-mode` after `insert-file-contents`, so `#+TODO` from the file is honored. Week detection: level-1 headline with `:WEEK` property.
- [ ] **Step 5:** Run `make test`. Expected: all pass.
- [ ] **Step 6:** Commit `feat: progress model and structure checker`.

### Task 2: Site export and dashboard

**Files:**
- Modify: `publish.el` (add export config + dashboard)
- Create: `assets/style.css`
- Modify: `test/hp-test.el`, `Makefile`

**Interfaces:**
- Consumes: Task 1 functions.
- Produces:
  - `hp-plan-dir` (defvar, default `"plan/"`) and `hp-site-dir` (default `"_site/"`); `hp-phase-files` reads from `hp-plan-dir`.
  - `(hp-dashboard-html PHASES)` → full HTML string for `index.html`; `PHASES` is a list of `hp-phase-summary` plists. Contains: overall "N of M weeks" and a percentage bar; one row per phase with bar and link `<file>.html`; current-week card with title linked to `<file>.html#<id>` and next action; or "Plan complete" when none.
  - `(hp-build-site)` → runs `org-publish-all` with force, then writes `_site/index.html`. Projects: `hp-org` (base `plan/`, publishing `org-html-publish-to-html`, `:with-toc t`, `:section-numbers nil`, `:html-head` linking `style.css`, `:html-postamble` with a "← Dashboard" link), `hp-assets` (base `assets/`, attachment). Output `_site/`.
- Makefile `site`: `emacs -Q --batch -L . -l publish.el -f hp-build-site`.

- [ ] **Step 1:** Add tests:
  - `hp-dashboard-shows-progress`: from the fixture summary, HTML contains "1 of 2 weeks", "week-02", and Task 1's next item text.
  - `hp-dashboard-complete`: summary whose weeks are all DONE → contains "Plan complete" and no "Current week".
  - `hp-dashboard-escapes`: phase title `A & <B> "C"` → contains `A &amp; &lt;B&gt; &quot;C&quot;`.
- [ ] **Step 2:** Run `make test`. Expected: the three new tests FAIL.
- [ ] **Step 3:** Implement `hp-dashboard-html` (escape with `org-html-encode-plain-text` plus `"`) and `hp-build-site`. Write `assets/style.css`: readable measure (~70ch), system font stack, CSS variables for colors with a `prefers-color-scheme: dark` override, styled `.todo`/`.done` keywords, checkbox list styling, `details` styling, progress bars, responsive at 360px.
- [ ] **Step 4:** Run `make test`. Expected: pass.
- [ ] **Step 5:** Run `emacs -Q --batch -L . -l publish.el --eval '(let ((hp-plan-dir "test/fixtures/")) (hp-build-site))'`; open `_site/index.html` and the phase page; confirm `<details>` renders and the week anchor link works.
- [ ] **Step 6:** Commit `feat: org-publish export and progress dashboard`.

### Task 3: Start-here, phases 1–2

**Files:**
- Create: `plan/00-start-here.org`, `plan/01-electronics.org`, `plan/02-pico-digital-io.org`
- Create: `README.org` (what this is, how to log progress, `make site`)

**Interfaces:** Consumes the conventions checked by `hp-check-file`.

- [ ] **Step 1:** Write `00-start-here.org` (not a phase file; no weeks): how to use the repo (Emacs and GitHub mobile app), study rhythm table from the spec, tool list with when each is bought, parts philosophy, 3.3 V and "disconnect power before rewiring" safety notes, the four note questions.
- [ ] **Step 2:** Write `01-electronics.org` (weeks 1–4) and `02-pico-digital-io.org` (weeks 5–9, MicroPython; week 7 is transistors/MOSFETs/flyback) per the spec outline and Global Constraints. All weeks `TODO`.
- [ ] **Step 3:** Run `make check`. Expected: no errors.
- [ ] **Step 4:** Verify links: `grep -ohE 'https?://[^] >]+' plan/*.org | sort -u | xargs -n1 curl -sIL -o /dev/null -w '%{http_code} %{url_effective}\n'`. Expected: all 2xx/3xx; replace any that fail.
- [ ] **Step 5:** `make site`; dashboard shows 0 of 9 weeks and current week = Week 1.
- [ ] **Step 6:** Commit `content: start here, phases 1-2`.

### Task 4: Phases 3–4

**Files:** Create `plan/03-analog-sensing.org` (weeks 10–13), `plan/04-embedded-c.org` (weeks 14–19; week 16 Debug Probe/SWD/GDB; week 19 PIO with `:OPTIONAL: t`).

- [ ] **Step 1:** Write both files per spec and Global Constraints.
- [ ] **Step 2:** `make check` → no errors.
- [ ] **Step 3:** Link verification command from Task 3 → all 2xx/3xx.
- [ ] **Step 4:** Commit `content: phases 3-4`.

### Task 5: Phases 5–6

**Files:** Create `plan/05-peripherals.org` (weeks 20–25; 21 includes logic analyzer; 24 capstone v1; 25 Wi-Fi + capstone v2, Palak writes the Pi-side code from guidance), `plan/06-power-soldering.org` (weeks 26–28; 28 moves capstone to protoboard).

- [ ] **Step 1:** Write both files.
- [ ] **Step 2:** `make check` → no errors.
- [ ] **Step 3:** Link verification → all 2xx/3xx.
- [ ] **Step 4:** Commit `content: phases 5-6`.

### Task 6: Phases 7–8 and capstone

**Files:** Create `plan/07-pcb-kicad.org` (weeks 29–32), `plan/08-computer-hardware.org` (weeks 33–36, Nand2Tetris Part I, Ben Eater as optional companion), `plan/09-capstone.org` (descriptive: v1/v2/v3, which weeks carry its tasks, dew point, the sky-clarity limitation; no TODOs, no checkboxes).

- [ ] **Step 1:** Write the three files.
- [ ] **Step 2:** `make check` → no errors; `grep -cE '^\*+ (TODO|DONE)|\[ \]' plan/09-capstone.org` → 0.
- [ ] **Step 3:** Link verification → all 2xx/3xx.
- [ ] **Step 4:** `make site`; dashboard shows "0 of 36 weeks" (PIO counts until marked SKIPPED) and 8 phase rows.
- [ ] **Step 5:** Commit `content: phases 7-8 and capstone`.

### Task 7: CI, GitHub repo, Pages

**Files:** Create `.github/workflows/pages.yml`.

- [ ] **Step 1:** Workflow on push to `main` and `workflow_dispatch`: checkout; `purcell/setup-emacs@master` with `version: 30.1`; `make test check site`; `actions/configure-pages@v5`; `actions/upload-pages-artifact@v3` with `path: _site`; deploy job with `actions/deploy-pages@v4`, permissions `pages: write`, `id-token: write`, environment `github-pages`.
- [ ] **Step 2:** Commit `ci: build and deploy to GitHub Pages`.
- [ ] **Step 3:** `gh repo create systemhalted/hardware-path --public --source . --push --description "36-week hardware engineering learning path, tracked in Org"`.
- [ ] **Step 4:** `gh api -X POST repos/systemhalted/hardware-path/pages -f build_type=workflow`.
- [ ] **Step 5:** `gh run watch` on the latest run → success. Then `curl -sI https://systemhalted.github.io/hardware-path/` → 200 and body contains "0 of 36 weeks".
