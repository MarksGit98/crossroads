# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.6
- **Language**: GDScript (primary), C++ via GDExtension (performance-critical)
- **Rendering**: 2D (CanvasItem) — Vulkan/D3D12 backend
- **Physics**: Jolt (Godot 4.6 default)

## Naming Conventions

- **Classes**: PascalCase (e.g., `PlayerController`)
- **Variables/functions**: snake_case (e.g., `move_speed`)
- **Signals**: snake_case past tense (e.g., `health_changed`)
- **Files**: snake_case matching class (e.g., `player_controller.gd`)
- **Scenes**: PascalCase matching root node (e.g., `PlayerController.tscn`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_HEALTH`)

## Performance Budgets

- **Target Framerate**: 60 fps
- **Frame Budget**: 16.6 ms
- **Draw Calls**: [TO BE CONFIGURED]
- **Memory Ceiling**: [TO BE CONFIGURED]

## Testing

- **Framework**: GUT (Godot Unit Test)
- **Minimum Coverage**: [TO BE CONFIGURED]
- **Required Tests**: Balance formulas, gameplay systems, hex math, pathfinding, LOS, guard cone

## UI & Layout Rules

- **No hardcoded pixel positions.** All UI elements must be placed relative to the viewport (e.g., anchored to corners, centered via `get_viewport_rect().size`, or using Control node anchors/margins). This ensures the game scales correctly across any window size.
- Screen-space elements (Hand, Deck, ManaDisplay, etc.) must listen to `get_viewport().size_changed` and reposition dynamically when the window is resized.
- Use constants for margins/offsets from viewport edges (e.g., `MARGIN_LEFT`, `MARGIN_BOTTOM`) rather than absolute pixel coordinates.

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->
- **Hardcoded pixel positions for UI elements** — use viewport-relative positioning instead (see UI & Layout Rules above)

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here -->
- [None configured yet — add as dependencies are approved]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- [No ADRs yet — use /architecture-decision to create one]
