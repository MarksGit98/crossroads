---
name: add-creature-card
description: "Add a new player creature card to the game. Walks through the full pipeline: art relocation, SpriteFrames generation, scene inheritance, CardData factory with variant-grouped actives/passives, and deck registration. Use whenever the user says 'add a new creature', 'create a new card', or similar."
argument-hint: "[creature name]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Edit, Bash
---

# Adding a new creature card

Every creature follows the same 6-step pipeline. The skill enforces our folder conventions and the variant-grouped `{regular, upgraded}` schema for abilities. Skipping steps leaves broken references.

## Project conventions (hard rules)

1. **No code references to `sample images/`.** That folder is raw input only. Art that ships in gameplay lives under `assets/`.
2. **Directory layout:**
   - Source animation frames → `assets/creatures/<snake_name>/animations/`
   - SpriteFrames resource → `resources/creatures/<class>/<snake_name>_frames.tres`
   - Scene → `scenes/creatures/<class>/<snake_name>.tscn`
   - CardData factory → `assets/data/cards/class_cards/<class>/creatures/<snake_name>.gd`
3. **Class enum value:** for now everything goes under `viking/` (the only populated class folder). The `card_class` field on CardData uses `CardTypes.Class.VIKING`. Any future "neutral / common" reclassification happens later.
4. **Variant-grouped format** for all `actives` and `passives` entries:
   ```gdscript
   card.actives = [{ "regular": {...}, "upgraded": {...} }]
   ```
   Use `{ "regular": {...} }` alone if there's no upgrade yet (the resolver falls back to it).

---

## Step 1 — Relocate the art

