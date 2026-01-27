# Drone 3D Model Generation Guide

## Overview

This guide explains how to generate 3D drone models using **Tripo AI** and import them into Godot for use in the economic simulation game.

---

## Why Tripo AI?

- **Free tier:** 500 credits/month (~50 models)
- **Export formats:** `.glb`, `.fbx`, `.obj`, `.usdz`
- **Quality:** Excellent for game assets
- **Speed:** 8-10 seconds per generation
- **License:** CC BY 4.0 (commercial use allowed with attribution)
- **URL:** https://www.tripo3d.ai

---

## Drone Types

Our game features 4 distinct drone types, each with specific visual characteristics:

| Drone Type | Primary Color | Key Features | Purpose |
|------------|--------------|--------------|---------|
| **Explorer** | Blue | Spherical body, scanner ring, compact | Exploration, scouting, mapping |
| **Miner** | Orange/Yellow | Cubic body, large drill, rugged | Resource extraction |
| **Builder** | Green | Flat platform, robotic arms, tools | Construction, assembly |
| **Transporter** | Purple | Elongated body, cargo bay, 6 propellers | Logistics, item transport |

---

## Tripo AI Prompts

### Explorer Drone

```
sci-fi exploration drone, blue metallic body, spherical center with glowing scanner ring, 
four propellers on arms, compact aerodynamic design, LED light strips, 
holographic display on top, clean industrial aesthetic, game asset style, low poly
```

**Alternative (simpler):**
```
small blue exploration drone, round body, glowing ring sensor, quad propellers, 
sci-fi game asset
```

**Settings in Tripo AI:**
- Style: Sci-Fi / Industrial
- Poly Count: Low-Medium (better for games)
- Detail Level: Medium

---

### Miner Drone

```
industrial mining drone, orange and yellow body, cubic rectangular shape, 
large rotating drill bit underneath, four powerful propellers, 
warning stripes, hazard lights, rugged weathered panels, utilitarian factory design, 
game asset style, low poly
```

**Alternative (simpler):**
```
heavy mining drone, orange cubic body, drill on bottom, quad propellers, 
industrial warning stripes, game asset
```

**Settings in Tripo AI:**
- Style: Industrial / Mechanical
- Poly Count: Low-Medium
- Detail Level: Medium

---

### Builder Drone

```
construction robot drone, green and gray colors, flat hexagonal platform body, 
four articulated robotic arms with grippers and tools, welding torch, 
holographic blueprint projector on top, four propellers on corners, 
geometric industrial design, game asset style, low poly
```

**Alternative (simpler):**
```
construction drone, green platform body, robotic arms with tools, 
hologram display, quad propellers, game asset
```

**Settings in Tripo AI:**
- Style: Industrial / Robotic
- Poly Count: Low-Medium
- Detail Level: Medium

---

### Transporter Drone

```
cargo transport drone, purple and silver body, elongated rectangular shape, 
transparent cargo bay container in center, six powerful lift propellers in hexagon pattern, 
magnetic clamps underneath, LED navigation lights, sleek logistics design, 
game asset style, low poly
```

**Alternative (simpler):**
```
cargo drone, purple elongated body, transparent cargo container, 
six propellers, logistics design, game asset
```

**Settings in Tripo AI:**
- Style: Sci-Fi / Industrial
- Poly Count: Low-Medium
- Detail Level: Medium

---

## Generation Workflow

### Step 1: Sign Up for Tripo AI

1. Go to https://www.tripo3d.ai
2. Create free account
3. Verify email
4. Check your credit balance (should be 500 credits)

---

### Step 2: Generate Models

For each drone type:

1. **Click "Text to 3D"**
2. **Paste prompt** (from above)
3. **Adjust settings:**
   - Style: Sci-Fi or Industrial
   - Poly Count: Low or Medium
   - Detail Level: Medium
4. **Click "Generate"** (costs ~10 credits, takes 8-10 seconds)
5. **Review result:**
   - If good → Download
   - If not → Regenerate with adjusted prompt

