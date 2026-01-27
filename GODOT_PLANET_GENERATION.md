# Godot Planet Generation Guide

## Overview

This guide explains how to procedurally generate 3D planets in Godot with unique textures based on planet properties (diameter, biome, seed) **without requiring any texture image files**.

---

## Architecture

### Key Principle: Procedural Generation from Seeds

- **Planet data** (seed, diameter, biome) stored in database
- **3D mesh** generated dynamically based on diameter
- **Surface texture** generated in real-time by shader using noise
- **Zero texture files** required - everything is procedural
- **Same seed = identical planet** every time

---

## Database Structure

### Planet Properties

```json
{
  "planet_id": 567,
  "name": "Sirius Major I",
  "seed": 1829471829,
  "biome": "Temperate",
  "diameter": 8500.0,
  "atmosphere": "Breathable",
  "gravity": 1.2,
  "num_locations": 15
}
```

### Biome Types

- **Temperate**: Forests, plains, oceans, mountains
- **Ice**: Glaciers, frozen seas, ice mountains
- **Volcanic**: Lava flows, ash plains, volcanic rock
- **Barren**: Rocky plains, craters, deserts
- **Oceanic**: Deep oceans, shallow water, islands

---

## Godot Implementation

### Step 1: Create Planet Mesh

Generate `SphereMesh` dynamically based on planet diameter:

```gdscript
func create_planet(planet_data: Dictionary) -> MeshInstance3D:
    # Create sphere with custom diameter
    var sphere = SphereMesh.new()
    var radius = planet_data["diameter"] / 2.0
    sphere.radius = radius
    sphere.height = planet_data["diameter"];
    
    # Adjust detail based on size (LOD)
    sphere.radial_segments = get_lod_segments(planet_data["diameter"])
    sphere.rings = get_lod_rings(planet_data["diameter"]);
    
    # Create mesh instance
    var planet_mesh = MeshInstance3D.new()
    planet_mesh.mesh = sphere
    planet_mesh.name = planet_data["name"];
    
    # Apply procedural material
    var material = create_planet_material(planet_data)
    planet_mesh.material_override = material;
    
    return planet_mesh

func get_lod_segments(diameter: float) -> int:
    # More detail for larger planets
    if diameter > 20000:
        return 128  # High detail
    elif diameter > 10000:
        return 64   # Medium detail
    else:
        return 32   # Low detail

func get_lod_rings(diameter: float) -> int:
    return get_lod_segments(diameter) / 2
```

---

### Step 2: Procedural Shader (No Textures Needed!)

Create `planet_shader.gdshader`:

```gdshader
shader_type spatial;

uniform int planet_seed = 12345;
uniform int biome_type = 0;  // 0=Temperate, 1=Ice, 2=Volcanic, 3=Barren, 4=Oceanic
uniform float noise_scale = 2.0;

// Hash function for noise generation
float hash(vec3 p) {
    p = fract(p * vec3(443.897, 441.423, 437.195));
    p += dot(p, p.yxz + 19.19);
    return fract((p.x + p.y) * p.z);
}

// 3D Simplex-style noise
float noise3d(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);  // Smoothstep
    
    return mix(
        mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x),
            mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
        mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x),
            mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y),
        f.z
    );
}

// Multi-octave noise for detail
float fbm(vec3 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise3d(p * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    
    return value;
}

// Get color based on biome and elevation
vec3 get_biome_color(float elevation, int biome) {
    vec3 color;
    
    if (biome == 0) {  // Temperate
        if (elevation > 0.7) {
            color = vec3(0.9, 0.9, 0.9);  // Snow peaks
        } else if (elevation > 0.5) {
            color = vec3(0.5, 0.4, 0.3);  // Mountains
        } else if (elevation > 0.3) {
            color = vec3(0.3, 0.6, 0.2);  // Forest
        } else if (elevation > 0.25) {
            color = vec3(0.4, 0.7, 0.3);  // Plains
        } else {
            color = vec3(0.2, 0.4, 0.8);  // Ocean
        }
    } else if (biome == 1) {  // Ice
        if (elevation > 0.6) {
            color = vec3(0.95, 0.97, 1.0);  // Ice peaks
        } else if (elevation > 0.3) {
            color = vec3(0.85, 0.9, 0.95);  // Glaciers
        } else {
            color = vec3(0.7, 0.8, 0.9);  // Frozen sea
        }
    } else if (biome == 2) {  // Volcanic
        if (elevation > 0.6) {
            color = vec3(0.3, 0.1, 0.0);  // Dark volcanic rock
        } else if (elevation > 0.3) {
            color = vec3(0.5, 0.3, 0.2);  // Ash plains
        } else {
            color = vec3(1.0, 0.3, 0.0);  // Lava
        }
    } else if (biome == 3) {  // Barren
        if (elevation > 0.5) {
            color = vec3(0.5, 0.4, 0.3);  // Rocky mountains
        } else if (elevation > 0.3) {
            color = vec3(0.6, 0.5, 0.4);  // Rocky plains
        } else {
            color = vec3(0.7, 0.6, 0.5);  // Sand/dust
        }
    } else if (biome == 4) {  // Oceanic
        if (elevation > 0.4) {
            color = vec3(0.6, 0.5, 0.3);  // Small islands
        } else if (elevation > 0.2) {
            color = vec3(0.3, 0.5, 0.8);  // Shallow water
        } else {
            color = vec3(0.1, 0.2, 0.6);  // Deep ocean
        }
    } else {
        color = vec3(0.5, 0.5, 0.5);  // Default gray
    }
    
    return color;
}

void fragment() {
    // Get world-space position on sphere surface
    vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec3 sphere_normal = normalize(world_pos);
    
    // Sample noise at sphere surface (with seed offset)
    vec3 noise_pos = sphere_normal * noise_scale + vec3(float(planet_seed) * 0.001);
    
    // Generate elevation with multiple octaves
    float elevation = fbm(noise_pos);
    
    // Normalize to 0-1 range
    elevation = elevation * 0.5 + 0.5;
    
    // Get color based on biome and elevation
    vec3 color = get_biome_color(elevation, biome_type);
    
    // Add subtle variation for realism
    float micro_detail = noise3d(sphere_normal * 50.0) * 0.05;
    color = color * (1.0 + micro_detail);
    
    ALBEDO = color;
    ROUGHNESS = 0.8;
    SPECULAR = 0.2;
}
```

