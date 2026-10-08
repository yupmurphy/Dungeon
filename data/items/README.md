# Item tables

The items in `resources/items/` are **generated** from the tables in this folder. Never edit those files by hand.

To change items:
1. Edit a table in Notepad. Excel can change the format.
2. Save it.
3. Double-click `tools/generate_items.bat`.

If something is wrong, the generator writes nothing. It prints `ERROR` with the table, the line and the problem.

Zero, or an empty cell, means "gives nothing".

## How an item gets its values

```
value = tier_rules[role, tier] x slot_rules.scale  +  slot_bonuses[slot, tier]
```

Then the `special` column of `items.csv` sets exact values on top. Use it only for special items.

Example: Leggings (pants, leather, tier D) get:
- defense: 6 x 0.7 = 4.2;
- the bonus of pants at tier D: carry_weight 3 and exhaustion_gain -0.016.

## The tables

| Table | One row per | What it holds |
| --- | --- | --- |
| `items.csv` | item | `id, name, slot, tier, role, set_id, sprite, source, special` |
| `tier_rules.csv` | role and tier | Every stat of that role at that tier, one column per stat, for a full-size piece (body, weapon, amulet). |
| `slot_bonuses.csv` | slot and tier | What the slot adds by itself. Boots: speed. Helmet: sight and light. Gloves: attack speed and crit. Pants: carry weight and less exhaustion. Body: health. Amulet: magic. Ring: crit damage. |
| `slot_rules.csv` | slot | `group` (armor / weapon / jewelry), `scale` (share of the role values), `drawn` (1 = visible on the character). |
| `roles.csv` | role | `group`, and for weapons: `melee` (1 / 0), `splash` (1 / 0), `attack_range`. |
| `stats.csv` | stat | `kind`, and what the stat means. |

### items.csv columns

| Column | Meaning |
| --- | --- |
| id | Unique id, never changed once used (saves, drops). Letters, digits and `_`. |
| name | The name shown in the game. |
| slot | body, pants, boots, helmet, gloves, weapon, amulet, ring. |
| tier | F, D, C, B, A, S (F = weakest). |
| role | A role from `roles.csv` of the same group as the slot. A dagger can't be a helmet. |
| set_id | The set the item belongs to (sets table, stage 4). Empty = none. |
| sprite | The LPC art that draws it. Empty for slots that aren't drawn (jewelry, gloves for now). |
| source | Where the item comes from: start, shop_smithy, shop_general, drop_goblin, drop_forest... |
| special | Only for special items: exact values that replace or add stats, e.g. `crit_chance=0.05;knockback=0.3`. |

### Stat kinds (stats.csv)

| Kind | Meaning |
| --- | --- |
| bonus | Added to whoever wears the item. |
| item | A property of the item itself (weight, price). |
| weapon | A property of a weapon, from its role (melee, splash, attack_range). |

Percentages are fractions: 0.05 = +5%.

## What you can do on your own (no code)

| What | How |
| --- | --- |
| Change a value | Edit the number in `tier_rules.csv` or `slot_bonuses.csv`. |
| Add an item | Add a row to `items.csv`. Use an existing sprite, or leave it empty for jewelry. |
| Remove an item | Delete its row. The generator deletes its file. |
| Make a special item | Write `stat=value;stat=value` in its `special` cell. |
| Add a role (e.g. `hammer`) | Add a row to `roles.csv`, then 6 rows to `tier_rules.csv` (`hammer,F` ... `hammer,S`). |
| Add a stat (e.g. `poison_resistance`) | Add a row to `stats.csv` (`poison_resistance,bonus,...`). In `tier_rules.csv` and/or `slot_bonuses.csv`, add `,poison_resistance` at the END of the first line, then `,value` only at the end of the rows that need it: shorter rows count as 0. A table without the column counts as 0 everywhere. Items then carry it. Making it **do** something in the game needs code. |
| Change how big a slot's share is | Change `scale` in `slot_rules.csv`. |

## What needs code

- A new slot.
- New tier letters.
- The effect of a brand new stat in the game.
