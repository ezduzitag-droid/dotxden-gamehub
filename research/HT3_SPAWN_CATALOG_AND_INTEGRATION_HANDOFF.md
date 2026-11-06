# Hard Time III v1.1.8 — Spawn-Item Native Research, Asset Catalog and Embedded-Menu Integration Handoff

**Research date:** 2026-11-06 (America/Los_Angeles)  
**Purpose:** Hand this document to the other ChatGPT session, where the user reports that the **floating menu is already embedded in the APK and existing GG-derived stat/address bindings are working**. The next feature is a real **Spawn Items** section that invokes the game's own stock/entity creation routines, places selected objects directly in front of the active player, and presents distinct weapon/item/tool/furniture/vehicle categories.  
**Research status:** **Original uploaded XAPK directly examined**; native game factory paths and actor position copies statically verified; source asset labels catalogued; **no spawn action performed on the user's currently embedded APK** in this session.  
**IMPORTANT:** Treat the user's successful embedded-menu/binding report as the **latest project state**. Prior CP004/menu-only handoffs are historical. The currently working menu-enabled signed APK and its Android/IL2CPP command bridge were **not supplied here**, so exact bridge names, latest binary hashes, and runtime dispatch capabilities must be inspected in the other session, not invented.

## 0. Deep read-only re-audit — **important catalog clarification** (2026-11-06)

**This section supersedes the earlier assumption that the 148 extracted names are only bare asset-label strings.** They are **named Unity GameObject roots with nested component/transform hierarchies**, determined from the directly decoded Unity 6.0 serialized object table in `datapack.unity3d/resources.assets`. All 148 roots have **Transform + AudioSource on the root**; **138 additionally resolve to one or more descendant MeshFilter → Mesh objects**, frequently through a child GameObject named `Model`. Thus an audio component on the root does **not** imply that the root is sound-only. The remaining 10 names had **no linked MeshFilter mesh in this graph walk**, which does not prove they lack any possible sprite/other visual rendering.

**These are actual original-package object hierarchies**, but **Unity asset PathIDs are not the same as gameplay type IDs**. Serialized resources alone do not prove a working `Resources.Load` path, a scene-spawn API or drivable/pickup behavior. Real native type mappings and engine factories must still be validated.

### 0.1 Directly decoded serialized-file structure