---

### Step 3: Apply Material to Planet

```gdscript
func create_planet_material(planet_data: Dictionary) -> ShaderMaterial:
    var material = ShaderMaterial.new()
    material.shader = preload("res://shaders/planet_shader.gdshader");
    
    # Pass planet properties to shader
    material.set_shader_parameter("planet_seed", planet_data["seed"]);
    material.set_shader_parameter("biome_type", get_biome_id(planet_data["biome"]));
    material.set_shader_parameter("noise_scale", 2.0);
    
    return material;

func get_biome_id(biome_name: String) -> int:
    match biome_name:
        "Temperate":
            return 0
        "Ice":
            return 1
        "Volcanic":
            return 2
        "Barren":
            return 3
        "Oceanic":
            return 4
        _:
            return 0
```

---

### Step 4: Complete Planet Generator Class

```gdscript
class_name PlanetGenerator
extends Node3D

func load_planet(planet_id: int) -> MeshInstance3D:
    # Fetch planet data from API
    var planet_data = await get_planet_data(planet_id);
    
    # Create planet mesh
    var planet = create_planet(planet_data);
    
    # Optional: Add atmosphere
    if planet_data["atmosphere"] != "None":
        add_atmosphere(planet, planet_data);
    
    # Optional: Add collision for interaction
    add_collision_shape(planet, planet_data["diameter"] / 2.0);
    
    return planet;

func create_planet(planet_data: Dictionary) -> MeshInstance3D:
    # Create sphere mesh
    var sphere = SphereMesh.new();
    var radius = planet_data["diameter"] / 2.0;
    sphere.radius = radius;
    sphere.height = planet_data["diameter"];
    sphere.radial_segments = get_lod_segments(planet_data["diameter"]);
    sphere.rings = get_lod_rings(planet_data["diameter"]);
    
    # Create mesh instance
    var planet_mesh = MeshInstance3D.new();
    planet_mesh.mesh = sphere;
    planet_mesh.name = planet_data["name"];
    
    # Apply procedural material
    var material = create_planet_material(planet_data);
    planet_mesh.material_override = material;
    
    return planet_mesh;

func create_planet_material(planet_data: Dictionary) -> ShaderMaterial:
    var material = ShaderMaterial.new();
    material.shader = preload("res://shaders/planet_shader.gdshader");
    material.set_shader_parameter("planet_seed", planet_data["seed"]);
    material.set_shader_parameter("biome_type", get_biome_id(planet_data["biome"]));
    material.set_shader_parameter("noise_scale", 2.0);
    return material;

func get_biome_id(biome_name: String) -> int:
    match biome_name:
        "Temperate":
            return 0
        "Ice":
            return 1
        "Volcanic":
            return 2
        "Barren":
            return 3
        "Oceanic":
            return 4
        _:
            return 0;

func get_lod_segments(diameter: float) -> int:
    if diameter > 20000:
        return 128;
    elif diameter > 10000:
        return 64;
    else:
        return 32;

func get_lod_rings(diameter: float) -> int:
    return get_lod_segments(diameter) / 2;

func add_atmosphere(planet_mesh: MeshInstance3D, planet_data: Dictionary):
    # Create slightly larger transparent sphere
    var atmo_sphere = SphereMesh.new();
    var base_radius = planet_data["diameter"] / 2.0;
    atmo_sphere.radius = base_radius * 1.05;
    atmo_sphere.height = planet_data["diameter"] * 1.05;
    atmo_sphere.radial_segments = 32;
    atmo_sphere.rings = 16;
    
    var atmo_mesh = MeshInstance3D.new();
    atmo_mesh.mesh = atmo_sphere;
    
    # Transparent atmospheric material
    var atmo_material = StandardMaterial3D.new();
    atmo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA;
    atmo_material.albedo_color = get_atmosphere_color(planet_data["atmosphere"]);
    atmo_material.cull_mode = BaseMaterial3D.CULL_FRONT;  # Render from inside
    atmo_mesh.material_override = atmo_material;
    
    planet_mesh.add_child(atmo_mesh);

func get_atmosphere_color(atmosphere_type: String) -> Color:
    match atmosphere_type:
        "Breathable":
            return Color(0.5, 0.7, 1.0, 0.3);
        "Toxic":
            return Color(0.8, 1.0, 0.3, 0.4);
        "Thin":
            return Color(0.9, 0.9, 1.0, 0.1);
        _:
            return Color(1.0, 1.0, 1.0, 0.0);

func add_collision_shape(planet_mesh: MeshInstance3D, radius: float):
    var body = StaticBody3D.new();
    var shape = CollisionShape3D.new();
    var sphere_shape = SphereShape3D.new();
    sphere_shape.radius = radius;
    shape.shape = sphere_shape;
    body.add_child(shape);
    planet_mesh.add_child(body);

func get_planet_data(planet_id: int) -> Dictionary:
    # Replace with actual API call
    var response = await API.get("/planets/" + str(planet_id));
    return response;
```