**Tips:**
- Generate multiple variations if you have credits
- Try both detailed and simple prompts
- Note which prompts work best for iteration

---

### Step 3: Download Models

1. **Click on generated model**
2. **Select export format:** `.glb` (recommended for Godot)
3. **Download to:** `your_project/models/drones/raw/`
4. **Naming convention:**
   - `explorer_drone_v1.glb`
   - `miner_drone_v1.glb`
   - `builder_drone_v1.glb`
   - `transporter_drone_v1.glb`

**Why .glb?**
- ✅ Godot's preferred format
- ✅ Includes textures/materials
- ✅ Single file (easy to manage)
- ✅ Widely supported

---

## Importing to Godot

### Step 1: File Structure

Create this folder structure in your Godot project:

```
res://
├── models/
│   └── drones/
│       ├── raw/              # Original .glb files from Tripo AI
│       │   ├── explorer_drone_v1.glb
│       │   ├── miner_drone_v1.glb
│       │   ├── builder_drone_v1.glb
│       │   └── transporter_drone_v1.glb
│       └── scenes/           # Godot scene files (created below)
│           ├── explorer_drone.tscn
│           ├── miner_drone.tscn
│           ├── builder_drone.tscn
│           └── transporter_drone.tscn
```

---

### Step 2: Import Settings

When you drag a `.glb` file into Godot:

1. **Select the .glb file** in FileSystem
2. **Go to Import tab** (top-left)
3. **Configure settings:**

```
Root Type: Node3D
Root Name: (leave default)

Meshes:
  ✅ Generate LODs
  ✅ Create Shadow Meshes
  ✅ Light Baking: Static Lightmaps
  
Materials:
  ✅ Import Materials
  
Animation:
  ☐ Import Animations (not needed for drones)
  
Physics:
  ☐ Generate Collision Shapes (we'll add manually)
```

4. **Click "Reimport"**

---

### Step 3: Create Drone Scene

For each drone, create a proper scene:

1. **Right-click** on imported `.glb` → "New Inherited Scene"
2. **Or manually create scene:**

```
DroneBase (CharacterBody3D)
├── Model (imported .glb as child)
├── CollisionShape3D
│   └── Shape: SphereShape3D (radius: 0.5)
├── SelectionIndicator (Node3D)
│   └── Ring (MeshInstance3D with TorusMesh)
├── StatusLight (OmniLight3D)
└── DroneScript (attached script)
```

**Example scene setup script:**

```gdscript
# setup_drone_scene.gd
extends EditorScript

func _run():
    # Create base node
    var drone = CharacterBody3D.new()
    drone.name = "ExplorerDrone"
    
    # Load model
    var model = load("res://models/drones/raw/explorer_drone_v1.glb").instantiate()
    model.name = "Model"
    drone.add_child(model)
    model.owner = drone
    
    # Add collision
    var collision = CollisionShape3D.new()
    var shape = SphereShape3D.new()
    shape.radius = 0.5
    collision.shape = shape
    collision.name = "CollisionShape3D"
    drone.add_child(collision)
    collision.owner = drone
    
    # Add selection indicator
    var indicator = create_selection_indicator()
    indicator.name = "SelectionIndicator"
    drone.add_child(indicator)
    indicator.owner = drone
    
    # Save scene
    var scene = PackedScene.new()
    scene.pack(drone)
    ResourceSaver.save(scene, "res://models/drones/scenes/explorer_drone.tscn")
    
    print("✅ Drone scene created!")

func create_selection_indicator() -> Node3D:
    var indicator = Node3D.new()
    
    var ring = MeshInstance3D.new()
    var torus = TorusMesh.new()
    torus.inner_radius = 0.6
    torus.outer_radius = 0.65
    ring.mesh = torus
    
    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(1, 1, 0, 0.7)
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.emission_enabled = true
    mat.emission = Color(1, 1, 0)
    mat.emission_energy_multiplier = 2.0
    ring.material_override = mat
    
    ring.position.y = -0.5
    ring.visible = false  # Only show when selected
    
    indicator.add_child(ring)
    return indicator
```

