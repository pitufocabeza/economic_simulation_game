# Grid-Based Building Placement System (Godot 4.6)

## Files
- `BuildingDefinition.gd`: Resource for building types
- `BuildMenu.tscn` + `BuildMenu.gd`: Simple build menu UI
- `PlacementController.gd`: Handles placement logic, grid, ghost, validation, rotation
- `input_map.gd`: Input map actions to add

## Usage
1. Add `BuildMenu.tscn` to your UI scene, assign building definitions.
2. Add `PlacementController.gd` to your main scene, set references:
   - `terrain` (Node3D, your terrain node)
   - `build_menu` (the BuildMenu instance)
   - `is_tile_buildable` (Callable, e.g. a function or lambda)
3. Add input actions to your project (see `input_map.gd`).
4. Provide building scenes and icons for definitions.

## Features
- Strict grid placement, bottom-center anchor
- Ghost preview with color feedback
- Placement validation (bounds, slope, occupancy)
- 90° rotation (Q/E/R)
- Placement/cancel with mouse or keys

## No backend or economy logic included.