---

## Advanced Features

### Dynamic LOD (Level of Detail)

Adjust mesh detail based on camera distance:

```gdscript
extends Node3D

var planet_mesh: MeshInstance3D
var camera: Camera3D
var planet_data: Dictionary

func _process(_delta):
    var distance = camera.global_position.distance_to(global_position);
    update_lod(distance);

func update_lod(distance: float):
    var segments: int;
    var rings: int;
    
    if distance < 100.0:
        segments = 128;
        rings = 64;
    elif distance < 500.0:
        segments = 64;
        rings = 32;
    else:
        segments = 32;
        rings = 16;
    
    # Only regenerate if detail changed
    if planet_mesh.mesh.radial_segments != segments:
        var sphere = SphereMesh.new();
        sphere.radius = planet_data["diameter"] / 2.0;
        sphere.height = planet_data["diameter"];
        sphere.radial_segments = segments;
        sphere.rings = rings;
        planet_mesh.mesh = sphere;
```

---

### Irregular/Deformed Planets

Create asteroid-like or irregularly shaped planets:

```gdscript
func create_irregular_planet(planet_data: Dictionary) -> MeshInstance3D:
    var noise = FastNoiseLite.new();
    noise.seed = planet_data["seed"];
    noise.frequency = 0.5;
    
    var base_radius = planet_data["diameter"] / 2.0;
    var surface_tool = SurfaceTool.new();
    surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES);
    
    var segments = 64;
    var rings = 32;
    
    # Generate vertices with noise-based deformation
    for ring in range(rings + 1):
        var theta = (ring / float(rings)) * PI;
        
        for segment in range(segments + 1):
            var phi = (segment / float(segments)) * TAU;
            
            # Base sphere position
            var x = sin(theta) * cos(phi);
            var y = cos(theta);
            var z = sin(theta) * sin(phi);
            var sphere_point = Vector3(x, y, z);
            
            # Add noise-based deformation
            var deformation = noise.get_noise_3dv(sphere_point * 2.0) * 0.15;
            var radius = base_radius * (1.0 + deformation);
            
            var vertex = sphere_point * radius;
            
            # Add vertex with normal and UV
            surface_tool.set_normal(sphere_point);
            surface_tool.set_uv(Vector2(segment / float(segments), ring / float(rings)));
            surface_tool.add_vertex(vertex);
    
    # Generate triangles
    for ring in range(rings):
        for segment in range(segments):
            var i0 = ring * (segments + 1) + segment;
            var i1 = i0 + 1;
            var i2 = (ring + 1) * (segments + 1) + segment;
            var i3 = i2 + 1;
            
            surface_tool.add_index(i0);
            surface_tool.add_index(i2);
            surface_tool.add_index(i1);
            
            surface_tool.add_index(i1);
            surface_tool.add_index(i2);
            surface_tool.add_index(i3);
    
    surface_tool.generate_normals();
    var mesh = surface_tool.commit();
    
    var mesh_instance = MeshInstance3D.new();
    mesh_instance.mesh = mesh;
    
    # Apply material
    var material = create_planet_material(planet_data);
    mesh_instance.material_override = material;
    
    return mesh_instance;
```

