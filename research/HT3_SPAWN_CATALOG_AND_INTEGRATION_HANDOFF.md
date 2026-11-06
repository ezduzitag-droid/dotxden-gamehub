# Hard Time III v1.1.8 — Spawn-Item Native Research, Asset Catalog and Embedded-Menu Integration Handoff

**Research date:** 2026-11-06 (America/Los_Angeles)  
**Purpose:** Hand this document to the other ChatGPT session, where the user reports that the **floating menu is already embedded in the APK and existing GG-derived stat/address bindings are working**. The next feature is a real **Spawn Items** section that invokes the game's own stock/entity creation routines, places selected objects directly in front of the active player, and presents distinct weapon/item/tool/furniture/vehicle categories.  
**Research status:** **Original uploaded XAPK directly examined**; native game factory paths and actor position copies statically verified; source asset labels catalogued; **no spawn action performed on the user's currently embedded APK** in this session.  
**IMPORTANT:** Treat the user's successful embedded-menu/binding report as the **latest project state**. Prior CP004/menu-only handoffs are historical. The currently working menu-enabled signed APK and its Android/IL2CPP command bridge were **not supplied here**, so exact bridge names, latest binary hashes, and runtime dispatch capabilities must be inspected in the other session, not invented.

## 1. Primary resources and version-sensitive boundaries