---

### Step 4: Adjust Scale

Models from AI may be wrong scale. Test and adjust:

```gdscript
func _ready():
    # Check if model is too big/small
    var model = $Model
    
    # Adjust scale if needed (typical range: 0.1 - 5.0)
    model.scale = Vector3.ONE * 0.5  # Example: shrink to half size
```

**Finding the right scale:**
1. Add a CSGBox3D with size (1, 1, 1) as reference
2. Adjust drone scale until it looks right relative to reference
3. Note the scale value
4. Apply to all drones of that type

---

## Post-Processing (Optional)

### Add Procedural Materials

Override AI-generated materials with custom ones:

```gdscript
func apply_drone_material(drone_type: DroneType):
    var color = get_drone_color(drone_type)
    
    var model = $Model
    for child in get_all_meshes(model):
        var mat = StandardMaterial3D.new()
        mat.albedo_color = color
        mat.metallic = 0.8
        mat.roughness = 0.3
        mat.emission_enabled = true
        mat.emission = color * 0.3
        mat.emission_energy_multiplier = 0.5
        child.material_override = mat

func get_drone_color(drone_type: DroneType) -> Color:
    match drone_type:
        DroneType.EXPLORER:
            return Color(0.2, 0.6, 1.0)  # Blue
        DroneType.MINER:
            return Color(1.0, 0.7, 0.1)  # Orange
        DroneType.BUILDER:
            return Color(0.3, 0.8, 0.3)  # Green
        DroneType.TRANSPORTER:
            return Color(0.7, 0.3, 0.7)  # Purple
    return Color.WHITE

func get_all_meshes(node: Node) -> Array[MeshInstance3D]:
    var meshes: Array[MeshInstance3D] = []
    
    if node is MeshInstance3D:
        meshes.append(node)
    
    for child in node.get_children():
        meshes.append_array(get_all_meshes(child))
    
    return meshes
```

---

### Add Animations

Simple hover/propeller animations:

```gdscript
extends CharacterBody3D

var hover_time := 0.0
var base_y := 0.0

func _ready():
    base_y = position.y

func _process(delta):
    hover_time += delta
    
    # Hover animation (bob up and down)
    position.y = base_y + sin(hover_time * 2.0) * 0.1
    
    # Rotate propellers (if they're separate meshes)
    rotate_propellers(delta)

func rotate_propellers(delta: float):
    # Find propeller meshes (assumes they're named "Propeller" or similar)
    for child in $Model.get_children():
        if "propeller" in child.name.to_lower():
            child.rotate_y(delta * 20.0)  # Fast rotation
```

---

## Testing Checklist

After importing each drone:

- [ ] Model appears in viewport
- [ ] Scale is appropriate (roughly 0.5-1.0 units)
- [ ] Materials look correct
- [ ] Collision shape covers model
- [ ] No errors in output console
- [ ] Model rotates smoothly when camera moves around it
- [ ] FPS remains stable (check with multiple drones)

---

## Optimization

### LOD (Level of Detail)

For performance with many drones:

```gdscript
extends CharacterBody3D

@export var lod_distance_near := 10.0
@export var lod_distance_far := 50.0

var camera: Camera3D

func _process(_delta):
    if not camera:
        camera = get_viewport().get_camera_3d()
        return
    
    var distance = global_position.distance_to(camera.global_position)
    update_lod(distance)

func update_lod(distance: float):
    if distance < lod_distance_near:
        $Model.visible = true  # High detail
    elif distance < lod_distance_far:
        $Model.visible = true  # Could swap to lower poly version
    else:
        $Model.visible = false  # Too far, hide completely
```

---

### Mesh Optimization

If models are too heavy:

