ALL_GOODS = [
    # Raw Materials
    {"name": "Iron Ore", "primary_category": "raw", "subcategory": "metal", "rarity": "common"},
    {"name": "Copper Ore", "primary_category": "raw", "subcategory": "metal", "rarity": "common"},
    {"name": "Titanium Ore", "primary_category": "raw", "subcategory": "metal", "rarity": "rare"},
    {"name": "Quartz", "primary_category": "raw", "subcategory": "mineral", "rarity": "common"},
    {"name": "Coal", "primary_category": "raw", "subcategory": "energy", "rarity": "common"},
    {"name": "Hydrogen", "primary_category": "raw", "subcategory": "energy", "rarity": "common"},
    {"name": "Aluminum Ore", "primary_category": "raw", "subcategory": "metal", "rarity": "common"},
    {"name": "Zinc Ore", "primary_category": "raw", "subcategory": "metal", "rarity": "common"},
    {"name": "Lead Ore", "primary_category": "raw", "subcategory": "metal", "rarity": "rare"},
    {"name": "Nickel Ore", "primary_category": "raw", "subcategory": "metal", "rarity": "rare"},
    {"name": "Gold", "primary_category": "raw", "subcategory": "precious metal", "rarity": "rare"},
    {"name": "Platinum", "primary_category": "raw", "subcategory": "precious metal", "rarity": "exotic"},
    {"name": "Palladium", "primary_category": "raw", "subcategory": "precious metal", "rarity": "exotic"},
    {"name": "Uranium", "primary_category": "raw", "subcategory": "radioactive", "rarity": "rare"},
    {"name": "Plutonium", "primary_category": "raw", "subcategory": "radioactive", "rarity": "rare"},
    {"name": "Helium-3", "primary_category": "raw", "subcategory": "fusion fuel", "rarity": "exotic"},
    {"name": "Biomass", "primary_category": "raw", "subcategory": "organic material", "rarity": "common"},
    {"name": "Wood", "primary_category": "raw", "subcategory": "organic material", "rarity": "common"},
    {"name": "Nitrogen", "primary_category": "raw", "subcategory": "gaseous", "rarity": "common"},
    {"name": "Oxygen", "primary_category": "raw", "subcategory": "gaseous", "rarity": "common"},

    # Intermediate Products - Metals
    {"name": "Steel Plate", "primary_category": "intermediate", "subcategory": "metal", "rarity": "common"},
    {"name": "Steel Beam", "primary_category": "intermediate", "subcategory": "metal", "rarity": "common"},
    {"name": "Copper Wire", "primary_category": "intermediate", "subcategory": "metal", "rarity": "common"},
    {"name": "Titanium Alloy", "primary_category": "intermediate", "subcategory": "metal", "rarity": "rare"},
    {"name": "Aluminum Sheet", "primary_category": "intermediate", "subcategory": "metal", "rarity": "common"},
    {"name": "Gold Bar", "primary_category": "intermediate", "subcategory": "precious metal", "rarity": "rare"},
    {"name": "Platinum Bar", "primary_category": "intermediate", "subcategory": "precious metal", "rarity": "exotic"},
    
    # Intermediate Products - Construction
    {"name": "Reinforced Concrete", "primary_category": "intermediate", "subcategory": "construction", "rarity": "common"},
    {"name": "Glass Panels", "primary_category": "intermediate", "subcategory": "construction", "rarity": "common"},
    {"name": "Insulation Material", "primary_category": "intermediate", "subcategory": "construction", "rarity": "common"},
    {"name": "Ceramic Tiles", "primary_category": "intermediate", "subcategory": "construction", "rarity": "common"},
    
    # Intermediate Products - Electronics
    {"name": "Circuit Board", "primary_category": "intermediate", "subcategory": "electronics", "rarity": "common"},
    {"name": "Microprocessor", "primary_category": "intermediate", "subcategory": "electronics", "rarity": "rare"},
    {"name": "Sensor Array", "primary_category": "intermediate", "subcategory": "electronics", "rarity": "rare"},
    {"name": "Power Cell", "primary_category": "intermediate", "subcategory": "electronics", "rarity": "common"},
    {"name": "Battery Pack", "primary_category": "intermediate", "subcategory": "electronics", "rarity": "common"},
    
    # Intermediate Products - Chemicals
    {"name": "Plastic Polymers", "primary_category": "intermediate", "subcategory": "chemical", "rarity": "common"},
    {"name": "Rubber", "primary_category": "intermediate", "subcategory": "chemical", "rarity": "common"},
    {"name": "Lubricant", "primary_category": "intermediate", "subcategory": "chemical", "rarity": "common"},
    {"name": "Coolant", "primary_category": "intermediate", "subcategory": "chemical", "rarity": "common"},
    {"name": "Fuel Cells", "primary_category": "intermediate", "subcategory": "chemical", "rarity": "common"},
    
    # Intermediate Products - Advanced Materials
    {"name": "Carbon Fiber", "primary_category": "intermediate", "subcategory": "advanced material", "rarity": "rare"},
    {"name": "Superconductor", "primary_category": "intermediate", "subcategory": "advanced material", "rarity": "exotic"},
    {"name": "Nanomaterial", "primary_category": "intermediate", "subcategory": "advanced material", "rarity": "exotic"},

    # Finished Goods - Components
    {"name": "Control Unit", "primary_category": "finished", "subcategory": "component", "rarity": "rare"},
    {"name": "Hydraulic System", "primary_category": "finished", "subcategory": "component", "rarity": "common"},
    {"name": "Life Support Module", "primary_category": "finished", "subcategory": "component", "rarity": "rare"},
    {"name": "Navigation System", "primary_category": "finished", "subcategory": "component", "rarity": "rare"},
    {"name": "Communication Array", "primary_category": "finished", "subcategory": "component", "rarity": "rare"},
    {"name": "Thruster Unit", "primary_category": "finished", "subcategory": "component", "rarity": "rare"},
    {"name": "Shield Generator", "primary_category": "finished", "subcategory": "component", "rarity": "exotic"},
    
    # Finished Goods - Machinery
    {"name": "Industrial Robot", "primary_category": "finished", "subcategory": "machinery", "rarity": "rare"},
    {"name": "Excavator", "primary_category": "finished", "subcategory": "machinery", "rarity": "common"},
    {"name": "Refinery Equipment", "primary_category": "finished", "subcategory": "machinery", "rarity": "rare"},
    {"name": "Mining Drill", "primary_category": "finished", "subcategory": "machinery", "rarity": "common"},
    {"name": "Power Generator", "primary_category": "finished", "subcategory": "machinery", "rarity": "common"},
    
    # Finished Goods - Vehicles
    {"name": "Transport Shuttle", "primary_category": "finished", "subcategory": "vehicle", "rarity": "rare"},
    {"name": "Cargo Hauler", "primary_category": "finished", "subcategory": "vehicle", "rarity": "common"},
    {"name": "Freighter", "primary_category": "finished", "subcategory": "vehicle", "rarity": "rare"},
    {"name": "Mining Vessel", "primary_category": "finished", "subcategory": "vehicle", "rarity": "rare"},
    
    # Finished Goods - Consumer & Luxury
    {"name": "Consumer Electronics", "primary_category": "finished", "subcategory": "consumer", "rarity": "common"},
    {"name": "Furniture", "primary_category": "finished", "subcategory": "consumer", "rarity": "common"},
    {"name": "Medical Supplies", "primary_category": "finished", "subcategory": "consumer", "rarity": "common"},
    {"name": "Food Rations", "primary_category": "finished", "subcategory": "consumer", "rarity": "common"},
    {"name": "Luxury Goods", "primary_category": "finished", "subcategory": "luxury", "rarity": "rare"},
    {"name": "Exotic Crystals", "primary_category": "finished", "subcategory": "luxury", "rarity": "exotic"},
    {"name": "Artwork", "primary_category": "finished", "subcategory": "luxury", "rarity": "exotic"},
    
    # Finished Goods - Military/Defense
    {"name": "Weapon System", "primary_category": "finished", "subcategory": "military", "rarity": "rare"},
    {"name": "Armor Plating", "primary_category": "finished", "subcategory": "military", "rarity": "rare"},
    {"name": "Missile Launcher", "primary_category": "finished", "subcategory": "military", "rarity": "exotic"},
    
    # Finished Goods - Infrastructure
    {"name": "Habitat Module", "primary_category": "finished", "subcategory": "infrastructure", "rarity": "rare"},
    {"name": "Orbital Platform", "primary_category": "finished", "subcategory": "infrastructure", "rarity": "exotic"},
    {"name": "Space Station Component", "primary_category": "finished", "subcategory": "infrastructure", "rarity": "exotic"},
]