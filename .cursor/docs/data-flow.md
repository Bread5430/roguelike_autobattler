# Data Flow

1. **Map exploration**: Player selects nodes in `MapManager`
2. **Battle prep**: `GUI` enables deployment mode; places units from inventory using `FORMATION_MAP`; spells from inventory (click) go to `SpellBar`; right-click spell bar slot returns spell to inventory
   - Inventory right-click opens item details card (unit: glossary stats/blurb + deployment info; spell: cooldown + mana cost)
3. **Battle active**: `BattleManager` spawns enemies, runs flow simulation, updates units; spell bar click enters casting mode (preview under mouse), click to cast or right-click/Escape to cancel
4. **Post-battle**: Return to map, update progress