- Source: `split_0.apk/assets/bin/Data/datapack.unity3d` → UnityFS member `resources.assets`, decompressed 72,771,760 bytes.
- Unity SerializedFile **format 22**, Unity version **6000.3.25f1**, platform 13, little endian, metadata size **401,824**, data offset **401,872**, **16,665 serialized objects**, **52 object-type entries**.
- Unity standard ClassIDs confirmed against [Unity 6000.3 class reference](https://docs.unity.com/en-us/engine/6000.3/manual/working-with-scenes/text-scene-format/class-idreference): **1 GameObject**, **4 Transform**, **23 MeshRenderer**, **33 MeshFilter**, **43 Mesh**, **82 AudioSource**.
- The **113 item/handheld roots** are GameObject PathIDs **3754–3866**; each has components of classes **4 and 82** on the root.
- The **35 furniture/world/vehicle roots** are GameObject PathIDs **5180–5214**; each likewise has root components **4 and 82**.
- By parsing each GameObject's component `PPtr` references, its Transform child array, and the descendants' MeshFilter `m_Mesh` references, **138 of 148 named roots** linked to at least one class-43 Mesh, while **10** did not through this route: `Cardboard`, `Picture`, `Wooden Board`, `Cage Piece`, `Glass Pane`, `Magazine`, `Book`, `Belt`, `Folded Chair`, `Light Tube`.
- The same resource includes **1,514 class-43 Mesh objects**. Many mesh names are generic, so child relationships are essential; a filename grep alone misses them.

#### Verified example parent/child/mesh relationships

| Named root GameObject (Unity PathID) | Descendant GameObject / MeshFilter | Mesh asset / PathID | What it proves |
|---|---|---|---|
| `Apple` (**3847**) | `Model` / MeshFilter **13425** | `Geo_Apple` / **2019** | Food-looking root has linked visible geometry |
| `Orange` (**3757**) | `Model` / MeshFilter **13422** | `Geo_Orange` / **1993** | Root → Model → Mesh chain |
| `Burger` (see catalog) | `Model` chain present | `Geo_CheeseBurger` / **2004** | Food mesh present, not numeric item ID |
| `Machine Gun` (**3756**) | `Model` / MeshFilter **13669** | `MachineGun` / **2557** | Weapon-like composite geometry |
| `Taser` (**3766**) | `Model` / MeshFilter **13381** | `Taser` / **2542** | Weapon mesh references exist |
| `Rifle` (see catalog) | `Model` / MeshFilter **14234** | `Rifle` / **2167** | Renderer/model hierarchy exists |
| `Car_Sedan` (**5203**) | Multiple model children | Meshes include `Door_BL`, `Door_BR`, `Door_FL`, `Door_FR`, `Steer`, `Wheel_BL`, `Wheel_BR`, `Wheel_FL` | Multi-part car hierarchy, **not yet a verified drivable spawn** |
| `Car_Sports` (**5204**) | Multiple model children | Separate door, steering and wheel Mesh references | Model available; native vehicle registration still unresolved |
| `Car_Van` (**5180**) | Multiple model children | `Body`, doors, steering and wheels | Nested model structure |
| `Motorcycle` (**5213**) | Multiple model children | `Body`, `Handles`, `RearWheel`, `FrontWheel` | Visual parts available |
| `Bed` (**5188**) | Multiple model children | `Cover`, `Feet`, `Head`, `Mattress`, `Pillow` | Furniture hierarchy available |
| `Desk` (**5183**) | Multiple model children | `Drawer`, `Drawers01`, `Drawers02`, `Top01`, `Top02` | Multi-part furniture hierarchy |

**Careful terminology:** These are source **Unity PathIDs**, not `Stock.type`, not factory type values, and not APK resource IDs. Do **not** create a menu entry like "Spawn Apple (3847)" and assume the game factory accepts `3847`. Instead map each **native factory type ID → runtime spawned object → Unity hierarchy/mesh name**.

### 0.2 New native placement proof: the weapon factory intentionally offsets coordinates

Re-examined ARM64 at `IFCBDBGCKJA.CGLILJCFENK` RVA `0x1530160`:

- Six explicit args observed as `w0=type`, **`s0=x, s1=y, s2=z, s3=angle, s4=scale`**; it invokes allocator RVA `0x1526114` and returns an **integer object index**.
- It initially assigns input `x,y,z` to created object `+0x50,+0x54,+0x58`. The returned stock index must be **at least 1** before this positioning path executes.
- It calls a float random-range-like helper RVA **`0x2D54654`** with bounds **0.5 and 1.0**, then multiplies the result by the passed `scale` and stores it in a placement-distance field `+0xA0`. Another random amount is stored at `+0xA4` for other placement-related behavior.
- At `0x15302C4`, helper RVA **`0x167B110`** computes `cos((angle-90)×0.01745329238)×distance` and adds the result to object X. At `0x15302E0`, helper RVA **`0x167C6B4`** computes `sin((angle+90)×0.01745329238)×distance` and adds the result to object Z.
- Therefore the output placement after the factory runs is equivalent to:

```text
r ≈ Range(0.5, 1.0) * scale  // range helper semantics to be verified in runtime
outX = requestedX + sin(angleDegrees * π / 180) * r
outY = requestedY
outZ = requestedZ + cos(angleDegrees * π / 180) * r
```

**Engineering consequence:** The proposed "spawn 1.75 units in front" code from the earlier document **must not blindly add a 1.75-unit forward offset before calling this factory** without accounting for the factory's *additional* forward distance. For the *first controlled test*, consider passing validated player X/Y/Z and heading directly at scale 1.0; inspect where the result actually appears. If exact placement is required, use a validated **game-owned positioning/transform update operation** after the factory has registered the object; a raw stock-pointer write is not a substitute. Native factory behavior is evidenced; **live actor heading must still be calibrated separately**.

### 0.3 New validation details: do not sweep arbitrary IDs

The weapon-side validator at RVA `0x152604C` uses ARM64 conditional comparisons rather than a trivial `0..max` check:

- It performs a specific exclusion for **type 72** and a paired/small-range exclusion involving **108–122** (ARM64 `cmp`, `and`, `ccmp`, `ccmn`, `cset lo`; these exclusions are inferred from branch-condition evaluation).
- It conditionally excludes **type 28** when the manager static field at **`+0x08` equals 10**.
- It additionally checks a dynamic stock-type upper limit through manager static state at **`+0x0C`**, rejecting zero or values above the initialized limit when called as a strict type validator.
- **An additional allocator-level path treats request type 0 specially** (the caller bypasses the ordinary reject-on-validator-failure check); **do not treat 0 as a named item ID**.
- All this is original-build **static disassembly**, not a live comprehensive whitelist. **Type 83 is not in the statically excluded set**, which agrees with its observed original Android factory callsites. Record real runtime validity per ID, not merely a guessed range.

### 0.4 Second manager and Unity bundle follow-up

- `CAIHMLHBPMF.DOFOCOJJKKF`, token `0x06000608`, RVA **`0x16D2890`**, has **eight explicit parameters** and iterates existing second-manager entries. It calls methods on `GDICAFINBED` objects (e.g. `0x16EFFEC`, `0x16F585C`) after coordinate/state checks; **it does not directly invoke the second manager's creation method `0x16D1B9C` and should NOT be labeled a positioned furniture constructor**. This is a candidate for collision/interaction/selection research, not a validated spawn method.
- The original `assets/world` UnityFS CAB inspected separately contains **718 serialized objects**, including **137 GameObjects** named mainly UI terms such as `Virtual Stick`, `Joystick`, `Health Meter`, `Spirit Meter`, `DPad_Right`, `Button03`. A bundle's name `world` alone does **not** prove vehicle meshes/factories live in it.
- The actual car/weapon/food composite hierarchies above were found in **`datapack.unity3d/resources.assets`**. Separately, `world` may still be used for other resources, but do not conflate the two files.

### 0.5 Updated evidence-based next research tasks

1. On the user's **existing working embedded menu APK**, record actual `libil2cpp.so` hash and existing native bridge/dispatcher path. **Do not revert to an older checkpoint.**
2. Read player live actor X/Y/Z/angle and confirm walking/turning. Use the original ARM64-traced heading basis from section 0.2 as a testable reference.
3. Use the existing Android observed factory arg **83**, pass player coordinates and angle to the factory once with safe checks, account for its built-in forward displacement, then verify returned index, actual rendered hierarchy and interaction.
4. Match that spawned entity's `Stock.type` and Unity GameObject/mesh references to the **148 composite root names** and the **1,514 mesh-name index**, before naming any type ID.
5. For the second manager, trace the **factory-to-visual hierarchy connection** and a native positioned wrapper instead of interpreting `DOFOCOJJKKF` as a spawn API.
6. Keep vehicles on a **separate verified factory/physics gate**; the existence of wheel and door meshes is not proof of a complete registered drivable entity.

**Static verification performed:** SerializedFile v22 header and 16,665-object table parsed; 148 root-to-Transform-to-AudioSource references checked; recursively followed child Transforms and MeshFilter-to-Mesh pointers; verified 138 linked mesh hierarchies; decoded ARM64 float arguments, degree constants and trig helper callsites; compared Unity ClassIDs with official Unity documentation. No game process was run and no objects were spawned in this research session.

---

## 0C. Additional read-only game-system audit — NPCs, animals, rooms, and new menu capabilities (2026-11-06)

**This section records NEW research outside the item/weapon/furniture investigation and supersedes the older statement that an NPC creation call was unlocated.** The original 1.1.8 XAPK was re-verified with SHA-256 `07b0393458a8e11f570c421342113937ed35ea362304adee08b754669d7ddc03`. Research remained **entirely read-only**; the current user-confirmed working embedded APK/menu was not supplied, rebuilt, installed, or modified. The latest modified build's hashes and bridge API must come from the other ChatGPT session.

### 0C.1 The NPC actor factory and the most promising positioned-NPC wrapper

The actual game-assembly method map contains **2,004 methods** (IL2CPP metadata v39). New tracing identified a complete path from **requested Character ID → active-actor manager allocation → initialized EFPJKAPKGOB actor → environmental placement**:

| Owner.method | Metadata token | Original ARM64 RVA | What static code demonstrates |
|---|---|---|---|
| `LOCECKLDEDA.PGFGFJPFCIP` | `0x06000512` (method index 1297) | **`0x16842F8`** | **Four explicit arguments**: one integer in `w0`, three floats in `s0/s1/s2`. Selects an eligible Character (if no ID), checks for existing active actor, calls actor allocator, then positions returned actor with those three floats. **Strong candidate for Spawn NPC by ID at location**. |
| `LOCECKLDEDA.HBALMHCPLKM` | `0x0600050E` (1293) | **`0x167F29C`** | Two explicit integers. Calls selector `LEHNPLAAMMJ`, expands actor array/counter, constructs an `EFPJKAPKGOB` object and invokes its initializer. Returns the active actor index. |
| `LOCECKLDEDA.LEHNPLAAMMJ` | `0x0600050B` (1290) | `0x16835A4` | Three-argument actor-slot/selector routine. Handles existing/free slots and constructs actor instances in a fallback path. |
| `LOCECKLDEDA.AAJNJENIJBA` | `0x06000505` (1284) | **`0x167F5E4`** | One requested Character ID; scans manager slots, checks activity marker and actor Character ID, returns matching **actor index or zero**. **Read-only per-NPC lookup primitive**. |
| `EFPJKAPKGOB.GKPAOEAELIH` | game method index 942? **Verify against method map** | **`0x162962C`** | Three explicit arguments; actual actor initializer; establishes link to the stored Character record, health/state initialization, transforms, equipment/animation context and game-world setup. |
| `EFPJKAPKGOB.JLJDCKEMCCD` | `0x0600039D` (924) | **`0x15A32C0`** | **Three float arguments**. Assigns actor position, calls world-surface checks/height correction and handles placement fallback. It is more than raw x/y/z writes. |
| `LOCECKLDEDA.HNABEHOCBNL` | `0x06000501` (1280) | `0x167D6B4` | Scene/room population initializer; contains **three** direct calls to the actor allocator among roster/cast selection and other initialization logic. |
| `Scene_Game.Start` | `0x0600055F` | `0x16C479C` | Actually calls manager initialization, `LOCECKLDEDA.HNABEHOCBNL` and other game-stock managers during Game scene startup. |
| `Scene_Game.Update` | `0x06000560` | `0x16C5FAC` | Calls active-actor manager update methods, world update and separate weapon/furniture/animal-like manager updates. |

**Critical correction:** In the row for `EFPJKAPKGOB.GKPAOEAELIH`, the exact **metadata method index/token is available in the included 2,004-method map** and should be read from that table; do not copy a guessed index from this summary. The original RVA `0x162962C` and the direct native call from `0x167F5C8` are what matter for this analysis.

#### Direct native call chain and runtime consequences

- In `LOCECKLDEDA.PGFGFJPFCIP`, the first integer argument is treated as a **Character identifier / selection input**. When it is **zero**, the function selects a random candidate from `Characters.no_chars`, checks character/scene conditions, avoids active duplicates, and retries within a bounded loop. This is **random-eligible NPC selection**, not "NPC ID 0".
- When it chooses a candidate, `0x168450C` invokes `LOCECKLDEDA.HBALMHCPLKM` with the selected ID and secondary argument zero.
- If allocation returns a valid slot, `0x1684564` invokes `EFPJKAPKGOB.JLJDCKEMCCD` on the returned actor with the originally supplied `s0/s1/s2` position.
- `PGFGFJPFCIP` is called from **four** direct game-assembly callsites: `Character.HNCHDIIGBHO` at `0x1451BA8`, `EFPJKAPKGOB.PCOCOOEIOCP` at `0x153A044`, and `LPBGBCKENEM.GFFNGIBJOKL` at `0x1769E64` and `0x176A1A4`. These are **existing gameplay paths**, not fabricated entrypoints.
- Placement method `JLJDCKEMCCD` stores coordinate arguments in **active actor +0x48 / +0x4C / +0x50**, but may adjust vertical placement using World methods, test geometry, and choose an alternate valid position. **Passing (0,0,0) can enter random/fallback placement logic**. Do not interpret zero triple as a guaranteed world origin or insist that the final Y equals requested Y.
- The call chain initializes actor state through game functions; direct modification of array length or raw actor pointers does **not** perform these steps.

**Expected bridge plan:** On Unity's correct main execution context, request `SpawnNpc(characterId, requestedX, requestedY, requestedZ)`, validate the Game scene and initialized manager, invoke this **original-build-verified wrapper with its actual generated ABI and hidden runtime metadata arguments**, then resolve returned actor index and verify a newly visible NPC. This is a plan, **not** a working bridge delivered by this research.

**Per-character duplication caution:** `PGFGFJPFCIP` consults existing actor lookup, so requesting the same roster character repeatedly is **not** a safe way to create clones. A room-population slider must choose **distinct eligible IDs** and respect the game's occupancy/roster capacity. Character cloning requires separately verified lifecycle logic.

### 0C.2 Verified current-room NPC lookup and count logic

The original `LOCECKLDEDA` class is the active-actor manager (metadata type-definition index **87**). Its static field-offset table reveals:

| Manager field | Static offset in initialized class | Meaning established by native usage |
|---|---:|---|
| `GDKONMBMION` | **`+0x00`** | **Highest registered active-actor slot/count**, read and incremented by allocator. Not proof that all slots are currently active, visible, or NPCs. |
| `BLNLGHHFPOE` | **`+0x20`** | IL2CPP array reference of actor objects, indexed from **1** in the traced lookup. Validate allocated length at array `+0x18`; element pointers at array `+0x20 + index*8`. |
| Other static fields | `+0x04`, `+0x08`, `+0x0C`, `+0x10`, `+0x14`, `+0x18`, `+0x28`, `+0x30` | Other manager flags/counts/arrays. **Do not label or edit without functional cross-references.** |

**Disassembly of `AAJNJENIJBA` at `0x167F5E4`:** loops actor slots 1..manager count; rejects missing entries and records with **float `actor+0x38 < 0`**, then compares **int `actor+0x18`** against requested Character ID. Returns the matching slot index (or 0). The field at `+0x38` behaves as an **activity marker** in this path; it must **not** be presumed NPC health.

**Recommended display calculation:** `Room NPCs = valid active actor slots meeting all filters` — unique `actor+0x20` linked Character record, non-player Character, live activity marker, optional validated current World location, correct Game scene. Do **not** display raw manager slot count as "NPCs in room." The global Character-roster count `Characters.no_chars` is not a room count either. Do not set either integer to spawn/despawn actors.

**Suggested individual-NPC identity fields** from named IL2CPP `Character` class (type index 7), validated field-offset map:

| Field | Character-relative offset | Intended read-only menu usage |
|---|---:|---|
| `id` | **`+0x10`** | Stable roster identifier, subject to scene/save validation |
| `name` | **`+0x18`** | Managed IL2CPP string for UI row |
| `role` | **`+0x24`** | Prisoner/officer/civilian label after role-value mapping |
| `team` | **`+0x2C`** | Faction/group field; do not guess semantics |
| `prop` | `+0x38` | Stored accessory/prop field; meaning needs runtime confirmation |
| `stat` | **`+0x70`** | Validated six-stat array mapping |
| `health`, `healthLimit` | **`+0x80`, `+0x84`** | Stored/saved health reference; not necessarily effective live state |
| `spirit`, `injury` | `+0x88`, `+0x8C` | Stored state; spirit is scaled in actor initialization |
| `relation` | **`+0xA0`** | Relationship array reference; **index/value semantics unverified** |
| `location` | **`+0xEC`** | Stored room/location index, useful with `World.location` after validation |
| `x, y, z, angle` | **`+0xF0, +0xF4, +0xF8, +0xFC`** | Stored position; live actor preferred during gameplay |
| `dead`, `absent` | `+0x94`, `+0x98` | Eligibility/status checks; do not toggle blindly |

**Per-NPC live actor** `EFPJKAPKGOB` (type index 49):
- `actor+0x20` → linked `Character` object.
- `actor+0x18` → Character ID used by active lookup.
- `actor+0x38` → activity/available-slot marker (lookup treats negative as inactive).
- `actor+0x48/+0x4C/+0x50` → live X/Y/Z, `actor+0x78` → angle (from prior original-build investigation).
- `actor+0xB4` → **live health float**, `actor+0xB8` → live health limit float, `actor+0xD0` → **live spirit float**, `actor+0x248` → **live injury Int32**.
- Validate both `actor+0x18 == selected Character.id` and `actor+0x20 == expected Character pointer` before editing any NPC. Unique actor identity is essential during room changes or mass announcements/animations.

**NPC health editing:** The existing embedded menu reportedly already edits player's live health. Reuse its verified mechanism but **parameterize the actor target** instead of changing `Characters.cStar`. An individual NPC's live actor health may be updated with the same typed rules **only after the selected NPC is uniquely resolved**. Saved `Character.health` and active `actor.health` can diverge; freezing needs resilient reacquisition and should stop/retry safely if the actor disappears or ambiguity arises. The live edit must not silently retarget an NPC with a recycled array slot.

### 0C.3 A third entity creation manager: animal candidate, distinct from weapons, furniture and NPCs

The Game scene initialization and update call **three distinct stock/entity managers plus the actor manager**:

| Manager | Representative native method | Concrete evidence | Category evidence |
|---|---|---|---|
| `IFCBDBGCKJA` | `CGLILJCFENK` **`0x1530160`** | Positioned weapon-stock factory, native argument 83 / random 88..91 | Weapon/handheld stock: **high-confidence** |
| `CAIHMLHBPMF` | `HBALMHCPLKM` **`0x16D1B9C`** | Distinct Stock records and own array/allocator | Furniture/item/world-stock: **probable, not fully mapped** |
| **`LNHJHMBGCIC`** | **`HBALMHCPLKM` `0x18531E4`** | Distinct manager with own count/array, type validator, allocation, constructor and per-frame updates | **Likely animal manager**, not runtime-confirmed |
| `LOCECKLDEDA` | `HBALMHCPLKM` **`0x167F29C`** | Allocates **`EFPJKAPKGOB`** actors | NPC/active-character manager: **confirmed static chain** |

**New proof for third manager:**
- `Scene_Game.Start` invokes `LNHJHMBGCIC.JNJJAAMPECO` and `LNHJHMBGCIC.HNABEHOCBNL`; `Scene_Game.Update` invokes `LNHJHMBGCIC.OMCPFEIKAEE`.
- `LNHJHMBGCIC.HBALMHCPLKM(int,int)` at **`0x18531E4`** validates requested type, grows the manager array/count and creates **`IEJILMLDJKF`** managed objects, calling constructor at **`0x16EE5E8`** and initializer `IEJILMLDJKF.GKPAOEAELIH` at **`0x16EB4DC`** with actor index and requested arguments.
- `LNHJHMBGCIC.MGABOLMHDLK` at **`0x1853968`** constructs Stock records and interacts with the other stock managers, indicating a saved-entity system.
- `SaveData` has three separately named saved collections: **`stockAnimals+0x1A0`**, **`stockFurniture+0x1A8`**, and **`stockWeapons+0x1B0`** (instance-relative offsets), supporting the three-manager interpretation.
- The resource bundle contains real animated **`Wolf`** and **`Horse`** object hierarchies, but these **do not by themselves prove numeric animal type IDs or which manager uses each model**.

**Menu implication:** Add an **Animals (research)** category as a future candidate, with available Wolf/Horse model evidence displayed as **assets, not verified spawn IDs**. Do not call `LNHJHMBGCIC.HBALMHCPLKM` with guessed animal types or combine these IDs with weapon/furniture namespaces. The first step is confirming `IEJILMLDJKF` runtime objects against the actual Wolf/Horse model and a safe placed-animal wrapper.

### 0C.4 Untouched Unity model families: Humans, Wolves, Horses, Crowds, vehicles

The original `datapack.unity3d/resources.assets` SerializedFile table (16,665 objects) was decoded and the named GameObject hierarchy traversed through Transforms and component references. The **Unity PathIDs below are NOT game character IDs or spawn type IDs.**

| Source GameObject | Unity PathID | Descendant Transform count | Verified component structure | Spawn-system implication |
|---|---:|---:|---|---|
| **`Human_Prefab`** | **4887** | **43** | Transform, MeshFilter, MeshRenderer, 17 SkinnedMeshRenderers, MonoBehaviour, Animator, AudioSource | General rigged human model; **not** a person-specific NPC ID. NPC appearance likely depends on `Character` data/costumes and actor setup. |
| **`Wolf`** | **5836** | **55** | Animated bone tree, SkinnedMeshRenderer, Animator, AudioSource and force/shadow component | Animal-looking model exists; must map native animal type and movement/AI path. |
| **`Horse`** | **3123** | **55** | Multiple SkinnedMeshRenderers, Animator, AudioSource and force/shadow component | Animal-looking model exists; no numeric type mapping yet. |
| **`Crowd`** | **3194** | **28** | Animator with 27 descendant MeshFilter/MeshRenderer crowd parts | **Background crowd geometry, not 27 active NPC actor objects.** |
| **`Car_Sedan`** | **5203** | **13** | Body/doors/steering/wheels; MeshRenderers, Animator and effect components | Vehicle visual hierarchy exists; still **not a validated drivable vehicle factory**. |

**Important distinction for NPC counts:** A single `Human_Prefab` is reusable character geometry. A `Crowd` with 27 visual subobjects is a static/background display. **Only validated active `EFPJKAPKGOB` objects registered through the actor manager** should count as gameplay NPCs.

### 0C.5 Other discoverable menu categories from previously unexamined named metadata

These fields are present in the original source. **They are candidates for read-only inspection; direct changes may not refresh game systems or may be overwritten.** Implement controls only after finding the game's own update/setter path.

| Menu category / proposed feature | Static evidence | Recommended gate |
|---|---|---|
| **NPCs in room: count and choose individual** | Actor manager array +0x20, count/high-water +0x00, per-actor ID+0x18 and linked Character+0x20 | **First priority**, read-only roster + active/dead filtering. |
| **Spawn NPC / spawn random eligible NPC / teleport NPC** | `PGFGFJPFCIP` `0x16842F8`; actor position method `JLJDCKEMCCD` `0x15A32C0` | Native calling convention, main-thread dispatch, valid scene/character/coordinates; observe real actor. |
| **NPC live health, spirit, injury, attributes** | Active `EFPJKAPKGOB` mirrors and `Character.stat+0x70` | Port existing proven player editor to validated selected target; don't write stored-only health. |
| **NPC roles, teams, relationships** | `Character.role+0x24`, `team+0x2C`, `relation+0xA0` | List read-only first; resolve role/team enum and relationship indexing before edits. |
| **NPC equipment / physical status** | `Character.prop+0x38`, `cuffed+0x140`, `chained+0x144`, `seat+0x104` | Verify native gameplay methods; these saved fields may not effect live actors. |
| **Animal list and spawning** | Third manager `LNHJHMBGCIC`, `IEJILMLDJKF` objects, `SaveData.stockAnimals`, Wolf/Horse models | **Research-only** until type-ID/map and positioned wrapper confirmed. |
| **Item/weapon/furniture inspector** | `Stock.id+0x10`, `type+0x14`, `variant+0x18`, `location+0x2C`, `holder+0x54`, `wear+0x58`, `owner+0x5C`, `health+0x68`, `content+0x6C`, `fireTim+0x70` | Per-object read-only listing; optional durability/owner editor only via validated game logic. |
| **Room/world environment** | `World.location+0x10`, `weather+0x78`, `waterLevel+0x80`, `floodLevel+0x88`, `floodTarget+0x8C`, `lightSetting+0xF8`, `fog+0x194` | Read status first; changes may require world reinitialization, physics/weather methods, or scene load. |
| **Crowd / arena visuals** | `World.crowdSize+0x1B0`, `ringShape+0x1C8`, `arenaCage+0x2E0` | Distinguish background crowd from live NPCs; treat structural edits as risky. |
| **Time and schedules** | `Progress.clockSpeed+0x00`, `wakeTime+0x60`, `lunchTime+0x64`, `lockTime+0x68`; existing clock fields | Read-only inspector first; current working time controls may already expose these. |
| **Game population/options** | `SaveData.optPopulation+0xE0`, `optAnimals+0xE4`, `optHealthDrain+0xF8`, `optGore+0x104`, `optFrameRate+0x13C` | **SaveData instance settings**, not instant "spawn N" controls. Discover live option controller and application timing. |
| **Missions / active tasks** | `Progress.mission+0x100`, `missionClient+0x104`, `missionTarget+0x108`, `missionVariable+0x10C`, `missionDeadline+0x110` | Show read-only mission details, avoid editing flags without world-state invariants. |
| **Pre-match cast selector** | `Scene_Match_Setup.AddRandom` `0x168CB9C`, `RemoveCast` `0x168DA34` | **Only match/setup scene.** These methods are NOT equivalent to spawning an NPC in live Game scene. |

### 0C.6 Correct "NPC count = X" UI behavior

**Do not** set `LOCECKLDEDA.static+0x00` or `Characters.no_chars` to a target number. Both are internal bookkeeping; increasing them may make the game read uninitialized/null actor pointers and crash. The user can have an **editable target count** that the bridge meets *through valid creation/destruction APIs*:

```text
CURRENT ROOM  (display live verified actor rows)
  NPCs: 5 active | actor slots/high-water: 9 | roster: 320 [illustrative ONLY]
  Select NPC
    #id / name / role / health / spirit / x-y-z / freeze status
    Health & Spirit  [enabled only for unique live actor]
    Stats, role, relation, inventory [initially read-only]
    Teleport next to me [only after verified reposition API]
  Spawn NPC
    Choose roster character ID or random eligible
    Spawn one, in front of current player
    Spawn until target count (future, small bounded queue)
  NPC errors/logs (validation/scene/actor ambiguity)
```

Numbers in this diagram are **illustrative**. At runtime enumerate live manager entries with class/array bounds checks, exclude player, inactive/dead/unusable slots, and compare the linked Character's location with `World.location` only when room semantics are validated. After each confirmed spawn, **re-enumerate**; do not increment the UI count optimistically. Decreasing count requires a **verified game despawn/retire method**, not a negative pointer or raw array edit. If no safe despawn method is established, offer spawn-one with maximum limits and mark count reduction unavailable.

### 0C.7 Safe test sequence for the receiving embedded-APK session

1. **Protect present success:** Back up the **latest working embedded-menu APK**, signed 3-split build and saves. Inspect the *current* Android→Unity/IL2CPP bridge and hashes; **do not revert to CP004**.
2. **Read-only enumerate:** Read `LOCECKLDEDA` static actor array and count; validate IL2CPP array length, each actor pointer/type, `actor+0x38` active marker, `actor+0x18` Character ID, `actor+0x20` linked Character and names/role/health. Record UI row mapping, active count, roster count, World location.
3. **Identity gate:** Test with one NPC moving, fighting, room change and an animation/announcement. Selection by **Character ID plus object validation**, not stale array slot. Reset stale actor pointers and preserve selected-ID UI state.
4. **One existing NPC editor:** Reuse current working live health read/write/freeze only for a uniquely selected NPC. Compare on-screen effect and stored-vs-live state, no crash, no accidental writes to player.
5. **NPC positioning gate:** Validate that `JLJDCKEMCCD` accepts three finite world floats and routes collision/ground height safely. All-zero input is a special fallback; never use blindly.
6. **First real NPC spawn:** Call `PGFGFJPFCIP` once in the Game scene with an eligible specific Character ID, player-relative safe coordinates, correct native ABI/thread, and verify actor count/ID/visual/health/interaction. Check duplicate-ID and scene-change behavior.
7. **Count target after proof:** Queue one create at a time with strict caps and rollback; don't treat manager high-water count as live NPC count. Deletion needs its own validated lifecycle.
8. **Animal/item follow-up:** Investigate separate manager type namespaces, category-specific factories, and model matching; only then enable animal/furniture/weapon/menu choices.
9. **Optional safe add-ons:** Implement read-only World/Progress/Stock/mission inspectors first. Do not combine high-risk world editing with the first NPC spawn test.
10. **Record evidence:** Original and modified module hashes, method/bridge signatures, current Game scene, character ID, requested/actual location, returned actor index, recognized name/model, logs, and observed gameplay behavior.

**What remains unverified:** The precise live APK bridge signature, NPC spawn UI integration, actual NPC spawn outcome, game-room filtering semantics, NPC despawn implementation, numeric animal IDs, any vehicle spawn API, item category ID mappings, and real-time effects of World/SaveData option edits. The static native findings are substantial but do not justify claiming successful runtime features.

**Reproducibility artifact:** The separate file **HT3_NPC_And_Game_Systems_ReadOnly_Evidence_2026-11-06.zip** contains the original-build 2,004 game-method map, 873 selected field records, 22 target native method entries, call graphs/disassembly and model-hierarchy notes. It was created without writing to any APK or device.

---

## 1. Primary resources and version-sensitive boundaries

| Source | Role |
|---|---|
| **Original user-uploaded XAPK** — `Hard Time III_1.1.8(1).xapk` | Directly re-examined; SHA-256 `07b0393458a8e11f570c421342113937ed35ea362304adee08b754669d7ddc03`, 294,671,941 bytes. Multiple Library copies appear to match this original. |
| **Original IL2CPP metadata** — `base.apk/assets/bin/Data/Managed/Metadata/global-metadata.dat` | 7,306,836 bytes; metadata format 39. |
| **Original ARM64 native module** — `split_1.apk/lib/arm64-v8a/libil2cpp.so` | 54,278,448 bytes; SHA-256 `fb06deda27c22077fb6963a4df3b57de977c4ea5c291aee03e8675d61940549d`. |
| **Serialized asset source** — `split_0.apk/assets/bin/Data/datapack.unity3d` | UnityFS archive; nested `resources.assets` contains two verified contiguous source-label groups used in the catalog below. These are strings, not numeric IDs. |
| [Current GG Lua source](https://github.com/ezduzitag-droid/dotxden-gamehub/blob/main/data/node_6f2e9a.lua) | v2.1.1 stat/actor-pointer research reference; **not itself a spawn implementation**. |
| [Previous native spawn audit](https://github.com/ezduzitag-droid/dotxden-gamehub/blob/main/research/HT3_Spawn_API_Audit_2026-11-04.md) | Previously resolved factory/second allocator and limitations; independently checked against source binary in this research. |
| [Embedded-menu visual source](https://github.com/ezduzitag-droid/dotxden-gamehub/blob/main/data/ht3-control-studio.html) | Earlier standalone HTML. **May lag the user's now-functional embedded APK/menu:** inspect the working embedded copy before editing UI. |
| [PC mod cross-reference](https://github.com/IngoHHacks/HardTimeKeybindCheats/blob/main/Plugin.cs) | External *PC* source showing `MappedWeapons.Add(0)`, `MappedItems.Add(0)`, `MappedWeapons.Produce(83,...)`. Helpful corroboration, **not** a validated Android ID map/ABI. |

**ELF RVA caution:** The addresses below are **native virtual addresses/RVAs in the original ARM64 build**, not absolute process addresses, ZIP offsets, or guaranteed offsets in a later modified build. Check the exact target `libil2cpp.so` hash and loaded mapping. When the ELF has separately mapped segments, compute the mapping base correctly; do not add an RVA to an arbitrary `/proc/maps` line without checking its file offset.

## 2. Executive findings

1. **Actual positioned creation function identified:** `IFCBDBGCKJA.CGLILJCFENK` at RVA **`0x1530160`** takes six explicit parameters consistent with **`(type, x, y, z, angle, scale)`**. It invokes an allocator/registrar, then positions the returned object. The original game's ARM64 callsites actually use this function; it is **not** merely an unused metadata name.
2. **Native Android type-argument evidence:** constant **83** and an RNG-selected value between **88 and 91** are passed to the positioned weapon/stock factory. **Object identities are unknown**. Do **not** equate 83 with catalog row 83 or invent names such as Knife/Slingshot for these numbers.
3. **A distinct second stock manager exists:** `CAIHMLHBPMF` with allocation method RVA **`0x16D1B9C`**. It may correspond to furniture/item placement, but its exact object category, named IDs, positioned creation path and scene materialization still require resolution.
4. **Important disambiguation:** the second manager's initializer was observed with `Stock.type` **1 or 2** and **location codes 14, 18, 23, 24, 46, 48, 49**. Those location numbers are **not object IDs**; `1`/`2` should not be named chairs/food without further evidence.
5. **Coordinate and facing fields located in this source XAPK**: the active actor's world position maps to offsets **+0x48 (X), +0x4C (Y), +0x50 (Z), +0x78 (angle)**; stored Character coordinates and angle are **+0xF0, +0xF4, +0xF8, +0xFC**. The ARM64 initializer copies these values; inspect the live actor after movement before trusting its angle as forward direction.
6. **Composite Unity asset catalog decoded:** **113 item-like GameObject roots** and **35 furniture/vehicle/world roots**, each with Transform+AudioSource, of which **138/148 link to descendant MeshFilter/Mesh objects** (see deep re-audit section 0). All Unity PathIDs and source ordinals are **NOT numeric gameplay spawn IDs**. Native factory mapping is still required.
7. **Vehicles remain separate:** car/motorcycle **asset names exist**, but no safe drivable vehicle-spawning method or numeric vehicle-ID mapping has been established. Do not send vehicle labels into the weapon-stock factory.
8. **New menu feature must call an actual native game factory** on the correct game/Unity execution context; writing numeric memory values or appending uninitialized pointers to Stock arrays cannot spawn a fully registered scene entity.

### 2.1 Confirmed numeric/code evidence (NOT a complete ID catalog)

| Value / RVA | Domain | What the code actually supports | Evidence quality |
|---|---|---|---|
| `83` | `IFCBDBGCKJA` positioned factory argument | Existing original Android callsites pass 83 as requested type | **Verified in static ARM64 code**; display name and runtime spawning **not tested** |
| `88..91` | Same positioned factory | Existing Android callsite requests an RNG value using bounds 88 and 91; meaning depends on RNG semantics | **Verified range-bound inputs**; four individual observed runtime IDs **not yet established** |
| `0` | `MappedWeapons.Add` / `MappedItems.Add` in PC mod | Random/default creation request in external **PC** implementation | **PC-only reference**; NOT universal Android `type_id=0` |
| `1,2` | `Stock.type` values in second-manager initializer | Values copied into stock record by initialization routines | **Verified typed fields**, but not a named catalog |
| `14,18,23,24,46,48,49` | `Stock.location` | Scene/location identifiers in second manager initialization | **Verified locations**, explicitly **NOT item/vehicle IDs** |
| `0x1530160` | `IFCBDBGCKJA.CGLILJCFENK` | Positioned stock/weapon factory | **Static execution/calls verified**, invocation from embedded UI pending |
| `0x1526114` | `IFCBDBGCKJA.HBALMHCPLKM` | Weapon-side object allocation/registration | **Static call trace verified** |
| `0x152604C` | `IFCBDBGCKJA.AKKIOODJGNM` | Type validator | **Static call trace verified**; no universal contiguous valid-type range |
| `0x16D1B9C` | `CAIHMLHBPMF.HBALMHCPLKM` | Separate managed stock allocation/registration | **Static execution trace verified**; identity and placement pending |
| `0x165957C` | `Stock.JFEMFOPPBIL` | Populates `Stock.type` and `Stock.location` | **Static field writes verified**; not an independent safe Unity-spawn call |
| `0x16A92FC` | `World.LAPKJLMHCGE` | Indexed world-state updater | **Not a verified vehicle constructor** |

## 3. Player coordinates: newly recovered exact mappings

### 3.1 Field table and layout, directly decoded from the user's XAPK

The IL2CPP metadata field definitions were decoded and cross-checked against the native field-offset table, with known GG fields (live health/spirit/injury and Character stat) as sanity checks. The source ELF has a field-offset table at **ELF file offset `0x76E988`**, which is not a universal cross-build location.

| Data owner | Field | Relative offset | Representation / interpretation |
|---|---|---|---|
| `Character` stored record | `x` | `+0xF0` | Float32 |
| `Character` | `y` | `+0xF4` | Float32 |
| `Character` | `z` | `+0xF8` | Float32 |
| `Character` | `angle` | `+0xFC` | Float32 |
| `Character` | `location` | `+0xEC` | Int32 scene/location reference |
| **`EFPJKAPKGOB` active actor** | **X** (obfuscated `HIDLCGMCHJD`) | **`+0x48`** | **Float32** |
| **Active actor** | **Y** (`CECPJOCEGKC`) | **`+0x4C`** | **Float32** |
| **Active actor** | **Z** (`BLKHODNLCED`) | **`+0x50`** | **Float32** |
| **Active actor** | **angle** (`KJPHAPAFKEO`) | **`+0x78`** | **Float32** |

**Additional ARM64 proof** — actor initialization at **`0x162B02C–0x162B05C`** follows active actor `+0x20` to the stored Character, loads two floats from `Character+0xF0` into actor `+0x48/+0x4C`, loads another two from `Character+0xF8`, writes Z to actor `+0x50` and angle to actor `+0x78`. These are actual ARM64 load/store instructions, not inferred only from similar-looking field order.

**Critical runtime caveat:** These registers show how the actor is **initialized**. They do **not** independently prove that actor X/Y/Z/angle are updated continuously during gameplay, or establish angle units/sign convention. Verify live coordinates while walking and turning on the target game before using them for production spawning.

### 3.2 Locate the correct player — reuse the existing working binding

The existing GG resolver already knows the safe identity chain:

`Characters.cStar` (active Character record) → `LOCECKLDEDA` active-actor manager array → **unique** `EFPJKAPKGOB` actor whose Character reference at `actor+0x20` equals `Characters.cStar`.

For the spawning bridge, **reuse the validated active actor resolver** from the functioning embedded menu if it already exposes this actor and checks scene/class identity. Do not choose actor index 0 or the nearest NPC on a guess. Cache an actor only for the current stable scene; **re-resolve after room changes/death/respawns**. Refuse to spawn if there is no unique valid player actor, a stale library mapping, nonfinite position, or the game is outside the Game scene.

### 3.3 Spawn directly in front of the character

**Preferred method:** obtain the real Unity actor object's **`Transform.position`** and normalized **`Transform.forward`** from a validated native/Unity bridge. Resolve ground/collider placement using engine collision/navigation logic when available.

**Fallback, only after live-calibrating angle conventions:** if the native bridge has validated `actor.x/y/z/angle` and the game angle is proven to use **degrees**, one candidate forward vector for Unity's X/Z plane is:

```text
theta = actorAngleDegrees * pi / 180
forwardX = sin(theta)
forwardZ = cos(theta)
targetX = actorX + distance * forwardX
targetY = actorY + calibratedHeightOffset
targetZ = actorZ + distance * forwardZ
```

This **is a hypothesis, not a verified orientation formula**. The game may use a different handedness, axis, offset or radians. Compare actor movement with actual heading at **0°, 90°, 180°, 270°**; if the computed forward points sideways/behind, correct sign/axes rather than hardcoding wrong formulas. Match the game's actual `Produce(type,x,y,z,angle,scale)` coordinate system.

**Conservative default for first spawn:** distance **1.5–2.0 game-world units** (tentative), scale **1.0** (tentative), **quantity 1**, no velocity, only after checking a safe clear spot. Ground heights and collision footprints differ for an apple versus an office desk or a car. Use a ground raycast / surface placement and item bounds where possible, prevent inside-wall or below-floor spawns, and never put vehicles through a weapon/prop factory.

### 3.4 Stock record coordinates — NOT sufficient by themselves

The managed `Stock` record contains the following **verified** fields: `id+0x10`, `type+0x14`, `variant+0x18`, `scale+0x28`, `location+0x2C`, `x+0x30`, `y+0x34`, `z+0x38`, `angle+0x3C`, `origin+0x40`, `originX+0x44`, `originY+0x48`, `originZ+0x4C`, `originAngle+0x50`. These fields help trace persistence and location bookkeeping. **Writing them into a random object or adding a raw pointer to a list does not execute factory initialization, scene registration, Unity rendering or collision creation.**

## 4. Actual native creation paths and unresolved categories

### 4.1 Weapon/handheld-stock factory — best first test

- Owner: `IFCBDBGCKJA` (metadata type index 24).
- Positioned function: `CGLILJCFENK`, metadata method index **273**, token **`0x06000112`**, native **`0x1530160`**, **6 explicit arguments**.
- From ARM64 argument flow and PC reference, signature is **consistent with** `Produce(type,x,y,z,angle,scale)`. Confirm the correct return type, internal convention, hidden `MethodInfo*` argument and any required runtime context before invoking.
- Positioned function calls `HBALMHCPLKM` at **`0x1526114`** to validate/allocate/register a stock object, obtains its registered index, then updates the created object’s position at **`+0x50/+0x54/+0x58`**, angle/rotation at **`+0x6C/+0x98`**, and scaling-related data at **`+0xA0/+0xA4`**.
- Native caller examples: `EFPJKAPKGOB.CKHFEGNHFJP` at **`0x15A97A8`** and **`0x15A9858`**; `GDICAFINBED.IBILCPMOIKN` has calls in the **`0x16F4F8C–0x16F5258`** range.
- The game's own code passes type **83** and values selected with bounds **88–91**, associated with limb/dismemberment effects. They may be special-purpose stock models. Start with a **single controlled, developer-approved test**, not a bulk scan of guessed integer IDs.

**First API test gate:** In actual gameplay, use the already embedded menu/native bridge to schedule **one** validated factory invocation on the game/Unity main thread; return a success result only after a manager index is valid **and a visible, interactable scene object exists**. A nonzero return, stock array length change, or memory readback alone is **not** sufficient.

### 4.2 Second stock / item / furniture manager — separate research gate

- `CAIHMLHBPMF.HBALMHCPLKM(int,int)`, token **`0x06000600`**, native **`0x16D1B9C`**.
- Calls `CAIHMLHBPMF.LEHNPLAAMMJ` at **`0x16D1ED8`**, allocates managed stock and registers it in a second manager's array/counter.
- Callers show **(0, loopIndex)** and **(managerStaticType, 0)** patterns. **Do not** interpret either zero as a universal spawn type.
- `CAIHMLHBPMF.MGABOLMHDLK` at **`0x16D213C`** initializes stocks through `Stock.JFEMFOPPBIL` at **`0x165957C`**. Observed `Stock.type` **1,2** and **location** 14/18/23/24/46/48/49.
- **Remaining work:** identify which asset/table/scene materializes these stocks, locate a *positioned* or equivalent safe scene-creation wrapper, identify manager type IDs and their asset names, and verify pickup/use/collision and cleanup in gameplay.
- Likely furniture/item counterpart from structural similarity and PC source, **but not yet category-verified in Android**.

### 4.3 Vehicle manager — independently unresolved

The original `World` type holds `gVehicle`, `vehiclePosition`, `vehicleTarget` and `vehicleAccel` fields; `World.LAPKJLMHCGE` at **`0x16A92FC`** updates indexed world state, but **has not been demonstrated to create vehicles**. Some car and motorcycle assets exist; **there is no verified numeric vehicle spawn ID or callable drivable-vehicle constructor**. Hold the Vehicle submenu in research/unavailable state until its own creation, physics, seat, wheel, collision and scene registration paths are resolved.

## 5. Categorized original-XAPK asset labels — complete audited extracts

The following **113** names were read from an audited group of serialized GameObject roots (not merely string blobs) in extracted `datapack.unity3d/resources.assets` near source offset **`0x406EEE4–0x40706C4`**. The following **35** were read from a separate contiguous region near **`0x4084054–0x40847C4`**. Exact offsets are from the **decompressed nested `resources.assets` file**, not the outer XAPK. The categories are **our proposed UI organization**, not an official decoded type taxonomy. A game may use a shovel as both tool and weapon. The numeric **source ordinal** below is **only the order encountered in this serialized name group**, emphatically **NOT an item ID, weapon ID, tool ID, furniture ID or vehicle ID**.

Items grouping counts: Weapons — ranged: 12; Weapons — melee / improvised: 24; Tools / equipment: 12; Food / drink: 17; Medicine / resources / consumables: 9; Sports / recreation: 9; Electronics / personal belongings: 11; Loose props / building parts: 19.

World grouping counts: Vehicle / mobility asset: 7; Furniture / fixtures: 19; World props / objects: 9.

**The 148 names also represent composite Unity root object hierarchies (138 have linked MeshFilter/Mesh descendants), NOT just audio labels or unstructured strings.** See section 0 for precise Unity PathID/component/mesh proof.

**All `Verified spawn ID` entries are intentionally `Unknown` until independently linked to the actual corresponding native factory type and observed in-game.** Especially: source ordinal **83 = Slingshot** does **not** establish factory type argument **83 = Slingshot**; those systems must not be conflated.

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

Other string searches found **`Bicycle`** and **`Train`** elsewhere, but **outside** this particular audited 35-name world group; their source context, usable prefab ownership and spawn IDs have not been fully decoded. The label **`Plane`** is ambiguous (it may refer to a mesh, shader or world element). Keep these in an **unmapped extras** subsection rather than presenting them as validated vehicles. No source asset label is evidence that an actual spawnable, controllable vehicle exists.

## 6. How to discover real numeric IDs — recommended evidence pipeline

**Do not brute-force thousands of IDs or automatically invoke unvalidated calls.** Instead, build an evidence-linked mapping:

1. From the existing embedded menu/backend, inspect a live **weapon/stock-manager collection** after the Game scene is fully initialized. Record each existing stock object's validated `type`, `variant`, `location`, registered index and class.
2. For the same registered object, resolve its actual Unity GameObject/mesh/prefab/sprite or other resource reference (where the engine exposes it) to a **human-readable asset label**. Record **native typeId → exact visible object name → factory → live scene**.
3. Repeat for the **second stock manager**, keeping its IDs in a **separate namespace**; identical numbers can mean different things in different factories.
4. Cross-check `Stock.type` with the factory's requested parameter and its runtime validation function. Observe creation, collision, persistence, pickup and disposal; don't call it proven on allocator success alone.
5. Create a build-specific verified mapping with fields such as `category`, `factory`, `typeId`, `displayName`, `sourceEvidence`, `verifiedInGame`, `interactable`, `testBuildHash`. Only publish to normal user-facing UI when `verifiedInGame=true`.
6. For food, medical and tools, use their native object/consumable behavior to classify. The presence of a picture or name in an asset bundle does not prove they use the same stock factory.
7. For vehicles, identify the **separate native creation and drivable physics registration method**. Do not attempt vehicle ID sweeps through stock/weapon/prop APIs.
8. Use the PC `MappedWeapons.Add(0)` and `MappedItems.Add(0)` only as **investigation hints** for separate manager paths and optional/random semantics. Android signatures and ID meanings must be independently verified against this XAPK.

**Suggested mapping evidence states:** `asset_name_only`, `native_argument_seen`, `manager_type_seen`, `factory_confirmed`, `scene_object_verified`, `pickup_usable_verified`. This prevents false “fully mapped” claims.

## 7. Integrate one Spawn section into the ALREADY WORKING embedded menu

**Do not rebuild the UI host, change the game's signing baseline without need, or replace the known-working command/binding bridge.** Extend the existing menu implementation in that other session:

```text
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
```

**State behavior:** The prior UI specification was to reopen at the **same category/editor** and retain unsaved input. The new Spawn section must follow the same rule (remember category, selection, placement, distance and any error/result message when the floating menu closes).

**Unmapped items:** A category list can be browsed and filtered immediately using the asset-label catalog, but `SPAWN` should be disabled on labels with unknown type IDs instead of guessing. Optionally have a separately labeled **developer diagnostic** that accepts a *specifically validated factory argument* (e.g. 83) for controlled first tests; do not misrepresent it as a named product.

**Minimal native command contract — architectural proposal, not a present method:**

```text
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
```

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
- `Stock.location=14/18/23/24/46/48/49` is not a catalog of seven furniture IDs.
- `Stock.type=1/2` from initializer is not sufficient for a named food/furniture mapping.
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

This research used the Library's **original XAPK**, verified its SHA-256, extracted the original ARM64 `libil2cpp.so` and IL2CPP v39 metadata, inspected real ARM64 disassembly, decoded field definitions and verified native field offsets, extracted `resources.assets` from the UnityFS `datapack.unity3d`, and enumerated the 148 above strings. Existing native factory analyses were cross-checked against this source. The external PC mod was used as a comparative **reference only**. The actual live APK and its functioning bridge remain in the other session's workspace.

**Canonical future document path:** `research/HT3_SPAWN_CATALOG_AND_INTEGRATION_HANDOFF.md`. Future findings should **update this same Markdown** in GitHub and clearly replace `Unknown` IDs only after evidence, instead of producing many conflicting handoff variants.
