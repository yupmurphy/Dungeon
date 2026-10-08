# Item tables

The items in `resources/items/` are GENERATED from these tables. Never edit them by hand. Edit a table, then
double-click `tools/generate_items.bat`, or run `-- --generate-items`. Open the tables in a text editor (Notepad);
Excel can change the format.

## items.csv

One row per item:

| Column | Meaning |
| --- | --- |
| id | Unique id, never changed once used (saves, drops). Letters, digits and `_`. |
| name | The name shown in the game. |
| slot | torso, legs, feet, helmet or weapon. Hair is a look, not an item. |
| tier | 1 = starting gear; higher is better. |
| role | Armor: cloth, leather, plate. Weapons: light, balanced, heavy, reach. |
| set_id | The set the item belongs to (sets table, stage 4). Empty = none. |
| sprite | The LPC item that draws it (assets/lpc/catalog.json). Several items can share one sprite. |
| source | Where the item comes from: start, shop_smithy, shop_general, drop_goblin, drop_forest... |
| overrides | ONLY for special items. Exact values that replace the rule values, e.g. `crit_chance=0.05;knockback=0.3`. |

## tier_rules.csv

The bonuses of every role at every tier, for a torso-sized piece (or a weapon), for example
`defense=7;move_speed=-0.04`. Every role and tier used in `items.csv` needs a row here.

## slot_rules.csv

Each slot's share of the tier rule values (scale). For example, a legs piece of leather tier 2 gets 0.7 x 7 = 4.9
defense.

## Stats

Percentages are written as fractions: 0.05 = +5%.

| Stat | Effect |
| --- | --- |
| defense | Flat defense. |
| evade | Chance that enemies miss you. |
| move_speed | Movement speed. |
| attack_speed | Attack speed. |
| damage | Damage bonus. |
| knockback | Knockback. |
| crit_chance | Critical chance. |

Stage 3 makes these stats count in the game.
