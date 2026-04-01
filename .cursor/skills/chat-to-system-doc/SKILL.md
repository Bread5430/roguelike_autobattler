---
name: chat-to-system-doc
description: >-
  Compresses agentic development chat history into dense markdown system docs
  under .cursor/docs/, with optional registration in roguelike-project-context.
  Use when the user asks to summarize a dev chat, archive decisions, produce a
  subsystem/feature brief, or refresh documentation from conversation logs.
---

# Chat → system doc (compression + index)

## Purpose

Turn raw AI development chat into a **small, actionable markdown document** another agent can load quickly. Support **whole-project** overviews and **scoped** docs (single feature, subsystem, or bug arc).

## Default output location

- **Subsystem / feature scope:** `.cursor/docs/systems/<kebab-case-slug>.md` (create `systems/` if missing).
- **Full-project archive:** `.cursor/docs/project-snapshot-<YYYY-MM-DD>.md` **[assumed]** or a user-provided path.

Ask the user only if the path or scope is ambiguous.

---

## Optimized compression spec (apply literally)

**Input:** development chat transcript (paste, file path, or summarized thread).

**Output style:** Dense bullets; no dialogue, timestamps, or speaker labels; professional technical tone; **eliminate redundancy** and abandoned approaches—keep **final decisions** and **why**.

**Uncertainty:** Infer missing facts only when reasonable; mark **`[assumed]`** inline or in a short footnote section.

**Required sections** (omit only if truly inapplicable; state *N/A* in one line):

1. **Project overview** — Goal; constraints/requirements; tech stack/tools.
2. **Final architecture** — System design; components and responsibilities; data/control flow (numbered steps if linear).
3. **Key decisions & rationale** — Design choices; trade-offs; why the chosen approach won.
4. **Implemented features / progress** — Done work; current capabilities.
5. **Open problems / TODOs** — Known issues; incomplete work; risks.
6. **Important context for continuation** — Invariants; implicit constraints; gotchas.
7. **Useful snippets / patterns** — Reusable patterns, APIs, algorithms (minimal code—reference paths when possible).

**Compression rules**

- Prefer bullets over prose; one idea per bullet where possible.
- Merge duplicate discussion into a single decision + rationale.
- Preserve **exact** identifiers: file paths, class names, signals, public APIs.
- Do not restate the same constraint in multiple sections unless it is a critical invariant (then put it once under section 6).

---

## Per-system / feature docs

When the user names a **subsystem** (e.g. “input stack”, “spell bar”, “map gen”):

- Title the doc clearly (H1): `<System> — technical summary`.
- Weight sections toward **architecture**, **decisions**, and **continuation context** for that scope; keep overview shallow if the parent project is already documented elsewhere.
- Cross-link to core docs when useful: `.cursor/docs/architecture.md`, etc.

---

## Update `roguelike-project-context` index (features)

When a new system doc is written or **when the user asks to register** a doc in the project context skill:

1. Open `.cursor/skills/roguelike-project-context/SKILL.md`.
2. Locate **`### Features index`** (below the core doc table).
3. **Add or update one row** in the Features index table:

   - **Path:** workspace-relative, e.g. `.cursor/docs/systems/tactical-cursor.md`.
   - **Read when:** 5–15 words, third-person, trigger-rich (symptoms, topics, file names).
   - If the only row is the **placeholder** (`*—*` / “no subsystem docs registered”), **replace** that row with the real entry instead of appending.

4. **Do not** duplicate the same path; if the doc moved, fix the path in place.
5. Keep the core **Doc index** table (architecture, patterns, …) unchanged unless the user explicitly asks to edit those rows.
6. Optionally add one line under the table if multiple docs form a **feature family** (e.g. “Input: see also `input-coordination-plan.md`”).

If the Features index section is missing (older checkout), insert after the core table:

```markdown
### Features index (subsystem docs)

| Path | Read when |
|------|-----------|
```

Then add the first data row (no placeholder rows).

---

## Workflow checklist

- [ ] Confirm scope (full project vs subsystem) and output path.
- [ ] Emit the seven-section doc (or justified N/A).
- [ ] If requested or a new `.cursor/docs/systems/*.md` was created: **update Features index** in `roguelike-project-context/SKILL.md`.
- [ ] Short reply to user: path written + whether the index was updated.
