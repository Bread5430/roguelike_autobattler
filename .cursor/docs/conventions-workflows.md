# Conventions

- **File naming**: PascalCase for scenes (`.tscn`), snake_case for scripts (`.gd`)
- **Node structure**: Managers as Control/Node2D, units as CharacterBody2D
- **Input**: Custom actions in `project.godot` (leftClick, inventory=I, rotatePlacement=R)
- **Debugging**: Dev console (`Testing/dev_console.gd`) toggled with `` ` `` for commands like `help`

# Workflows

- **Run**: Open in Godot editor, play main scene (`UI/Menus/MainMenu.tscn`)
- **Export**: Godot’s built-in export for platforms
- **Testing**: `enemy_spawn_test.tscn` for isolated battle testing
- **Data editing**: Modify CSVs; restart autoloads to reload (including `units_glossary.csv` for unit combat stats and glossary text)
