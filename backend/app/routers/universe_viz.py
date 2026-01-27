from fastapi import APIRouter, Depends, Response
from sqlalchemy.orm import Session
from sqlalchemy import select
from app.deps import get_db
from app.models.universe import Universe
from app.models.region import Region
from app.models.star_system import StarSystem
from app.models.planet import Planet
import json

router = APIRouter(prefix="/viz", tags=["Visualization"])


@router.get("/universe")
def visualize_universe(db: Session = Depends(get_db)):
    """
    Generate an interactive 3D visualization of the universe using Three.js.
    """
    
    # Fetch all data
    regions = db.scalars(select(Region)).all()
    systems = db.scalars(select(StarSystem)).all()
    
    # Prepare data for JavaScript
    regions_data = [
        {
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
            "name": s.name,
            "x": s.x + s.region.x,  # Combine region + system coordinates
            "y": s.y + s.region.y,
            "z": s.z + s.region.z,
            "region_name": s.region.name
        }
        for s in systems
    ]
    
    # Convert to JSON strings for embedding in JavaScript
    regions_json = json.dumps(regions_data)
    systems_json = json.dumps(systems_data)
    
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
            
            let scene, camera, renderer, controls;
            let systemsVisible = true;
            let systemObjects = [];
            
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
                    scene.add(cube);
                    
                    // Add region label
                    const sprite = makeTextSprite(region.name, {{
                        fontsize: 500,
                        backgroundColor: {{ r: 0, g: 0, b: 0, a: 0.7 }}
                    }});
                    sprite.position.set(region.x, region.y + 6000, region.z);
                    scene.add(sprite);
                }});
                
                // Add star systems
                const systemGeometry = new THREE.SphereGeometry(300, 8, 8);
                systems.forEach(system => {{
                    const material = new THREE.MeshBasicMaterial({{ color: 0xffff00 }});
                    const sphere = new THREE.Mesh(systemGeometry, material);
                    sphere.position.set(system.x, system.y, system.z);
                    sphere.userData = {{ name: system.name, region: system.region_name }};
                    scene.add(sphere);
                    systemObjects.push(sphere);
                }});
                
                // Add ambient light
                const light = new THREE.AmbientLight(0x404040);
                scene.add(light);
                
                // Stats
                document.getElementById('stats').innerHTML = `
                    <strong>Regions:</strong> ${{regions.length}}<br>
                    <strong>Star Systems:</strong> ${{systems.length}}<br>
                    <strong>Core Regions:</strong> ${{regions.filter(r => r.is_core).length}}<br>
                    <strong>Outlaw Regions:</strong> ${{regions.filter(r => !r.is_core).length}}
                `;
                
                window.addEventListener('resize', onWindowResize);
            }}
            
            function makeTextSprite(message, parameters) {{
                if (parameters === undefined) parameters = {{}};
                const fontface = parameters.hasOwnProperty("fontface") ? parameters["fontface"] : "Arial";
                const fontsize = parameters.hasOwnProperty("fontsize") ? parameters["fontsize"] : 18;
                const canvas = document.createElement('canvas');
                const context = canvas.getContext('2d');
                context.font = fontsize + "px " + fontface;
                context.fillStyle = "rgba(255, 255, 255, 1.0)";
                context.fillText(message, 0, fontsize);
                
                const texture = new THREE.Texture(canvas);
                texture.needsUpdate = true;
                const spriteMaterial = new THREE.SpriteMaterial({{ map: texture }});
                const sprite = new THREE.Sprite(spriteMaterial);
                sprite.scale.set(5000, 2500, 1.0);
                return sprite;
            }}
            
            function animate() {{
                requestAnimationFrame(animate);
                controls.update();
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
