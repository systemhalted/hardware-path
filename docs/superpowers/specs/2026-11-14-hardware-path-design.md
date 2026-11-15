# Hardware Path: design

Date: 2026-11-14
Owner: Palak Mathur (GitHub `systemhalted`)

## Intent

Palak is a software engineer who wants to learn hardware engineering properly:
build projects and understand how things work underneath, not collect finished
tutorials. They want an eight-month, project-based curriculum and a site that
tracks their progress through it.

Palak lives in Emacs (31.1) and Org mode. The progress record must live in a
git repo as Org files. The site is a view of those files, never the source of
truth.

## Goals

- A complete curriculum, 36 weeks at 3–4 hours a week, from Ohm's law to
  a self-designed PCB and a CPU built from NAND gates.
- Every week has: what to learn, what to build, parts needed, a checkpoint
  question, and a notes section for the four reflection questions
  (expected / measured / different and why / what next).
- Progress is tracked with native Org features (TODO states, checkboxes,
  `[/]` statistics cookies) so it works inside Emacs with no site at all.
- A public site on GitHub Pages, rebuilt on every push, showing a progress
  dashboard and every week's content with Palak's notes inline.
- Readable and usable on a phone (Palak may read at the workbench).

## Non-goals

- Editing progress through the site. All edits happen in Org files (Emacs on
  the laptop, or the GitHub mobile app for quick changes).
- Accounts, a server, a database, or anything running on mrshudson for the
  site itself.
- A general-audience course. It is written for Palak, published publicly
  because GitHub Pages on a free plan requires a public repo. Palak accepted
  that their notes are public.

## Anti-goals (failure even if it technically works)

- The site and the Org files disagree, or the site needs data that isn't in
  the Org files.
- Logging progress requires leaving Org or learning a new tool.
- The curriculum becomes a tutorial checklist: weeks with builds but no
  "predict, then measure" and no checkpoint.
- Heavy JS frameworks or a build toolchain Palak has to maintain locally.

## Approaches considered

Where progress is stored:

1. **Browser storage on a static site.** No infrastructure, but progress is
   stuck in one browser and easy to lose. Rejected.
2. **Static site plus a small server on mrshudson** (the home Pi NAS) saving
   progress to bakerstreet. Multi-device and backed up, but adds a service and
   keeps the record outside git. Claude's recommendation; Palak declined.
3. **Progress in a git repo** (chosen by Palak). Full history, nothing hosted.
   Palak then chose **Org files instead of Markdown**.

How Org becomes a site:

- **Emacs `org-publish` in a GitHub Action** (chosen). Exact Org semantics,
  same tool Palak uses, local preview with their own Emacs.
- Pandoc or Hugo (go-org): partial Org support, a second parser that can
  disagree with what Emacs shows. Rejected.
- Jekyll on Pages: no native Org support. Rejected.

## Hardware decisions

- **Board: Raspberry Pi Pico 2 WH** (RP2350, Wi-Fi, pre-soldered headers).
  Reasons: excellent docs, MicroPython then C SDK, PIO, official Debug Probe
  for real GDB debugging, Wi-Fi for the capstone. Do not assume any branded
  kit (Palak explicitly rejected assuming Freenove).
- Parts are listed per phase so Palak buys them when needed, not as one kit.
- Tools introduced as needed: multimeter (week 1), Raspberry Pi Debug Probe
  (phase 4), USB logic analyzer with PulseView (phase 5), soldering iron such
  as a Pinecil (phase 6). Oscilloscope is mentioned as a later, optional
  purchase.
- Pico GPIO is 3.3 V; every parts list notes voltage compatibility.
- Palak's existing hardware: Linux laptop (Omarchy/Arch, "drwatson"),
  Raspberry Pi 3B NAS "mrshudson" at 192.168.4.23, an original
  first-generation Raspberry Pi Model A (256 MB, no networking).

## Curriculum

Weeks are milestones, not deadlines.

