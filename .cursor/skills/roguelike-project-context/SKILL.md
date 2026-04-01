---
name: roguelike-project-context
description: >-
  Loads split project reference docs for the Godot 4.4 roguelike autobattler.
  Use when the user asks about architecture, managers, map/battle flow, data
  pipelines, conventions, adding units/spells/formations, or GUI vs battle input
  (InputCoordinator, mouse_filter, handle_game_area_click). Do not load every
  file by default—read only the doc(s) that match the current task.
---

# Roguelike Autobattler — project context (progressive load)

This skill points at markdown references under `.cursor/docs/`. **Read only the file(s) relevant to the question** using the Read tool. Avoid loading all docs in one turn unless the user asks for a full project brief.

## Doc index (pick by topic)

From the **workspace root**, read only what you need:

| Path | Read when |
|------|-----------|
| `.cursor/docs/architecture.md` | Core systems, main scripts, spells/GUI/units overview |
| `.cursor/docs/patterns.md` | Autoloads, glossary, signals, placement, roles, `Unit_Parent` filtering, item inspection |
| `.cursor/docs/data-flow.md` | Map → prep → battle → post-battle sequence, inventory/spell bar behavior |
| `.cursor/docs/conventions-workflows.md` | Naming, nodes, input actions, dev console, run/test/export, CSV editing |
| `.cursor/docs/feature-recipes.md` | Step-by-step: new unit, formation, state hook, spell |
| `.cursor/docs/input-coordination-plan.md` | InputCoordinator, `handle_game_area_click`, `handle_unit_click`, mouse_filter, viewport handling, Passthrough_Helper |

## Usage

1. Infer which topic(s) apply (e.g. "placement broken" → `patterns.md` + `input-coordination-plan.md`).
2. Read those files only.
3. If scope is unclear, read `architecture.md` first, then add another doc if needed.

## GitHub Copilot note

Project instructions previously lived at `.github/copilot-instructions.md`; they are now split under `.cursor/docs/`. For Copilot in GitHub, copy or symlink content if your workflow still expects `.github/copilot-instructions.md`.