Copy (don't leave in `sample images/`):
```bash
mkdir -p "assets/creatures/<snake_name>/animations"
cp "sample images/<source>/..." "assets/creatures/<snake_name>/animations/<anim>.png"
```

**Canonical animation names** (expected by `CreatureStateMachine` and `_pick_basic_attack_anim`):

| Name | Loop | Required? | Notes |
|---|---|---|---|
| `idle` | yes | ✓ | fallback for scale / stats bar sizing uses this |
| `walk` | yes | ✓ | plays during movement tweens |
| `attack01` | no | ✓ | basic attack variant A |
| `attack02` | no | — | optional; engine cycles 50/50 between 01 and 02 when both present |
| `take_hit` / `hurt` | no | — | plays on damage — if source art lacks it, use first N frames of death strip |
| `death` | no | ✓ | last frames of life |
| `heavy_attack` OR `heavy_attack_start` + `heavy_attack_loop` + `heavy_attack_end` | no (start/end), yes (loop) | — | the 3-phase form is for boss-style specials like the Minotaur; having any of these auto-flags `has_heavy_attack = true` |

If the source lacks take_hit, document which die-strip frames are being reused (e.g. "first 3 frames = take_hit, last 3 = death").

## Step 2 — Generate the SpriteFrames

For **individual-frame folders** (each png is one frame, numbered):
```javascript
// Run via `node -e "..."` — see resources/creatures/viking/axed_marauder_frames.tres for reference output.
// Reads a folder of Attack1.png, Attack2.png, ... and builds a single animation entry with one ExtResource per frame.
```

For **sprite-strip PNGs** (all frames in one image, e.g. 288×48 strip of 6 × 48×48 frames):
```javascript
// See resources/creatures/viking/rusalka_frames.tres.
// Uses AtlasTexture sub_resources with Rect2(col * frame_w, 0, frame_w, frame_h) regions.
```

Both patterns already exist in the repo — read `axed_marauder_frames.tres` (folder-based) or `rusalka_frames.tres` (strip-based) to copy the template.

**Never** hand-author the .tres file in the editor — always generate via script so frame counts, speeds, and loop flags are explicit in the commit diff.

## Step 3 — Create the scene

`scenes/creatures/<class>/<snake_name>.tscn`:

```gdscript
[gd_scene format=3 uid="uid://<unique>"]

[ext_resource type="PackedScene" uid="uid://dhmnojgcubeqc" path="res://scenes/creatures/creature.tscn" id="1_base"]
[ext_resource type="Script" uid="uid://cbw8skgcjltof" path="res://scripts/creatures/viking_creature.gd" id="2_script"]
[ext_resource type="SpriteFrames" path="res://resources/creatures/<class>/<snake_name>_frames.tres" id="3_frames"]

[node name="<PascalName>" unique_id=<unique int> instance=ExtResource("1_base")]
script = ExtResource("2_script")
## See Step 4 table for target_display_height values.
target_display_height = 180.0

[node name="AnimatedSprite2D" parent="." index="0" unique_id=48825108]
sprite_frames = ExtResource("3_frames")
```

## Step 4 — Choose `target_display_height` (pixels)

Absolute pixel target. Pick based on source art tightness + intended silhouette:

| Size class | Pixels | When |
|---|---|---|
| Tiny / caster-support | 100–120 | Tight frames (e.g., Rusalka 48×48 at 100) |
| Small / scrappy | 120–140 | Axed Marauder (80×120 frames at 120) |
| Standard humanoid | 160–200 | Default most units — Knight, Soldier, etc. (180) |
| Heavy / elite | 220–260 | Elite Orc, Knight Templar — broader silhouette |
| Boss / legendary | 260–320 | Minotaur-scale units |

If unsure, start at 180 (the class default) and adjust after seeing it on the board.

## Step 5 — Create the CardData factory

`assets/data/cards/class_cards/<class>/creatures/<snake_name>.gd`:

```gdscript
## <Name> — one-line pitch of role + flavor.
## Two-line description of the intended gameplay role (tank, striker,
## support, controller, etc.) and a mechanical hook so a reader grasps
## what makes this card distinct.
static func data() -> CardData:
	var card := CardData.new()

	# Identity
	card.id = "<class>_<snake_name>"              # must start with <class>_ (deck lookup)
	card.card_name = "<Display Name>"
	card.card_type = CardTypes.CardType.CREATURE
	card.card_class = CardTypes.Class.VIKING       # see conventions above
	card.rarity = CardTypes.Rarity.COMMON          # COMMON/UNCOMMON/RARE/EPIC/LEGENDARY
	card.flavor = "Player-facing flavor quote."

	# Cost
	card.cost_type = CardTypes.CostType.MANA
	card.cost_value = 3                            # typical 2–5

	# Stats
	card.role = CardTypes.CreatureRole.STRIKER     # TANK/STRIKER/SUPPORT/CONTROLLER/ASSASSIN/ARTILLERY
	card.atk = 2
	card.hp = 4
	card.armor = 0
	card.move_range = 2
	card.move_pattern = CardTypes.MovePattern.STANDARD
	card.attack_range = 1
	card.attack_pattern = CardTypes.AttackPattern.MELEE
	card.damage_type = CardTypes.DamageType.PHYSICAL

	# Keywords — add RANGED if attack_range > 1 (also gates perform_attack's
	# walk-up behavior). Other common ones: FLYING, TAUNT, LIFESTEAL, SWIFT.
	card.keywords = []

	# Passives — variant-grouped. Each entry is either:
	#   a) { "regular": {...}, "upgraded": {...} }  — upgrade-aware
	#   b) { "regular": {...} }                     — no upgrade variant yet
	#   c) flat dict                                — legacy flat format
	# Accessor Creature.get_passives() resolves per instance is_upgraded.
	card.passives = [
		# Example — end-of-turn trigger:
		# {
		# 	"regular": {
		# 		"id": "<snake_name>_passive_id",
		# 		"name": "Display Name",
		# 		"description": "Tooltip text.",
		# 		"type": CardTypes.PassiveType.ON_TRIGGER,
		# 		"trigger": CardTypes.TriggerType.END_OF_TURN,
		# 		"effects": [{ ...effect dict... }],
		# 	},
		# },
	]

	# Actives — same variant-grouped format. Standard fields per ability:
	#   id, name, description, cost, range, cooldown, target_rule, effects[]
	# Optional: required_charge_id + starting_charges for deployable-throw
	# abilities (see Axed Marauder / ThrownAxe pattern).
	card.actives = []

	# Creature scene
	card.creature_scene_path = "res://scenes/creatures/<class>/<snake_name>.tscn"

	return card
```

### Active ability dict shape

```gdscript
"regular": {
	"id": "<snake>_<action>",
	"name": "Display Name",
	"description": "Tooltip — shown via action menu hover.",
	"cost": 1,                                                  # mana (or other cost_type)
	"cost_type": CardTypes.CostType.MANA,                       # optional; defaults to MANA
	"range": 2,                                                 # hex range from caster
	"cooldown": 2,                                              # turns
	"target_rule": CardTypes.TargetRule.ANY_ENEMY,              # see enum for options
	"effects": [{                                               # resolved via Creature.apply_effect
		"type": CardTypes.EffectType.DEAL_DAMAGE,               # existing EffectType
		"target": CardTypes.EffectTarget.SELECTED,              # or CASTER / ALL_ENEMIES_IN_AREA / etc.
		"damage_type": CardTypes.DamageType.PHYSICAL,
		"value": 3,
	}],
}
```

If you need a new gameplay verb (THROW_X, APPLY_ZONE, etc.), use the **add-card-effect-type** skill first to register the EffectType + dispatcher branch, then reference it here.

## Step 6 — Register in the test deck

Append the card id to `EXAMPLE_DECK` in `scripts/cards/deck.gd`. Alphabetical order within the Creatures/Spells/Equipment sections.

---

## Verification

After writing all files:

1. **No sample-images refs:** `Grep "sample images" scripts/ assets/ resources/ scenes/` — must be empty for the new creature's paths
2. **Card id starts with class prefix** (e.g., `viking_<name>`) so `CardDatabase.get_card()` lookups succeed
3. **Scene references match:**
   - CardData.creature_scene_path → the `.tscn` you created
   - `.tscn` sprite_frames ExtResource → the `.tres` you generated
   - `.tres` ExtResources → the PNGs you copied
4. **Deck entry:** open the test scene — the creature should spawn in hand after a draw

## Common pitfalls

- **Missing `take_hit`/`hurt`**: causes a silent no-op when damaged; combat still resolves but there's no flinch animation. Pulling 3 frames from the death strip is the standard workaround.
- **Forgot RANGED keyword on `attack_range > 1`**: creature walks into melee range before attacking (see `Creature.is_ranged_attacker()`). Either add the keyword or rely on attack_range > 1 check — the code handles both.
- **Variant-grouped with missing `regular`**: the resolver prefers `regular` and falls back to `upgraded`. An entry with ONLY `upgraded` still works but reads oddly. Always include `regular` unless the ability literally can't exist un-upgraded.
- **Oversized sprite**: if the creature dwarfs the board, lower `target_display_height` on the scene. Do not edit `sprite_scale_factor` — it's legacy and ignored.
- **Unused actives/passives array entries**: an empty `{}` or a dict without a `type` silently no-ops. Always fill or omit.

## Reference files

Ask me to read these to crib patterns:
- Full example with variants: `assets/data/cards/class_cards/viking/creatures/wizard.gd`
- Deployable-charge ability: `assets/data/cards/class_cards/viking/creatures/axed_marauder.gd`
- Strip-based SpriteFrames: `resources/creatures/viking/rusalka_frames.tres`
- Folder-based SpriteFrames: `resources/creatures/viking/axed_marauder_frames.tres`
- Architecture overview: `docs/architecture/gameplay-flow.md`