**Depth (Palak chose this):** each week's Learn section is a short framing of
the key idea and why it matters this week, followed by specific pointers
(a named Pico docs section, a 6.002 lecture, a Platt chapter, a video). The
plan is a guide through good sources, not a textbook. Effort goes into the
builds, the predict-then-measure steps, the checkpoints, and verified links.
Sources: Raspberry Pi Pico docs (MicroPython and C SDK), MIT OCW 6.002 as a
theory reference, *Make: Electronics* (Platt), KiCad docs, Nand2Tetris Part I,
Ben Eater's 8-bit computer videos as an optional companion.

**Phase 1: Electronics foundations (weeks 1–4)**
1. Voltage, current, resistance, power, Ohm's law. Breadboard rows and rails.
   Measure resistors with the multimeter.
2. Closed circuits, polarity, LEDs, current limiting. Calculate and measure.
3. Series and parallel, voltage dividers. Predict, then measure; change one
   resistor and explain.
4. Switches, ground, continuity, schematic symbols. Draw a schematic first.

**Phase 2: The Pico and digital I/O (weeks 5–9)** — MicroPython
5. Microcontroller, firmware, GPIO. Blink the onboard LED.
6. Digital output and pin limits. Traffic light.
7. Transistors and MOSFETs as switches; driving a motor or relay; flyback
   diodes; why GPIO can't power loads directly. *(addition)*
8. Digital input, pull-ups/pull-downs, button bounce.
9. State and timing. Reaction-time game.

**Phase 3: Analog and sensing (weeks 10–13)**
10. ADC; potentiometer readings vs multimeter.
11. PWM and duty cycle; LED brightness; servo control.
12. LDRs and voltage dividers; light meter.
13. Noise, thresholds, hysteresis; automatic night light.

**Phase 4: Embedded C and debugging (weeks 14–19)**
14. Pico C SDK, compiler, flashing; blink in C.
15. GPIO and polling in C; compare with MicroPython.
16. Debug Probe, SWD, GDB: breakpoints, stepping, inspecting registers.
    *(addition)*
17. Timers, interrupts, short handlers.
18. Memory, stack, globals; reaction game as a finite-state machine.
19. PIO state machines (optional week). *(addition)*

**Phase 5: Talking to peripherals (weeks 20–25)**
20. Reading datasheets: supply, pinout, interface, timing.
21. I²C with a temperature/humidity sensor (BME280 or SHT31); watch it on a
    logic analyzer. *(logic analyzer is an addition)*
22. SPI with a small display or SD card module; compare with I²C.
23. UART between the Pico and the laptop or mrshudson.
24. Sampling, logging, measurement quality. **Capstone v1** here.
25. Wi-Fi on the Pico 2 W; **Capstone v2**: send readings to mrshudson, store
    them, small dashboard, dew-point warning. Palak writes the Pi-side code
    from guidance; the plan does not ship it.

**Phase 6: Power and soldering (weeks 26–28)** *(addition)*
26. Regulators, decoupling capacitors, current budgets, battery basics.
27. Soldering: a through-hole practice kit.
28. Move the capstone circuit from breadboard to protoboard.

**Phase 7: PCB design in KiCad (weeks 29–32)** *(addition)*
29. Schematic capture for the capstone.
30. Footprints and layout.
31. DRC, Gerbers, ordering (JLCPCB or PCBWay).
32. Assembly and bring-up of the board when it arrives.

**Phase 8: Computer hardware from first principles (weeks 33–36)**
Nand2Tetris Part I in the simulator.
33. Boolean logic, gates from NAND.
34. Combinational logic, ALU.
35. Sequential logic, registers, memory.
36. CPU and instruction execution. Finishing Part I is the stated next goal.

**Capstone: StarFest conditions monitor** (spans phases 5–7; tracked only
inside the phase weeks, see Org conventions)
- v1 (week 24): temperature and humidity, display/print, interval logging,
  handles a disconnected sensor.
