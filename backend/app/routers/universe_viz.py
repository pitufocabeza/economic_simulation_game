from fastapi import APIRouter, Depends, Response
from sqlalchemy.orm import Session
from sqlalchemy import select, func
from app.deps import get_db
from app.models.universe import Universe
from app.models.region import Region
from app.models.star_system import StarSystem
from app.models.planet import Planet
from app.models.location import Location
from app.models.resource_deposit import ResourceDeposit
import json

router = APIRouter(prefix="/viz", tags=["Visualization"])


@router.get("/universe")
def visualize_universe(db: Session = Depends(get_db)):
    """
    Generate an interactive 3D visualization of the universe using Three.js.
    """
    
    # Fetch regions (small, fast)
    regions = db.scalars(select(Region)).all()
    
    # Fetch systems with region data (avoid N+1 queries)
    systems_query = select(StarSystem).join(Region)
    systems = db.scalars(systems_query).all()
    
    # Pre-count planets per system and locations per planet in bulk
    planets_per_system = dict(
        db.execute(
            select(Planet.star_system_id, func.count(Planet.id))
            .group_by(Planet.star_system_id)
        ).all()
    )
    
    locations_per_planet = dict(
        db.execute(
            select(Location.planet_id, func.count(Location.id))
            .group_by(Location.planet_id)
        ).all()
    )
    
    # Fetch planets (without loading relationships)
    planets = db.scalars(select(Planet)).all()
    
    # Prepare data for JavaScript
    regions_data = [
        {
            "id": r.id,
            "name": r.name,
            "x": r.x,
            "y": r.y,
            "z": r.z,
            "is_core": any(core_name in r.name for core_name in ["Forgeheart", "Crystal", "Ironclad", "Radiant", "Obsidian", "Stellarforge", "Embercore", "Voidsteel", "Prismgate", "Titanforge", "Luminary"])
        }
        for r in regions
    ]
    
    systems_data = [
        {
            "id": s.id,
            "name": s.name,
            "region_id": s.region_id,
            "local_x": s.x,
            "local_y": s.y,
            "local_z": s.z,
            "x": s.x + s.region.x,  # Combine region + system coordinates
            "y": s.y + s.region.y,
            "z": s.z + s.region.z,
            "region_name": s.region.name,
            "planets_count": planets_per_system.get(s.id, 0)
        }
        for s in systems
    ]
    
    planets_data = [
        {
            "id": p.id,
            "name": p.name,
            "system_id": p.star_system_id,
            "biome": p.biome,
            "radius": p.radius,
            "total_resources": p.total_resources,
            "locations_count": locations_per_planet.get(p.id, 0)
        }
        for p in planets
    ]
    
    # Don't load resource breakdown upfront - too slow for 3,488 planets
    # Will be loaded via API when planet is clicked
    
    # Convert to JSON strings for embedding in JavaScript
    regions_json = json.dumps(regions_data)
    systems_json = json.dumps(systems_data)
    planets_json = json.dumps(planets_data)
    
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Universe Visualization</title>
        <meta charset="utf-8">
        <style>
            body {{ 
                margin: 0; 
                overflow: hidden; 
                font-family: Arial, sans-serif;
                background: #000;
            }}
            #info {{
                position: absolute;
                top: 10px;
                left: 10px;
                color: white;
                background: rgba(0,0,0,0.7);
                padding: 15px;
                border-radius: 5px;
                font-size: 14px;
                max-width: 300px;
                max-height: 90vh;
                overflow-y: auto;
            }}
            #controls {{
                position: absolute;
                top: 10px;
                right: 10px;
                color: white;
                background: rgba(0,0,0,0.7);
                padding: 15px;
                border-radius: 5px;
                font-size: 12px;
            }}
            button {{
                background: #4CAF50;
                color: white;
                border: none;
                padding: 8px 16px;
                margin: 5px;
                border-radius: 3px;
                cursor: pointer;
            }}
            button:hover {{ background: #45a049; }}
            .legend {{
                margin-top: 10px;
                padding-top: 10px;
                border-top: 1px solid #444;
            }}
            .legend-item {{
                display: flex;
                align-items: center;
                margin: 5px 0;
            }}
            .color-box {{
                width: 20px;
                height: 20px;
                margin-right: 10px;
                border: 1px solid white;
            }}
        </style>
    </head>
    <body>
        <div id="info">
            <h2>Universe Map</h2>
            <div id="stats"></div>
            <div class="legend">
                <div class="legend-item">
                    <div class="color-box" style="background: #00ffff;"></div>
                    <span>Core Regions (near center)</span>
                </div>
                <div class="legend-item">
                    <div class="color-box" style="background: #ff0000;"></div>
                    <span>Outlaw Regions (fringe)</span>
                </div>
                <div class="legend-item">
                    <div class="color-box" style="background: #ffff00;"></div>
                    <span>Star Systems</span>
                </div>
            </div>
        </div>
        
        <div id="controls">
            <h3>Controls</h3>
            <p>🖱️ Left Click + Drag: Rotate</p>
            <p>🖱️ Right Click + Drag: Pan</p>
            <p>🖱️ Scroll: Zoom</p>
            <button onclick="resetCamera()">Reset View</button>
            <button onclick="toggleSystems()">Toggle Systems</button>
        </div>

        <script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
        <script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/OrbitControls.js"></script>
        
        <script>
            const regions = {regions_json};
            const systems = {systems_json};
            const planets = {planets_json};
            const planetResourcesCache = {{}};  // Cache loaded resources
            
            let scene, camera, renderer, controls;
            let systemsVisible = true;
            let regionObjects = [];
            let systemObjects = [];
            let planetObjects = [];
            let labelSprites = [];
            let viewMode = 'universe'; // 'universe', 'region', 'system', 'planet'
            let selectedRegion = null;
            let selectedSystem = null;
            let raycaster, mouse;
            
            init();
            animate();
            
            function init() {{
                scene = new THREE.Scene();
                scene.background = new THREE.Color(0x000000);
                
                camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 1, 200000);
                camera.position.set(50000, 50000, 100000);
                
                renderer = new THREE.WebGLRenderer({{ antialias: true }});
                renderer.setSize(window.innerWidth, window.innerHeight);
                document.body.appendChild(renderer.domElement);
                
                controls = new THREE.OrbitControls(camera, renderer.domElement);
                controls.enableDamping = true;
                controls.dampingFactor = 0.05;
                
                raycaster = new THREE.Raycaster();
                mouse = new THREE.Vector2();
                
                // Add click handler
                renderer.domElement.addEventListener('click', onDocumentMouseClick, false);
                
                loadUniverseView();
                
                window.addEventListener('resize', onWindowResize);
            }}
            
            function loadUniverseView() {{
                clearScene();
                viewMode = 'universe';
                
                // Add galactic center marker
                const centerGeometry = new THREE.SphereGeometry(1000, 32, 32);
                const centerMaterial = new THREE.MeshBasicMaterial({{ color: 0xffffff, wireframe: true }});
                const center = new THREE.Mesh(centerGeometry, centerMaterial);
                center.position.set(50000, 50000, 50000);
                scene.add(center);
                
                // Add regions
                regions.forEach(region => {{
                    const size = 10000;
                    const geometry = new THREE.BoxGeometry(size, size, size);
                    const color = region.is_core ? 0x00ffff : 0xff0000;
                    const material = new THREE.MeshBasicMaterial({{
                        color: color,
                        transparent: true,
                        opacity: 0.2,
                        wireframe: true
                    }});
                    const cube = new THREE.Mesh(geometry, material);
                    cube.position.set(region.x, region.y, region.z);
                    cube.userData = {{ type: 'region', data: region }};
                    scene.add(cube);
                    regionObjects.push(cube);
                    
                    // Add region label
                    const sprite = makeTextSprite(region.name, {{
                        fontsize: 28
                    }});
                    sprite.position.set(region.x, region.y + 6000, region.z);
                    scene.add(sprite);
                    labelSprites.push(sprite);
                }});
                
                // Add star systems
                const systemGeometry = new THREE.SphereGeometry(300, 8, 8);
                systems.forEach(system => {{
                    const material = new THREE.MeshBasicMaterial({{ color: 0xffff00 }});
                    const sphere = new THREE.Mesh(systemGeometry, material);
                    sphere.position.set(system.x, system.y, system.z);
                    sphere.userData = {{ type: 'system', data: system }};
                    scene.add(sphere);
                    systemObjects.push(sphere);
                }});
                
                updateStats();
            }}
            
            function loadRegionView(region) {{
                clearScene();
                viewMode = 'region';
                selectedRegion = region;
                
                // Show systems in this region
                const regionSystems = systems.filter(s => s.region_id === region.id);
                
                const systemGeometry = new THREE.SphereGeometry(500, 16, 16);
                regionSystems.forEach(system => {{
                    const material = new THREE.MeshBasicMaterial({{ color: 0xffff00 }});
                    const sphere = new THREE.Mesh(systemGeometry, material);
                    sphere.position.set(system.local_x, system.local_y, system.local_z);
                    sphere.userData = {{ type: 'system', data: system }};
                    scene.add(sphere);
                    systemObjects.push(sphere);
                    
                    // Add system label
                    const sprite = makeTextSprite(system.name, {{ fontsize: 14 }});
                    sprite.position.set(system.local_x, system.local_y + 800, system.local_z);
                    scene.add(sprite);
                    labelSprites.push(sprite);
                }});
                
                // Center camera
                camera.position.set(5000, 5000, 15000);
                controls.target.set(5000, 5000, 5000);
                
                updateStats();
            }}
            
            function loadSystemView(system) {{
                clearScene();
                viewMode = 'system';
                selectedSystem = system;
                
                // Add central star
                const starGeometry = new THREE.SphereGeometry(1000, 32, 32);
                const starMaterial = new THREE.MeshBasicMaterial({{ color: 0xffff00, emissive: 0xffaa00 }});
                const star = new THREE.Mesh(starGeometry, starMaterial);
                star.position.set(0, 0, 0);
                scene.add(star);
                
                // Show planets in this system
                const systemPlanets = planets.filter(p => p.system_id === system.id);
                
                systemPlanets.forEach((planet, index) => {{
                    const distance = 2000 + (index * 1500);
                    const angle = (index / systemPlanets.length) * Math.PI * 2;
                    
                    const planetGeometry = new THREE.SphereGeometry(planet.radius / 10, 16, 16);
                    const planetMaterial = new THREE.MeshBasicMaterial({{ color: getBiomeColor(planet.biome) }});
                    const sphere = new THREE.Mesh(planetGeometry, planetMaterial);
                    
                    const x = Math.cos(angle) * distance;
                    const z = Math.sin(angle) * distance;
                    sphere.position.set(x, 0, z);
                    sphere.userData = {{ type: 'planet', data: planet }};
                    scene.add(sphere);
                    planetObjects.push(sphere);
                    
                    // Add orbit line
                    const orbitGeometry = new THREE.RingGeometry(distance - 50, distance + 50, 64);
                    const orbitMaterial = new THREE.MeshBasicMaterial({{ 
                        color: 0x444444, 
                        side: THREE.DoubleSide,
                        transparent: true,
                        opacity: 0.3
                    }});
                    const orbit = new THREE.Mesh(orbitGeometry, orbitMaterial);
                    orbit.rotation.x = Math.PI / 2;
                    scene.add(orbit);
                    
                    // Add planet label
                    const sprite = makeTextSprite(planet.name, {{ fontsize: 10 }});
                    sprite.position.set(x, planet.radius / 10 + 800, z);
                    scene.add(sprite);
                    labelSprites.push(sprite);
                }});
                
                // Center camera
                camera.position.set(0, 5000, 10000);
                controls.target.set(0, 0, 0);
                
                updateStats();
            }}
            
            function clearScene() {{
                while(scene.children.length > 0) {{ 
                    scene.remove(scene.children[0]); 
                }}
                regionObjects = [];
                systemObjects = [];
                planetObjects = [];
                labelSprites = [];
            }}
            
            function onDocumentMouseClick(event) {{
                event.preventDefault();
                
                mouse.x = (event.clientX / window.innerWidth) * 2 - 1;
                mouse.y = -(event.clientY / window.innerHeight) * 2 + 1;
                
                raycaster.setFromCamera(mouse, camera);
                
                let intersects;
                if (viewMode === 'universe') {{
                    intersects = raycaster.intersectObjects([...regionObjects, ...systemObjects]);
                }} else if (viewMode === 'region') {{
                    intersects = raycaster.intersectObjects(systemObjects);
                }} else if (viewMode === 'system') {{
                    intersects = raycaster.intersectObjects(planetObjects);
                }}
                
                if (intersects && intersects.length > 0) {{
                    const userData = intersects[0].object.userData;
                    
                    if (userData.type === 'region') {{
                        loadRegionView(userData.data);
                    }} else if (userData.type === 'system') {{
                        loadSystemView(userData.data);
                    }} else if (userData.type === 'planet') {{
                        showPlanetDetails(userData.data);
                    }}
                }}
            }}
            
            function showPlanetDetails(planet) {{
                // Check cache first
                if (planetResourcesCache[planet.id]) {{
                    displayPlanetDetails(planet, planetResourcesCache[planet.id]);
                }} else {{
                    // Show loading state
                    document.getElementById('stats').innerHTML = `
                        <h3>${{planet.name}}</h3>
                        <p>Loading resource data...</p>
                    `;
                    
                    // Fetch resources from API
                    fetch(`/viz/planet/${{planet.id}}/resources`)
                        .then(response => response.json())
                        .then(data => {{
                            planetResourcesCache[planet.id] = data.resources;
                            displayPlanetDetails(planet, data.resources);
                        }})
                        .catch(error => {{
                            console.error('Error loading resources:', error);
                            document.getElementById('stats').innerHTML = `
                                <h3>${{planet.name}}</h3>
                                <p style="color: #ff6666;">Error loading resources</p>
                                <button onclick="loadSystemView(selectedSystem)">Back to System</button>
                            `;
                        }});
                }}
            }}
            
            function displayPlanetDetails(planet, resources) {{
                const resourcesList = Object.entries(resources)
                    .sort((a, b) => b[1] - a[1])
                    .map(([type, qty]) => `<tr><td>${{type}}</td><td style="text-align: right">${{qty.toLocaleString()}}</td></tr>`)
                    .join('');
                
                document.getElementById('stats').innerHTML = `
                    <h3>${{planet.name}}</h3>
                    <strong>Biome:</strong> ${{planet.biome}}<br>
                    <strong>Radius:</strong> ${{planet.radius.toFixed(0)}} km<br>
                    <strong>Total Resources:</strong> ${{planet.total_resources.toLocaleString()}}<br>
                    <strong>Claimable Locations:</strong> ${{planet.locations_count}}<br>
                    <strong>Avg per Location:</strong> ${{(planet.total_resources / planet.locations_count).toLocaleString()}}<br>
                    <br>
                    <h4 style="margin: 10px 0 5px 0;">Resource Breakdown:</h4>
                    <table style="width: 100%; font-size: 12px;">
                        <thead>
                            <tr style="border-bottom: 1px solid #666;">
                                <th style="text-align: left;">Resource</th>
                                <th style="text-align: right;">Quantity</th>
                            </tr>
                        </thead>
                        <tbody>
                            ${{resourcesList}}
                        </tbody>
                    </table>
                    <br>
                    <button onclick="loadSystemView(selectedSystem)">Back to System</button>
                `;
            }}
            
            function getBiomeColor(biome) {{
                const colors = {{
                    'Barren': 0x8B7355,
                    'Oceanic': 0x0077BE,
                    'Ice': 0xADD8E6,
                    'Temperate': 0x228B22,
                    'Volcanic': 0xFF4500
                }};
                return colors[biome] || 0x888888;
            }}
            
            function updateStats() {{
                if (viewMode === 'universe') {{
                    document.getElementById('stats').innerHTML = `
                        <strong>Regions:</strong> ${{regions.length}}<br>
                        <strong>Star Systems:</strong> ${{systems.length}}<br>
                        <strong>Planets:</strong> ${{planets.length}}<br>
                        <strong>Core Regions:</strong> ${{regions.filter(r => r.is_core).length}}<br>
                        <strong>Outlaw Regions:</strong> ${{regions.filter(r => !r.is_core).length}}<br>
                        <br>
                        <em>Click a region or system to explore</em>
                    `;
                }} else if (viewMode === 'region') {{
                    const regionSystems = systems.filter(s => s.region_id === selectedRegion.id);
                    const totalPlanets = regionSystems.reduce((sum, s) => sum + s.planets_count, 0);
                    
                    document.getElementById('stats').innerHTML = `
                        <h3>${{selectedRegion.name}}</h3>
                        <strong>Type:</strong> ${{selectedRegion.is_core ? 'Core' : 'Outlaw'}}<br>
                        <strong>Star Systems:</strong> ${{regionSystems.length}}<br>
                        <strong>Total Planets:</strong> ${{totalPlanets}}<br>
                        <br>
                        <button onclick="loadUniverseView()">Back to Universe</button><br>
                        <em>Click a system to explore</em>
                    `;
                }} else if (viewMode === 'system') {{
                    const systemPlanets = planets.filter(p => p.system_id === selectedSystem.id);
                    
                    document.getElementById('stats').innerHTML = `
                        <h3>${{selectedSystem.name}}</h3>
                        <strong>Region:</strong> ${{selectedSystem.region_name}}<br>
                        <strong>Planets:</strong> ${{systemPlanets.length}}<br>
                        <br>
                        <button onclick="loadRegionView(selectedRegion || regions.find(r => r.id === ${{selectedSystem.region_id}}))">Back to Region</button><br>
                        <button onclick="loadUniverseView()">Back to Universe</button><br>
                        <br>
                        <em>Click a planet for details</em>
                    `;
                }}
            }}
            
            function makeTextSprite(message, parameters) {{
                if (parameters === undefined) parameters = {{}};
                const fontface = parameters.hasOwnProperty("fontface") ? parameters["fontface"] : "Arial";
                const fontsize = parameters.hasOwnProperty("fontsize") ? parameters["fontsize"] : 64;
                const borderThickness = 4;
                
                const canvas = document.createElement('canvas');
                const context = canvas.getContext('2d');
                context.font = "Bold " + fontsize + "px " + fontface;
                
                // Get text width for canvas sizing
                const metrics = context.measureText(message);
                const textWidth = metrics.width;
                
                canvas.width = textWidth + borderThickness * 2;
                canvas.height = fontsize * 1.4 + borderThickness * 2;
                
                // Re-apply font after canvas resize
                context.font = "Bold " + fontsize + "px " + fontface;
                context.fillStyle = "rgba(0, 0, 0, 0.8)";
                context.fillRect(0, 0, canvas.width, canvas.height);
                
                context.fillStyle = "rgba(255, 255, 255, 1.0)";
                context.fillText(message, borderThickness, fontsize + borderThickness);
                
                const texture = new THREE.Texture(canvas);
                texture.needsUpdate = true;
                const spriteMaterial = new THREE.SpriteMaterial({{ map: texture }});
                const sprite = new THREE.Sprite(spriteMaterial);
                sprite.scale.set(canvas.width * 50, canvas.height * 50, 1.0);
                return sprite;
            }}
            
            function animate() {{
                requestAnimationFrame(animate);
                controls.update();
                
                // Make labels always face camera
                labelSprites.forEach(sprite => {{
                    sprite.quaternion.copy(camera.quaternion);
                }});
                
                renderer.render(scene, camera);
            }}
            
            function onWindowResize() {{
                camera.aspect = window.innerWidth / window.innerHeight;
                camera.updateProjectionMatrix();
                renderer.setSize(window.innerWidth, window.innerHeight);
            }}
            
            function resetCamera() {{
                camera.position.set(50000, 50000, 100000);
                camera.lookAt(50000, 50000, 50000);
                controls.target.set(50000, 50000, 50000);
            }}
            
            function toggleSystems() {{
                systemsVisible = !systemsVisible;
                systemObjects.forEach(obj => {{
                    obj.visible = systemsVisible;
                }});
            }}
        </script>
    </body>
    </html>
    """
    
    return Response(content=html_content, media_type="text/html")


@router.get("/planet/{planet_id}/resources")
def get_planet_resources(planet_id: int, db: Session = Depends(get_db)):
    """
    Get resource breakdown for a specific planet (on-demand).
    """
    # Get resource totals grouped by type
    resources = db.execute(
        select(ResourceDeposit.resource_type, func.sum(ResourceDeposit.quantity))
        .join(Location)
        .where(Location.planet_id == planet_id)
        .group_by(ResourceDeposit.resource_type)
    ).all()
    
    resource_breakdown = {
        res_type: int(quantity) for res_type, quantity in resources
    }
    
    return {
        "planet_id": planet_id,
        "resources": resource_breakdown
    }


@router.get("/universe/data")
def get_universe_data(db: Session = Depends(get_db)):
    """
    Get universe data as JSON for custom visualizations.
    """
    universe = db.scalar(select(Universe))
    regions = db.scalars(select(Region)).all()
    systems = db.scalars(select(StarSystem)).all()
    planets = db.scalars(select(Planet)).all()
    
    return {
        "universe": {
            "name": universe.name if universe else "Unknown",
            "total_regions": len(regions),
            "total_systems": len(systems),
            "total_planets": len(planets)
        },
        "regions": [
            {
                "id": r.id,
                "name": r.name,
                "position": {"x": r.x, "y": r.y, "z": r.z},
                "systems_count": len(r.star_systems)
            }
            for r in regions
        ],
        "systems": [
            {
                "id": s.id,
                "name": s.name,
                "region_id": s.region_id,
                "position": {"x": s.x, "y": s.y, "z": s.z},
                "planets_count": len(s.planets)
            }
            for s in systems
        ]
    }