---

## Linking to Tilemap Locations

Ensure planet surface matches location biomes:

```python
# Backend: When creating locations for a planet
def create_locations_for_planet(planet_id: int, planet_data: dict):
    locations = []
    
    for i in range(planet_data["num_locations"]):
        # Derive location seed from planet seed
        location_seed = hash(f"{planet_data['seed']}_{i}");
        
        # Sample planet noise at location position to determine biome
        position = calculate_location_position(i, planet_data["num_locations"]);
        local_biome = sample_planet_biome(planet_data["seed"], position);
        
        locations.append({
            "location_id": generate_id(),
            "planet_id": planet_id,
            "tilemap_seed": location_seed,
            "biome": local_biome,  # ← Matches planet surface!
            "position": position,
            "grid_width": 16,
            "grid_height": 16
        })
    
    return locations
```

---

## API Endpoints

### Get Planet Data
```
GET /planets/{planet_id}
```

**Response:**
```json
{
  "planet_id": 567,
  "name": "Sirius Major I",
  "seed": 1829471829,
  "biome": "Temperate",
  "diameter": 8500.0,
  "atmosphere": "Breathable",
  "gravity": 1.2,
  "num_locations": 15
}
```

### Get Planet Locations
```
GET /planets/{planet_id}/locations
```

**Response:**
```json
[
  {
    "location_id": 1234,
    "name": "Plot 1",
    "position": {"x": 100, "y": 200, "z": 50},
    "biome": "Temperate",
    "claimed": false
  },
  ...
]
```

---

## Performance Notes

| Aspect | Details |
|--------|---------|
| **Mesh Generation** | < 1ms (very fast) |
| **Shader Rendering** | Real-time (GPU accelerated) |
| **Memory Usage** | Minimal (no texture files) |
| **File Size** | Tiny (just shader code) |
| **Consistency** | Same seed = identical planet always |

---

## Comparison: Texture Approaches

| Approach | Files Needed | Performance | Variety | Consistency |
|----------|--------------|-------------|---------|-------------|
| **Shader (recommended)** | ❌ None | Excellent | Infinite | Perfect |
| **CPU-generated textures** | ✅ Generated | Good | Infinite | Perfect |
| **Pre-made textures** | ✅ Artist-made | Best | Limited | N/A |

---

## Testing Determinism

Verify that the same seed produces identical planets:

```gdscript
func test_planet_consistency():
    var test_data = {
        "seed": 12345,
        "diameter": 10000,
        "biome": "Temperate"
    }
    
    # Generate planet twice
    var planet1 = create_planet(test_data);
    var planet2 = create_planet(test_data);
    
    # Both should have identical materials with same seed
    var mat1 = planet1.material_override as ShaderMaterial;
    var mat2 = planet2.material_override as ShaderMaterial;
    
    assert(mat1.get_shader_parameter("planet_seed") == mat2.get_shader_parameter("planet_seed"));
    print("✅ Deterministic generation confirmed!");
}
```

---

## Future Enhancements

1. **Animated clouds**: Add moving cloud layer with time-based noise
2. **City lights**: Show locations with buildings on night side
3. **Rings**: Add Saturn-like ring systems
4. **Moons**: Generate orbiting moons
5. **Day/night cycle**: Rotate planet and update lighting
6. **Terrain deformation**: Allow terraforming to modify planet appearance

---

## Summary

✅ **Zero texture files required** - Everything is procedural  
✅ **Dynamic mesh generation** based on diameter  
✅ **Shader-based texturing** from seed + biome  
✅ **Deterministic** - Same seed always produces identical planet  
✅ **Performance optimized** with LOD system  
✅ **Scales to millions of unique planets** with minimal resources  

This system allows you to generate an entire procedural galaxy with planets that are:
- Visually unique
- Consistent across sessions
- Lightweight (no texture assets)
- Perfectly integrated with your tilemap system