- v2 (week 25): Pico 2 W sends readings over Wi-Fi to mrshudson, which stores
  them and serves a small dashboard. Dew-point warning. A service on mrshudson
  for the capstone is fine; the "no server" non-goal applies only to this site.
- v3 (phase 7): the circuit on Palak's own PCB.
- Honest limitation stated in the content: temperature and humidity don't
  tell you sky clarity or seeing.

**Study rhythm** (included as an intro page): 30–45 min concept, 60–90 min
build, 30 min "change one thing and predict", 15–30 min notes.

## Repository and file structure

`~/Work/products/hardware-path`, pushed to public GitHub repo
`systemhalted/hardware-path`.

- `plan/00-start-here.org` — how to use the repo, study rhythm, tools and
  setup, safety notes.
- `plan/01-electronics.org` … `plan/08-computer-hardware.org` — one file per
  phase.
- `plan/09-capstone.org` — capstone description and versions. No TODOs and
  no checkboxes; it never counts toward progress, so it cannot disagree with
  the phase files.
- `publish.el` — org-publish config and dashboard generation.
- `Makefile` — `make site` (build to `_site/`), `make clean`.
- `.github/workflows/pages.yml` — install Emacs, run the build, deploy to
  Pages with the official Pages actions.
- `assets/` — CSS (and any small JS, if needed).

### Org conventions

- Phase file: one top-level heading per week, with a TODO state and no
  cookie: `* TODO Week 3: Series, parallel, voltage dividers`. A week is done
  when its heading is DONE (or SKIPPED, for optional weeks).
- TODO keywords: `TODO`, `DOING`, `|`, `DONE`, `SKIPPED` (for optional weeks
  like PIO). Set via `#+TODO:` in each file so Emacs and the build agree.
- Week properties drawer: `:WEEK:` number, `:OPTIONAL: t` when optional.
- Subheadings under each week (not TODO items): `Learn`, `Build` (checkbox
  list, with the `[/]` cookie on the `Build` heading itself, e.g.
  `** Build [1/3]`), `Parts`, `Checkpoint`, `Notes`.
- `Checkpoint` holds the question, then a short answer inside
  `#+begin_details` / `#+end_details` with a "Check your answer" summary, so
  Palak can try first. Export with `org-html-html5-fancy` so it becomes a
  native `<details>` element (no JS).
- Each phase file ends with a `* Phase review` heading (no TODO state) of
  "Can you…?" questions. Not tracked, does not block progress.
- Capstone tasks appear as build items inside weeks 24, 25, 28 and 29–32. `Notes` has the four questions as
  sub-subheadings, empty until Palak fills them.
- Progress is computed only from week-heading TODO states (weeks done /
  non-skipped weeks) and `Build` checkboxes (for "next action").

## Site

- Built by `org-publish` from `plan/` to HTML, plus a generated `index.html`
  dashboard.
- Dashboard: overall progress (weeks done / total, with optional skipped weeks
  excluded from the total), a progress bar per phase, the current week (the
  first week that is `DOING`, otherwise the first `TODO`), and its first
  unticked build item as "next action". Each links into the phase page.
- Phase pages: rendered Org with TODO states and checkboxes styled visibly,
  notes inline under each week, a table of contents.
- Styling: clean, readable, light and dark mode, works at phone width. No JS
  framework.
- Local preview: `make site` with Palak's Emacs, then open `_site/index.html`.

## Calls made by Claude after review (Palak to check)

- Capstone v2 gets its own week (25); total is 36 weeks.
- Capstone tracked only in phase weeks; `09-capstone.org` is descriptive.
- `[/]` cookie lives on the `Build` heading; week state is the unit of
  progress.
- Phase review sections are untracked.
- Checkpoint answers included, folded in `<details>`.

## Left to the builder

- Exact Elisp for counting progress and generating the dashboard HTML.
- Visual design details within the constraints above.
- Exact wording of each week's content, following the outline above, with
  concrete, verifiable resource links (verify links exist).
- Whether CI uses a distro Emacs package or a setup action, as long as its
  Org version renders the same constructs used here.
