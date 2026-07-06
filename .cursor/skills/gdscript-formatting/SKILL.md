---
name: gdscript-formatting
description: >-
  GDScript formatting conventions for this project. Use when writing or editing
  .gd files, reviewing agent-generated GDScript, or when variable declaration
  style is in question. Forbids := on variables; use plain = or explicit type.
---

# GDScript formatting

## Variable declarations

**Do not use `:=` (inferred-type assignment) for variables.**

Use one of:

| Style | Example |
|-------|---------|
| Plain equals | `var foo = get_bar()` |
| Explicit type | `var foo : Bar = get_bar()` |

Applies to `var`, `@export var`, and `@onready var`.

```gdscript
# Forbidden
var offers := rest_control.generate_offers()
@onready var health_bar := $HealthBar

# Allowed
var offers = rest_control.generate_offers()
var offers : Dictionary = rest_control.generate_offers()
@onready var health_bar : ProgressBar = $HealthBar
```

## Exceptions

- `const` with `:=` is fine when matching nearby code (e.g. `const SLOT_SCENE := preload(...)`).
- Default function parameters may use `:=` (e.g. `func damage(amount := 1)`).

## Related docs

- `.cursor/docs/conventions-workflows.md` — full conventions list
- `.cursor/rules/gdscript-formatting.mdc` — file-scoped rule for `**/*.gd`
