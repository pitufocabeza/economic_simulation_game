from enum import Enum


class GoodsCategory(str, Enum):
    energy = "Energy"
    metal = "Metal"
    organic = "Organic"
    gaseous = "Gaseous"
    chemical = "Chemical"
    exotic = "Exotic"
    biotech= "Biotech"


class GoodsRarity(str, Enum):
    common = "Common"
    rare = "Rare"
    exotic = "Exotic"