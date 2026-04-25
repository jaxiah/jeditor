## Parent PRD

[PRD-001-jeditor-core.md](PRD-001-jeditor-core.md)

## What to build

Set up the complete project skeleton so every subsequent issue has a working build system, dependency declarations, and a passing test harness to build on. The deliverable is a project that compiles, runs a "hello world" TUI frame, and exits cleanly — nothing more.

## Acceptance criteria

- [x] `dune build` succeeds from the project root
- [x] `opam install . --deps-only` installs all required dependencies (Uutf, Uuseg, Alcotest; Notty not used — self-implementing terminal backend in ISSUE-005)
- [ ] `dune exec jeditor` launches, renders a single line of text in the terminal, and exits on any keypress
- [x] `dune test` runs and reports 0 failures (at minimum one placeholder test exists)
- [x] Directory structure matches the module layout described in PRD-001 (lib/buffer, lib/core, lib/terminal, lib/plugin, bin)
- [x] `.ocamlformat` and `.ocaml-version` committed so formatting is consistent from day one

## Blocked by

None — can start immediately.

## User stories addressed

- Project infrastructure prerequisite for all user stories.

## Completed

2026-04-24 — 5/6 acceptance criteria met. Implemented via TDD with OCaml 5.4.1 + dune 3.22.2.

Deferred: `dune exec jeditor` exits on any keypress (currently requires Enter). True "any keypress" raw-mode behavior depends on ISSUE-005 (Windows terminal backend). The binary compiles and runs correctly.