| Source | Role |
|---|---|
| **Original user-uploaded XAPK** — \`Hard Time III_1.1.8(1).xapk\` | Directly re-examined; SHA-256 \`07b0393458a8e11f570c421342113937ed35ea362304adee08b754669d7ddc03\`, 294,671,941 bytes. Multiple Library copies appear to match this original. |
| **Original IL2CPP metadata** — \`base.apk/assets/bin/Data/Managed/Metadata/global-metadata.dat\` | 7,306,836 bytes; metadata format 39. |
| **Original ARM64 native module** — \`split_1.apk/lib/arm64-v8a/libil2cpp.so\` | 54,278,448 bytes; SHA-256 \`fb06deda27c22077fb6963a4df3b57de977c4ea5c291aee03e8675d61940549d\`. |
| **Serialized asset source** — \`split_0.apk/assets/bin/Data/datapack.unity3d\` | UnityFS archive; nested \`resources.assets\` contains two verified contiguous source-label groups used in the catalog below. These are strings, not numeric IDs. |
| [Current GG Lua source](https://github.com/ezduzitag-droid/dotxden-gamehub/blob/main/data/node_6f2e9a.lua) | v2.1.1 stat/actor-pointer research reference; **not itself a spawn implementation**. |
| [Previous native spawn audit](https://github.com/ezduzitag-droid/dotxden-gamehub/blob/main/research/HT3_Spawn_API_Audit_2026-11-04.md) | Previously resolved factory/second allocator and limitations; independently checked against source binary in this research. |
| [Embedded-menu visual source](https://github.com/ezduzitag-droid/dotxden-gamehub/blob/main/data/ht3-control-studio.html) | Earlier standalone HTML. **May lag the user's now-functional embedded APK/menu:** inspect the working embedded copy before editing UI. |
| [PC mod cross-reference](https://github.com/IngoHHacks/HardTimeKeybindCheats/blob/main/Plugin.cs) | External *PC* source showing \`MappedWeapons.Add(0)\`, \`MappedItems.Add(0)\`, \`MappedWeapons.Produce(83,...)\`. Helpful corroboration, **not** a validated Android ID map/ABI. |

**ELF RVA caution:** The addresses below are **native virtual addresses/RVAs in the original ARM64 build**, not absolute process addresses, ZIP offsets, or guaranteed offsets in a later modified build. Check the exact target \`libil2cpp.so\` hash and loaded mapping. When the ELF has separately mapped segments, compute the mapping base correctly; do not add an RVA to an arbitrary \`/proc/maps\` line without checking its file offset.

## 2. Executive findings

1. **Actual positioned creation function identified:** \`IFCBDBGCKJA.CGLILJCFENK\` at RVA **\`0x1530160\`** takes six explicit parameters consistent with **\`(type, x, y, z, angle, scale)\`**. It invokes an allocator/registrar, then positions the returned object. The original game's ARM64 callsites actually use this function; it is **not** merely an unused metadata name.
2. **Native Android type-argument evidence:** constant **83** and an RNG-selected value between **88 and 91** are passed to the positioned weapon/stock factory. **Object identities are unknown**. Do **not** equate 83 with catalog row 83 or invent names such as Knife/Slingshot for these numbers.
3. **A distinct second stock manager exists:** \`CAIHMLHBPMF\` with allocation method RVA **\`0x16D1B9C\`**. It may correspond to furniture/item placement, but its exact object category, named IDs, positioned creation path and scene materialization still require resolution.
4. **Important disambiguation:** the second manager's initializer was observed with \`Stock.type\` **1 or 2** and **location codes 14, 18, 23, 24, 46, 48, 49**. Those location numbers are **not object IDs**; \`1\`/\`2\` should not be named chairs/food without further evidence.
5. **Coordinate and facing fields located in this source XAPK**: the active actor's world position maps to offsets **+0x48 (X), +0x4C (Y), +0x50 (Z), +0x78 (angle)**; stored Character coordinates and angle are **+0xF0, +0xF4, +0xF8, +0xFC**. The ARM64 initializer copies these values; inspect the live actor after movement before trusting its angle as forward direction.
6. **Asset catalog extracted:** **113** item-like labels and **35** object/furniture/vehicle labels in the actual nested \`resources.assets\`. All **148 source ordinals are NOT numeric spawn IDs**. A visible object name, an engine stock type, a location index, a prefabricated GameObject and a factory argument are distinct concepts.
7. **Vehicles remain separate:** car/motorcycle **asset names exist**, but no safe drivable vehicle-spawning method or numeric vehicle-ID mapping has been established. Do not send vehicle labels into the weapon-stock factory.
8. **New menu feature must call an actual native game factory** on the correct game/Unity execution context; writing numeric memory values or appending uninitialized pointers to Stock arrays cannot spawn a fully registered scene entity.

### 2.1 Confirmed numeric/code evidence (NOT a complete ID catalog)

| Value / RVA | Domain | What the code actually supports | Evidence quality |
|---|---|---|---|
| \`83\` | \`IFCBDBGCKJA\` positioned factory argument | Existing original Android callsites pass 83 as requested type | **Verified in static ARM64 code**; display name and runtime spawning **not tested** |
| \`88..91\` | Same positioned factory | Existing Android callsite requests an RNG value using bounds 88 and 91; meaning depends on RNG semantics | **Verified range-bound inputs**; four individual observed runtime IDs **not yet established** |
| \`0\` | \`MappedWeapons.Add\` / \`MappedItems.Add\` in PC mod | Random/default creation request in external **PC** implementation | **PC-only reference**; NOT universal Android \`type_id=0\` |
| \`1,2\` | \`Stock.type\` values in second-manager initializer | Values copied into stock record by initialization routines | **Verified typed fields**, but not a named catalog |
| \`14,18,23,24,46,48,49\` | \`Stock.location\` | Scene/location identifiers in second manager initialization | **Verified locations**, explicitly **NOT item/vehicle IDs** |
| \`0x1530160\` | \`IFCBDBGCKJA.CGLILJCFENK\` | Positioned stock/weapon factory | **Static execution/calls verified**, invocation from embedded UI pending |
| \`0x1526114\` | \`IFCBDBGCKJA.HBALMHCPLKM\` | Weapon-side object allocation/registration | **Static call trace verified** |
| \`0x152604C\` | \`IFCBDBGCKJA.AKKIOODJGNM\` | Type validator | **Static call trace verified**; no universal contiguous valid-type range |
| \`0x16D1B9C\` | \`CAIHMLHBPMF.HBALMHCPLKM\` | Separate managed stock allocation/registration | **Static execution trace verified**; identity and placement pending |
| \`0x165957C\` | \`Stock.JFEMFOPPBIL\` | Populates \`Stock.type\` and \`Stock.location\` | **Static field writes verified**; not an independent safe Unity-spawn call |
| \`0x16A92FC\` | \`World.LAPKJLMHCGE\` | Indexed world-state updater | **Not a verified vehicle constructor** |

## 3. Player coordinates: newly recovered exact mappings

### 3.1 Field table and layout, directly decoded from the user's XAPK

The IL2CPP metadata field definitions were decoded and cross-checked against the native field-offset table, with known GG fields (live health/spirit/injury and Character stat) as sanity checks. The source ELF has a field-offset table at **ELF file offset \`0x76E988\`**, which is not a universal cross-build location.

| Data owner | Field | Relative offset | Representation / interpretation |
|---|---|---|---|
| \`Character\` stored record | \`x\` | \`+0xF0\` | Float32 |
| \`Character\` | \`y\` | \`+0xF4\` | Float32 |
| \`Character\` | \`z\` | \`+0xF8\` | Float32 |
| \`Character\` | \`angle\` | \`+0xFC\` | Float32 |
| \`Character\` | \`location\` | \`+0xEC\` | Int32 scene/location reference |
| **\`EFPJKAPKGOB\` active actor** | **X** (obfuscated \`HIDLCGMCHJD\`) | **\`+0x48\`** | **Float32** |
| **Active actor** | **Y** (\`CECPJOCEGKC\`) | **\`+0x4C\`** | **Float32** |
| **Active actor** | **Z** (\`BLKHODNLCED\`) | **\`+0x50\`** | **Float32** |
| **Active actor** | **angle** (\`KJPHAPAFKEO\`) | **\`+0x78\`** | **Float32** |

**Additional ARM64 proof** — actor initialization at **\`0x162B02C–0x162B05C\`** follows active actor \`+0x20\` to the stored Character, loads two floats from \`Character+0xF0\` into actor \`+0x48/+0x4C\`, loads another two from \`Character+0xF8\`, writes Z to actor \`+0x50\` and angle to actor \`+0x78\`. These are actual ARM64 load/store instructions, not inferred only from similar-looking field order.

**Critical runtime caveat:** These registers show how the actor is **initialized**. They do **not** independently prove that actor X/Y/Z/angle are updated continuously during gameplay, or establish angle units/sign convention. Verify live coordinates while walking and turning on the target game before using them for production spawning.

### 3.2 Locate the correct player — reuse the existing working binding

The existing GG resolver already knows the safe identity chain:

\`Characters.cStar\` (active Character record) → \`LOCECKLDEDA\` active-actor manager array → **unique** \`EFPJKAPKGOB\` actor whose Character reference at \`actor+0x20\` equals \`Characters.cStar\`.

For the spawning bridge, **reuse the validated active actor resolver** from the functioning embedded menu if it already exposes this actor and checks scene/class identity. Do not choose actor index 0 or the nearest NPC on a guess. Cache an actor only for the current stable scene; **re-resolve after room changes/death/respawns**. Refuse to spawn if there is no unique valid player actor, a stale library mapping, nonfinite position, or the game is outside the Game scene.

### 3.3 Spawn directly in front of the character

**Preferred method:** obtain the real Unity actor object's **\`Transform.position\`** and normalized **\`Transform.forward\`** from a validated native/Unity bridge. Resolve ground/collider placement using engine collision/navigation logic when available.

**Fallback, only after live-calibrating angle conventions:** if the native bridge has validated \`actor.x/y/z/angle\` and the game angle is proven to use **degrees**, one candidate forward vector for Unity's X/Z plane is:

\`\`\`text
theta = actorAngleDegrees * pi / 180
forwardX = sin(theta)
forwardZ = cos(theta)
targetX = actorX + distance * forwardX
targetY = actorY + calibratedHeightOffset
targetZ = actorZ + distance * forwardZ
\`\`\`

This **is a hypothesis, not a verified orientation formula**. The game may use a different handedness, axis, offset or radians. Compare actor movement with actual heading at **0°, 90°, 180°, 270°**; if the computed forward points sideways/behind, correct sign/axes rather than hardcoding wrong formulas. Match the game's actual \`Produce(type,x,y,z,angle,scale)\` coordinate system.

**Conservative default for first spawn:** distance **1.5–2.0 game-world units** (tentative), scale **1.0** (tentative), **quantity 1**, no velocity, only after checking a safe clear spot. Ground heights and collision footprints differ for an apple versus an office desk or a car. Use a ground raycast / surface placement and item bounds where possible, prevent inside-wall or below-floor spawns, and never put vehicles through a weapon/prop factory.

### 3.4 Stock record coordinates — NOT sufficient by themselves

The managed \`Stock\` record contains the following **verified** fields: \`id+0x10\`, \`type+0x14\`, \`variant+0x18\`, \`scale+0x28\`, \`location+0x2C\`, \`x+0x30\`, \`y+0x34\`, \`z+0x38\`, \`angle+0x3C\`, \`origin+0x40\`, \`originX+0x44\`, \`originY+0x48\`, \`originZ+0x4C\`, \`originAngle+0x50\`. These fields help trace persistence and location bookkeeping. **Writing them into a random object or adding a raw pointer to a list does not execute factory initialization, scene registration, Unity rendering or collision creation.**

## 4. Actual native creation paths and unresolved categories

### 4.1 Weapon/handheld-stock factory — best first test

- Owner: \`IFCBDBGCKJA\` (metadata type index 24).
- Positioned function: \`CGLILJCFENK\`, metadata method index **273**, token **\`0x06000112\`**, native **\`0x1530160\`**, **6 explicit arguments**.
- From ARM64 argument flow and PC reference, signature is **consistent with** \`Produce(type,x,y,z,angle,scale)\`. Confirm the correct return type, internal convention, hidden \`MethodInfo*\` argument and any required runtime context before invoking.
- Positioned function calls \`HBALMHCPLKM\` at **\`0x1526114\`** to validate/allocate/register a stock object, obtains its registered index, then updates the created object’s position at **\`+0x50/+0x54/+0x58\`**, angle/rotation at **\`+0x6C/+0x98\`**, and scaling-related data at **\`+0xA0/+0xA4\`**.
- Native caller examples: \`EFPJKAPKGOB.CKHFEGNHFJP\` at **\`0x15A97A8\`** and **\`0x15A9858\`**; \`GDICAFINBED.IBILCPMOIKN\` has calls in the **\`0x16F4F8C–0x16F5258\`** range.
- The game's own code passes type **83** and values selected with bounds **88–91**, associated with limb/dismemberment effects. They may be special-purpose stock models. Start with a **single controlled, developer-approved test**, not a bulk scan of guessed integer IDs.

**First API test gate:** In actual gameplay, use the already embedded menu/native bridge to schedule **one** validated factory invocation on the game/Unity main thread; return a success result only after a manager index is valid **and a visible, interactable scene object exists**. A nonzero return, stock array length change, or memory readback alone is **not** sufficient.

### 4.2 Second stock / item / furniture manager — separate research gate

- \`CAIHMLHBPMF.HBALMHCPLKM(int,int)\`, token **\`0x06000600\`**, native **\`0x16D1B9C\`**.
- Calls \`CAIHMLHBPMF.LEHNPLAAMMJ\` at **\`0x16D1ED8\`**, allocates managed stock and registers it in a second manager's array/counter.
- Callers show **(0, loopIndex)** and **(managerStaticType, 0)** patterns. **Do not** interpret either zero as a universal spawn type.
- \`CAIHMLHBPMF.MGABOLMHDLK\` at **\`0x16D213C\`** initializes stocks through \`Stock.JFEMFOPPBIL\` at **\`0x165957C\`**. Observed \`Stock.type\` **1,2** and **location** 14/18/23/24/46/48/49.
- **Remaining work:** identify which asset/table/scene materializes these stocks, locate a *positioned* or equivalent safe scene-creation wrapper, identify manager type IDs and their asset names, and verify pickup/use/collision and cleanup in gameplay.
- Likely furniture/item counterpart from structural similarity and PC source, **but not yet category-verified in Android**.

### 4.3 Vehicle manager — independently unresolved

The original \`World\` type holds \`gVehicle\`, \`vehiclePosition\`, \`vehicleTarget\` and \`vehicleAccel\` fields; \`World.LAPKJLMHCGE\` at **\`0x16A92FC\`** updates indexed world state, but **has not been demonstrated to create vehicles**. Some car and motorcycle assets exist; **there is no verified numeric vehicle spawn ID or callable drivable-vehicle constructor**. Hold the Vehicle submenu in research/unavailable state until its own creation, physics, seat, wheel, collision and scene registration paths are resolved.

## 5. Categorized original-XAPK asset labels — complete audited extracts

The following **113** strings were read from a contiguous ASCII-name region of extracted \`datapack.unity3d/resources.assets\` near source offset **\`0x406EEE4–0x40706C4\`**. The following **35** were read from a separate contiguous region near **\`0x4084054–0x40847C4\`**. Exact offsets are from the **decompressed nested \`resources.assets\` file**, not the outer XAPK. The categories are **our proposed UI organization**, not an official decoded type taxonomy. A game may use a shovel as both tool and weapon. The numeric **source ordinal** below is **only the order encountered in this serialized name group**, emphatically **NOT an item ID, weapon ID, tool ID, furniture ID or vehicle ID**.

Items grouping counts: Weapons — ranged: 12; Weapons — melee / improvised: 24; Tools / equipment: 12; Food / drink: 17; Medicine / resources / consumables: 9; Sports / recreation: 9; Electronics / personal belongings: 11; Loose props / building parts: 19.

World grouping counts: Vehicle / mobility asset: 7; Furniture / fixtures: 19; World props / objects: 9.

**All \`Verified spawn ID\` entries are intentionally \`Unknown\` until independently linked to the actual corresponding native factory type and observed in-game.** Especially: source ordinal **83 = Slingshot** does **not** establish factory type argument **83 = Slingshot**; those systems must not be conflated.

### 5.1 Item/handheld asset labels (113 entries)

| Source group | Source ordinal (NOT ID) | Exact asset label | Proposed menu category | Verified spawn ID |
|---|---:|---|---|---|
| Handheld | 1 | Extinguisher | Tools / equipment | **Unknown** |
| Handheld | 2 | Shoe | Weapons — melee / improvised | **Unknown** |
| Handheld | 3 | Machine Gun | Weapons — ranged | **Unknown** |
| Handheld | 4 | Orange | Food / drink | **Unknown** |
| Handheld | 5 | Pillow | Loose props / building parts | **Unknown** |
| Handheld | 6 | Pallet | Loose props / building parts | **Unknown** |
| Handheld | 7 | Corn | Food / drink | **Unknown** |
| Handheld | 8 | Briefcase | Electronics / personal belongings | **Unknown** |
| Handheld | 9 | Plank | Weapons — melee / improvised | **Unknown** |
| Handheld | 10 | Burger | Food / drink | **Unknown** |
| Handheld | 11 | Football | Sports / recreation | **Unknown** |
| Handheld | 12 | Mobile Phone | Electronics / personal belongings | **Unknown** |
| Handheld | 13 | Taser | Weapons — ranged | **Unknown** |
| Handheld | 14 | Crutch | Tools / equipment | **Unknown** |
| Handheld | 15 | Pay Phone | Electronics / personal belongings | **Unknown** |
| Handheld | 16 | Baseball | Sports / recreation | **Unknown** |
| Handheld | 17 | Gift_Large | Loose props / building parts | **Unknown** |
| Handheld | 18 | Cue | Weapons — melee / improvised | **Unknown** |
| Handheld | 19 | Knife | Weapons — melee / improvised | **Unknown** |
| Handheld | 20 | Cardboard | Loose props / building parts | **Unknown** |
| Handheld | 21 | Bell | Loose props / building parts | **Unknown** |
| Handheld | 22 | Sign | Loose props / building parts | **Unknown** |
| Handheld | 23 | Basketball | Sports / recreation | **Unknown** |
| Handheld | 24 | Watermelon | Food / drink | **Unknown** |
| Handheld | 25 | Milk Bottle | Food / drink | **Unknown** |
| Handheld | 26 | Table Piece | Loose props / building parts | **Unknown** |
| Handheld | 27 | Steak | Food / drink | **Unknown** |
| Handheld | 28 | Step | Loose props / building parts | **Unknown** |
| Handheld | 29 | Picture | Loose props / building parts | **Unknown** |
| Handheld | 30 | Hockey Stick | Weapons — melee / improvised | **Unknown** |
| Handheld | 31 | Beer Bottle | Food / drink | **Unknown** |
| Handheld | 32 | Pipe | Weapons — melee / improvised | **Unknown** |
| Handheld | 33 | Barbed Bat | Weapons — melee / improvised | **Unknown** |
| Handheld | 34 | Cane | Weapons — melee / improvised | **Unknown** |
| Handheld | 35 | Egg | Food / drink | **Unknown** |
| Handheld | 36 | Table Leg | Loose props / building parts | **Unknown** |
| Handheld | 37 | Trophy | Loose props / building parts | **Unknown** |
| Handheld | 38 | Gift | Loose props / building parts | **Unknown** |
| Handheld | 39 | Cigarette | Medicine / resources / consumables | **Unknown** |
| Handheld | 40 | Wooden Board | Weapons — melee / improvised | **Unknown** |
| Handheld | 41 | Cage Piece | Loose props / building parts | **Unknown** |
| Handheld | 42 | Dynamite | Medicine / resources / consumables | **Unknown** |
| Handheld | 43 | Cricket Bat | Weapons — melee / improvised | **Unknown** |
| Handheld | 44 | Pick Axe | Tools / equipment | **Unknown** |
| Handheld | 45 | Ribs | Food / drink | **Unknown** |
| Handheld | 46 | Axe | Weapons — melee / improvised | **Unknown** |
| Handheld | 47 | Water Gun | Weapons — ranged | **Unknown** |
| Handheld | 48 | Syringe | Medicine / resources / consumables | **Unknown** |
| Handheld | 49 | Brass Knucks | Weapons — melee / improvised | **Unknown** |
| Handheld | 50 | Chicken Leg | Food / drink | **Unknown** |
| Handheld | 51 | Medical Kit | Medicine / resources / consumables | **Unknown** |
| Handheld | 52 | Bag | Electronics / personal belongings | **Unknown** |
| Handheld | 53 | Broom | Tools / equipment | **Unknown** |
| Handheld | 54 | Bazooka | Weapons — ranged | **Unknown** |
| Handheld | 55 | Hairdryer | Tools / equipment | **Unknown** |
| Handheld | 56 | iPad | Electronics / personal belongings | **Unknown** |
| Handheld | 57 | Beach Ball | Sports / recreation | **Unknown** |
| Handheld | 58 | Guitar | Weapons — melee / improvised | **Unknown** |
| Handheld | 59 | Hammer | Tools / equipment | **Unknown** |
| Handheld | 60 | Flame Thrower | Weapons — ranged | **Unknown** |
| Handheld | 61 | Bone | Weapons — melee / improvised | **Unknown** |
| Handheld | 62 | Tennis Ball | Sports / recreation | **Unknown** |
| Handheld | 63 | Spray Paint | Tools / equipment | **Unknown** |
| Handheld | 64 | Rock | Weapons — melee / improvised | **Unknown** |
| Handheld | 65 | Handcuffs | Tools / equipment | **Unknown** |
| Handheld | 66 | Screwdriver | Tools / equipment | **Unknown** |
| Handheld | 67 | Backpack | Electronics / personal belongings | **Unknown** |
| Handheld | 68 | Baseball Bat | Weapons — melee / improvised | **Unknown** |
| Handheld | 69 | Trashcan Lid | Weapons — melee / improvised | **Unknown** |
| Handheld | 70 | Tyre | Loose props / building parts | **Unknown** |
| Handheld | 71 | Skateboard | Sports / recreation | **Unknown** |
| Handheld | 72 | Dumbbell | Sports / recreation | **Unknown** |
| Handheld | 73 | Cash | Medicine / resources / consumables | **Unknown** |
| Handheld | 74 | Glass Pane | Loose props / building parts | **Unknown** |
| Handheld | 75 | Shovel | Tools / equipment | **Unknown** |
| Handheld | 76 | Revolver | Weapons — ranged | **Unknown** |
| Handheld | 77 | Magazine | Medicine / resources / consumables | **Unknown** |
| Handheld | 78 | Weight | Sports / recreation | **Unknown** |
| Handheld | 79 | Crossbow | Weapons — ranged | **Unknown** |
| Handheld | 80 | Tombstone | Loose props / building parts | **Unknown** |
| Handheld | 81 | Crowbar | Weapons — melee / improvised | **Unknown** |
| Handheld | 82 | Hotdog | Food / drink | **Unknown** |
| Handheld | 83 | Slingshot | Weapons — ranged | **Unknown** |
| Handheld | 84 | Key | Tools / equipment | **Unknown** |
| Handheld | 85 | Water Bottle | Food / drink | **Unknown** |
| Handheld | 86 | Fish | Food / drink | **Unknown** |
| Handheld | 87 | Book | Electronics / personal belongings | **Unknown** |
| Handheld | 88 | Uzi | Weapons — ranged | **Unknown** |
| Handheld | 89 | American Football | Sports / recreation | **Unknown** |
| Handheld | 90 | Robogun | Weapons — ranged | **Unknown** |
| Handheld | 91 | Battery | Medicine / resources / consumables | **Unknown** |
| Handheld | 92 | Microphone | Electronics / personal belongings | **Unknown** |
| Handheld | 93 | Banana | Food / drink | **Unknown** |
| Handheld | 94 | Apple | Food / drink | **Unknown** |
| Handheld | 95 | Luggage | Electronics / personal belongings | **Unknown** |
| Handheld | 96 | Rifle | Weapons — ranged | **Unknown** |
| Handheld | 97 | Handgun | Weapons — ranged | **Unknown** |
| Handheld | 98 | Chainsaw | Weapons — melee / improvised | **Unknown** |
| Handheld | 99 | Belt | Weapons — melee / improvised | **Unknown** |
| Handheld | 100 | Nightstick | Weapons — melee / improvised | **Unknown** |
| Handheld | 101 | Tennis Racket | Weapons — melee / improvised | **Unknown** |
| Handheld | 102 | Brick | Weapons — melee / improvised | **Unknown** |
| Handheld | 103 | Folded Chair | Loose props / building parts | **Unknown** |
| Handheld | 104 | Console | Electronics / personal belongings | **Unknown** |
| Handheld | 105 | Light Tube | Loose props / building parts | **Unknown** |
| Handheld | 106 | Ladder Piece | Loose props / building parts | **Unknown** |
| Handheld | 107 | Recorder | Electronics / personal belongings | **Unknown** |
| Handheld | 108 | Riot Shield | Tools / equipment | **Unknown** |
| Handheld | 109 | Tissue | Medicine / resources / consumables | **Unknown** |
| Handheld | 110 | Pizza | Food / drink | **Unknown** |
| Handheld | 111 | Golf Club | Weapons — melee / improvised | **Unknown** |
| Handheld | 112 | Ham | Food / drink | **Unknown** |
| Handheld | 113 | Ammo | Medicine / resources / consumables | **Unknown** |
 
### 5.2 Furniture/world/vehicle asset labels (35 entries)

| Source group | Source ordinal (NOT ID) | Exact asset label | Proposed menu category | Verified spawn ID |
|---|---:|---|---|---|
| World | 1 | Car_Van | Vehicle / mobility asset | **Unknown** |
| World | 2 | Stretcher | World props / objects | **Unknown** |
| World | 3 | Cardboard Box | World props / objects | **Unknown** |
| World | 4 | Desk | Furniture / fixtures | **Unknown** |
| World | 5 | Coffin | World props / objects | **Unknown** |
| World | 6 | Wheelchair | Vehicle / mobility asset | **Unknown** |
| World | 7 | School Desk | Furniture / fixtures | **Unknown** |
| World | 8 | Vending Machine | Furniture / fixtures | **Unknown** |
| World | 9 | Bed | Furniture / fixtures | **Unknown** |
| World | 10 | Car_SUV | Vehicle / mobility asset | **Unknown** |
| World | 11 | Stool | Furniture / fixtures | **Unknown** |
| World | 12 | Picnic Table | Furniture / fixtures | **Unknown** |
| World | 13 | Announce Desk | Furniture / fixtures | **Unknown** |
| World | 14 | Ladder | World props / objects | **Unknown** |
| World | 15 | Folding Chair | Furniture / fixtures | **Unknown** |
| World | 16 | Armchair | Furniture / fixtures | **Unknown** |
| World | 17 | Steps | World props / objects | **Unknown** |
| World | 18 | Snooker Table | Furniture / fixtures | **Unknown** |
| World | 19 | Trashcan | World props / objects | **Unknown** |
| World | 20 | Car_Police | Vehicle / mobility asset | **Unknown** |
| World | 21 | Sofa | Furniture / fixtures | **Unknown** |
| World | 22 | Table | Furniture / fixtures | **Unknown** |
| World | 23 | Toilet | Furniture / fixtures | **Unknown** |
| World | 24 | Car_Sedan | Vehicle / mobility asset | **Unknown** |
| World | 25 | Car_Sports | Vehicle / mobility asset | **Unknown** |
| World | 26 | Computer Desk | Furniture / fixtures | **Unknown** |
| World | 27 | Barrel | World props / objects | **Unknown** |
| World | 28 | Table (Round) | Furniture / fixtures | **Unknown** |
| World | 29 | Piano | Furniture / fixtures | **Unknown** |
| World | 30 | Metal Table | Furniture / fixtures | **Unknown** |
| World | 31 | Bench | Furniture / fixtures | **Unknown** |
| World | 32 | Easel | World props / objects | **Unknown** |
| World | 33 | Wooden Crate | World props / objects | **Unknown** |
| World | 34 | Motorcycle | Vehicle / mobility asset | **Unknown** |
| World | 35 | Office Chair | Furniture / fixtures | **Unknown** |

### 5.3 Additional possible transport/world labels

Other string searches found **\`Bicycle\`** and **\`Train\`** elsewhere, but **outside** this particular audited 35-name world group; their source context, usable prefab ownership and spawn IDs have not been fully decoded. The label **\`Plane\`** is ambiguous (it may refer to a mesh, shader or world element). Keep these in an **unmapped extras** subsection rather than presenting them as validated vehicles. No source asset label is evidence that an actual spawnable, controllable vehicle exists.

## 6. How to discover real numeric IDs — recommended evidence pipeline

**Do not brute-force thousands of IDs or automatically invoke unvalidated calls.** Instead, build an evidence-linked mapping:

1. From the existing embedded menu/backend, inspect a live **weapon/stock-manager collection** after the Game scene is fully initialized. Record each existing stock object's validated \`type\`, \`variant\`, \`location\`, registered index and class.
2. For the same registered object, resolve its actual Unity GameObject/mesh/prefab/sprite or other resource reference (where the engine exposes it) to a **human-readable asset label**. Record **native typeId → exact visible object name → factory → live scene**.
3. Repeat for the **second stock manager**, keeping its IDs in a **separate namespace**; identical numbers can mean different things in different factories.
4. Cross-check \`Stock.type\` with the factory's requested parameter and its runtime validation function. Observe creation, collision, persistence, pickup and disposal; don't call it proven on allocator success alone.
5. Create a build-specific verified mapping with fields such as \`category\`, \`factory\`, \`typeId\`, \`displayName\`, \`sourceEvidence\`, \`verifiedInGame\`, \`interactable\`, \`testBuildHash\`. Only publish to normal user-facing UI when \`verifiedInGame=true\`.
6. For food, medical and tools, use their native object/consumable behavior to classify. The presence of a picture or name in an asset bundle does not prove they use the same stock factory.
7. For vehicles, identify the **separate native creation and drivable physics registration method**. Do not attempt vehicle ID sweeps through stock/weapon/prop APIs.
8. Use the PC \`MappedWeapons.Add(0)\` and \`MappedItems.Add(0)\` only as **investigation hints** for separate manager paths and optional/random semantics. Android signatures and ID meanings must be independently verified against this XAPK.

**Suggested mapping evidence states:** \`asset_name_only\`, \`native_argument_seen\`, \`manager_type_seen\`, \`factory_confirmed\`, \`scene_object_verified\`, \`pickup_usable_verified\`. This prevents false “fully mapped” claims.

## 7. Integrate one Spawn section into the ALREADY WORKING embedded menu

**Do not rebuild the UI host, change the game's signing baseline without need, or replace the known-working command/binding bridge.** Extend the existing menu implementation in that other session:

\`\`\`text
[Existing floating III icon]
  Main menu
    existing Health / Spirit / Attributes / Money / Progress / Setup [preserve]
    NEW  SPAWN ITEMS
       Weapons
          Ranged
          Melee / improvised
       Tools & equipment
       Food & drink
       Medicine & resources
       Personal / sports / miscellaneous props
       Furniture & large objects
       Vehicles (research only until factory proven)
       Recent / verified spawns (optional)
          Selected asset/name and verified ID
          Count: 1 (initially)
          Placement: In front of player
          Distance: adjustable, default tentative 1.75 world units
          [SPAWN]  (enabled only for validated factory+ID+scene)
          Status: created & materialized / rejected with reason
\`\`\`

**State behavior:** The prior UI specification was to reopen at the **same category/editor** and retain unsaved input. The new Spawn section must follow the same rule (remember category, selection, placement, distance and any error/result message when the floating menu closes).

**Unmapped items:** A category list can be browsed and filtered immediately using the asset-label catalog, but \`SPAWN\` should be disabled on labels with unknown type IDs instead of guessing. Optionally have a separately labeled **developer diagnostic** that accepts a *specifically validated factory argument* (e.g. 83) for controlled first tests; do not misrepresent it as a named product.

**Minimal native command contract — architectural proposal, not a present method:**

\`\`\`text
SpawnRequest {
  requestId: stable unique ID
  category: weapon_stock | item_stock | furniture | vehicle
  factory: known validated factory namespace
  typeId: validated integer for that factory
  placement: front_of_player
  distance: finite validated float
  verticalOffset: finite calibrated float
  heading: player_forward
  scale: finite validated float
  quantity: 1 initially
}
SpawnResult {
  requestId
  status: queued | rejected | created | materialized | failed
  reason: error enum / diagnostics
  managerIndex: optional returned stock index
  entityHandle: optional validated scene object
  appliedWorldPosition: optional (x,y,z)
}
\`\`\`

**Bridge workflow:** HTML/native UI button → existing Android/JNI/IL2CPP command path (**inspect actual working method names in current APK**) → validate Game scene, original module hash, player and manager → schedule factory invocation on **Unity/game main thread** with correct ABI and lifecycle → verify registered scene object/collider/visibility → return a typed result to menu. If no main-thread dispatch exists, it must be implemented and proven first; JNI WebView callbacks are **not** automatically on the Unity thread. Avoid direct unverified invocation on the Android UI thread.

**Important UI wording:** Until there is an actual game response, do not use “Spawn succeeded” when only a JS click handler ran. Use “Request queued”, then “Created and observed” only with real verification.

## 8. Staged test plan with hard stop gates

| Stage | Actual work | Pass condition |
|---|---|---|
| **S0 — preserve verified base** | Freeze the user's **latest actually working embedded-menu APK**, signing config, all three splits, save data and current native bindings. Record **new current hashes**, not the earlier CP004 or original XAPK hashes. | Existing current build still launches, and original menu/stat edits still work after backup. |
| **S1 — live player transform** | Add read-only native menu diagnostic for actor X/Y/Z/angle. Test idle, walk forward/back, turn 90°, room transition, respawn. | Coordinates change with movement; angle/direction matches heading, resolver refreshes after scene transition; no crash. |
| **S2 — resolve callable weapon factory** | Verify original module hash, factory RVA, type argument ABI, loaded scene and manager, native main-thread dispatcher. Do not create items yet. | Factory signature/context, correct calling thread, safe failure behavior confirmed. |
| **S3 — first controlled spawn** | In Game scene invoke only the previously observed argument **83**, one entity, safe front-of-player location, no user-claimed item name. | Object visibly appears in front of player, is registered, can be interacted with as appropriate, and game remains stable. |
| **S4 — expand validated IDs** | Test the legitimate **88–91** code-selected values **individually** when validation permits; map visible appearance/behavior to ID. | Verified labels, factory identity, evidence and usability stored per ID; invalid IDs never crash. |
| **S5 — second stock manager** | Resolve item/furniture creation wrapper, positions, type/name mapping and scene/persistence lifecycle. | First actual item/furniture is created and interacts; separate type map confirmed. |
| **S6 — food/tools/props** | Categorize verified objects and add menu browsing, search and spawn confirmation. | At least one usable instance of each implemented category; mapped per original build version. |
| **S7 — vehicles** | Only after finding separate vehicle factory and initialization/physics/driver registration. | Drivable vehicle appears in usable state; no assumptions from World field names. |

**Per-spawn acceptance:** Verify visible object, actual correct model, valid physics/collider, pickup/use or intended interaction, correct floor position and orientation, repeat spawn, scene change, object cleanup/save behavior as appropriate, and no crash/ANR. Record spawned stock handle only if validated. Stop immediately on unexpected type/object/invalid pointers and roll back to known-working build.

## 9. Risks / contradictions that must stay visible

- The user **now reports a fully embedded menu and working GG-derived bindings**; this handoff **does not downgrade** that achievement. However, this research session **did not access the latest working modified APK**, so the bridge ABI/dispatch cannot be asserted.
- An existing healthy GG stat address only grants a **memory read/write**, not a constructor call. Spawning must execute native game factory+registration logic.
- Some factory values may represent **special body-part props** rather than normal inventory weapons.
- **Source ordinal 83 is not factory type ID 83.**
- \`Stock.location=14/18/23/24/46/48/49\` is not a catalog of seven furniture IDs.
- \`Stock.type=1/2\` from initializer is not sufficient for a named food/furniture mapping.
- The actor coordinate copy at initialization is static proof; **live update and heading conventions still need actual gameplay tests**.
- The **RVA is build-specific**; the current modified APK may have different native modules or injected ABI constraints. Compare original and target hashes before use.
- World/vehicle state arrays are not a vehicle spawn constructor. Vehicle support is intentionally gated.
- The XAPK's **asset names are source strings**, not necessarily concrete directly loadable GameObjects; scene materialization must be verified.
- No native function was called and no object spawned in this research session.

## 10. Exact task for the receiving ChatGPT session

> **Continue from the user's present successful in-APK menu and working GG-derived stat bindings. Read this handoff and the linked original XAPK/GG factory research. Add a Spawn Items top-level menu category without changing existing successful controls. First implement a read-only active-actor position/angle test using offsets +0x48/+0x4C/+0x50/+0x78, then validate game-facing player-relative placement and the positioned weapon-stock factory at original build RVA 0x1530160. Perform ONE real native factory invocation using an original Android-observed type argument and verify the object appears and interacts in front of the player. Only then map and enable actual named item/weapon/tool/furniture options. Treat vehicles as a separate unresolved factory. Keep the 113+35 asset-label list as UI research metadata, never as presumed IDs. Return tests, hashes, exact native bridge method names, success/failure logs and first observed ID→object matches.**
  
**Do not** create a second floating menu, reset the embedded APK to CP004, hardcode stale addresses across builds, replace existing working graphics, relabel source-list ordinals as type IDs, fabricate successful spawning, or perform unbounded random native calls.

---

### Provenance and reproducibility

This research used the Library's **original XAPK**, verified its SHA-256, extracted the original ARM64 \`libil2cpp.so\` and IL2CPP v39 metadata, inspected real ARM64 disassembly, decoded field definitions and verified native field offsets, extracted \`resources.assets\` from the UnityFS \`datapack.unity3d\`, and enumerated the 148 above strings. Existing native factory analyses were cross-checked against this source. The external PC mod was used as a comparative **reference only**. The actual live APK and its functioning bridge remain in the other session's workspace.

**Canonical future document path:** \`research/HT3_SPAWN_CATALOG_AND_INTEGRATION_HANDOFF.md\`. Future findings should **update this same Markdown** in GitHub and clearly replace \`Unknown\` IDs only after evidence, instead of producing many conflicting handoff variants.