1. **In Blender** (if you have it):
   - Import `.glb`
   - Select mesh → Modifiers → Add "Decimate"
   - Set ratio to 0.5 (reduces poly count by half)
   - Export as `.glb` again

2. **Or request lower poly** in Tripo AI:
   - Regenerate with "Poly Count: Low"
   - Add "low poly" to prompt

---

## Licensing & Attribution

### CC BY 4.0 Requirements

Tripo AI free tier models are licensed under **CC BY 4.0**, which requires attribution.

**Add to your game credits:**

```gdscript
# credits.gd
extends Control

func _ready():
    $CreditsLabel.text = """
    === CREDITS ===
    
    Game Development: [Your Name/Studio]
    
    3D Drone Models:
    Generated using Tripo AI (https://www.tripo3d.ai)
    Licensed under CC BY 4.0
    https://creativecommons.org/licenses/by/4.0/
    
    Game Engine:
    Godot Engine (https://godotengine.org)
    Licensed under MIT License
    
    Thanks for playing!
    """
```

**Or in a README.md:**

```markdown
## Credits

### 3D Models
- Drone models generated using [Tripo AI](https://www.tripo3d.ai)
- Licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)

### Engine
- [Godot Engine](https://godotengine.org) - MIT License
```

**This is legally required for commercial use of Tripo AI free tier models.**

---

## Troubleshooting

### Model doesn't appear in Godot
- Check if `.glb` import finished (look for `.import` file)
- Try reimporting: Select file → Import tab → Reimport
- Check Output console for errors

### Model is too big/small
- Adjust scale in import settings, OR
- Adjust scale in scene: `$Model.scale = Vector3.ONE * 0.5`

### Model is black/no materials
- Check if materials imported: Import tab → Materials → ✅ Import Materials
- Try applying custom materials (see Post-Processing section)

### Poor performance with multiple drones
- Enable LOD (see Optimization section)
- Reduce poly count in Tripo AI (use "Low" setting)
- Use GPU instancing (advanced)

### Model doesn't match prompt
- Try different phrasing
- Add "low poly game asset" to prompt
- Try simpler prompt
- Regenerate (costs 10 more credits)

---

## Alternative: Free Pre-Made Models

If Tripo AI results aren't satisfactory, use these CC0 (public domain) alternatives:

### Kenney.nl
- **URL:** https://kenney.nl/assets/modular-sci-fi
- **License:** CC0 (no attribution needed!)
- **Format:** `.glb`, `.fbx`, `.obj`

### Quaternius
- **URL:** https://quaternius.com/packs/ultimatescifikit.html
- **License:** CC0
- **Format:** `.fbx`, `.obj`

### Poly Pizza
- **URL:** https://poly.pizza
- Search: "drone" or "robot"
- **License:** CC0

---

## Best Practices

1. **Keep original files:** Never delete the raw `.glb` from Tripo AI
2. **Version control:** Name files with `_v1`, `_v2` for iterations
3. **Document prompts:** Save prompts that worked well in this file
4. **Test early:** Import one drone first before generating all 4
5. **Consistent scale:** Make sure all drones are similar size relative to each other
6. **Credits file:** Set up attribution immediately (easy to forget later)

---

## Summary

✅ Use **Tripo AI** free tier (500 credits/month)  
✅ Generate with optimized prompts (provided above)  
✅ Export as `.glb` format  
✅ Import to Godot with proper settings  
✅ Create scene with collision and effects  
✅ **Add CC BY 4.0 attribution** in credits  
✅ Optimize with LOD for performance  

**Total cost:** Free  
**Time investment:** ~1-2 hours for all 4 drones  
**Result:** Professional-looking 3D drones ready for your game  

---

## Next Steps

After getting your drone models:
1. Set up drone behavior system (AI, pathfinding)
2. Implement task assignment (mining, building, transport)
3. Create UI for drone control
4. Add visual feedback (selection, status indicators) 

See `GODOT_DRONE_SYSTEM.md` (to be created) for gameplay implementation.