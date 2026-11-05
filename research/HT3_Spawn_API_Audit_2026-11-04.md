# Hard Time III Android v1.1.8 — Spawn API research checkpoint
Date: 2026-11-04

## Scope and evidence
This audit uses the original uploaded Android `global-metadata.dat` and `libil2cpp.so`, the released PC `HardTimeKeybindCheats/Plugin.cs`, and earlier Android code-analysis notes. No emulator or in-game spawn was performed here. The GameGuardian menu is intentionally unchanged.

## Reproducible Android metadata findings
- Metadata format: IL2CPP v39.
- The first game assembly contains 2,004 indexed methods; see `HT3_Android_Method_Inventory.csv` in the downloadable audit.
- `IFCBDBGCKJA.CGLILJCFENK`: type-definition index **24**, method-definition index **273**, metadata token **0x06000112**, **6 explicit parameters** (parameter-definition start 251).
- This metadata entry was recovered directly from the uploaded file. Its native function pointer/calling convention/return type and actual behavior have **not** been verified by codegen registration cross-reference.
- Previous static analysis nominated it as a positioned-weapon creation candidate on matching parameter shape, but a matching count does not establish a matching factory.
- `Stock`: type-definition index **66**, world-object record with `id`, `type`, `variant`, `location`, and coordinates.
- `World`: type-definition index **134**, vehicle-related fields; no verified vehicle factory yet.
- `SaveData.stockFurniture` and `SaveData.stockWeapons` are persistent references, not automatically valid constructors.

## Independently inspected PC reference
Published project: https://github.com/IngoHHacks/HardTimeKeybindCheats/blob/main/Plugin.cs

- In the `Game` scene, `MappedWeapons.Add(0)` is called for random weapon creation; with Ctrl, `MappedItems.Add(0)` is called for random furniture/item creation (lines 276-286 at the version inspected).
- `MappedWeapons.Produce(83, x, y, z, rotation, scale)` and `MappedWeapons.Produce(Rnd(88,91), x, y, z, rotation, scale)` are invoked from a dismemberment effect (lines 129-143). These are verified arguments in **PC source**, not validated Android IDs or generalized weapons.
- `Add`'s underlying compiled signature may contain optional parameters not shown in source; a one-parameter call must not be assumed.
- Separate scene-conditions, object bookkeeping, position initialization, and destroy/cleanup logic must be traced in native Android.

## Work steps and status
| Requested gate | Offline result | Still necessary |
|---|---|---|
| 1. Weapon creation native method/call chain | **Partial**: narrowed metadata identity and 79 potential stock/scene candidates in the selected class sample; no proven Android method pointer or factory semantics | Correlate registration pointer with token, disassemble actual method, inspect callers and registration |
| 2. At least one weapon and furniture ID | **PC-only seeds**: `0` (random argument); `83`, `88–91` (PC Produce calls); **zero Android-verified IDs** | Trace ID selection and validated item tables in Android |
| 3. Spawn and usability verification | **Blocked**: offline XAPK cannot establish Unity scene runtime | GameGuardian or integrated Android hook observes materialization, pickup/use, collision, cleanup |
| 4. Food, tools and resources | **Metadata/asset strings only**, not verified ID mapping | Trace stock type/variant and factories |
| 5. Vehicles | `World` vehicle fields identified, **factory unresolved** | Analyze independent vehicle-instantiation pathway |

## Important implementation boundary
A GameGuardian memory address/value editor does not inherently call arbitrary ARM64 IL2CPP methods. It is unsafe to turn guessed method pointers/IDs into menu actions. Once the actual creation method and ID table are resolved, either a verified existing in-game creation trigger must be driven through GG, or a developer-approved native bridge integrated in the APK is required. Do not treat item names or saved Stock records as executable spawn calls.

## Next offline reverse-engineering steps
1. Decode game image registration method pointer lookup, not metadata method indices as executable addresses.
2. Resolve the native body and caller set of `IFCBDBGCKJA.CGLILJCFENK` and rival stock managers.
3. Trace the complete `Add`/produce/registration sequence to scene objects and numeric type tables, including ID bounds and position initialization.
4. Export verified Android IDs and signatures separately from PC-only candidates.

## Project files
- Original Android XAPK uploaded in chat; extracted `global-metadata.dat`, `libil2cpp.so`.
- `HT3_Android_Method_Inventory.csv` and `HT3_Spawn_Candidate_Inventory.csv` generated in this turn.
- No gameplay test, spawn execution, or APK edit claimed.

## Native follow-up: registration and actual callers (supersedes earlier 'unresolved pointer')
A subsequent direct binary trace **resolved** the method pointers using the `Assembly-CSharp.dll` codegen module:
- String virtual address `0x74E1B1`; image codegen module at `0x3087018`.
- Module declares **2,004** method slots; relocated native method-pointer table at **`0x3240EF0`**.
- `IFCBDBGCKJA.CGLILJCFENK` / token `0x06000112` / index 273 → **RVA `0x1530160`**.
- `IFCBDBGCKJA.HBALMHCPLKM` / token `0x06000101` / index 256 → **RVA `0x1526114`**.
- `IFCBDBGCKJA.AKKIOODJGNM` / token `0x0600010F` / index 270 → **RVA `0x152604C`**.
- `Stock.LDOCDJOFJCN` / token `0x06000467` / index 1126 → **RVA `0x1659270`**.

Native execution path in static disassembly:
1. At `0x15301D8`, the positioned method calls `0x1526114` with `(type, 0)`, receiving a managed stock index.
2. It checks bounds/index and follows the manager's object pointer array.
3. At `0x1530228` and `0x153023C`–`0x1530258`, it writes three position floats, orientation, and scale-related values into the selected object. It returns the chosen index.
4. `0x1526114` checks whether a type is allowed, creates/extends the manager's object array, adjusts its length/count, and initializes an object. It is the actual creation/registration layer, not merely a metadata match.
5. `0x152604C` checks the incoming type and dynamic stock count; its comparisons include `0x48` (72) and additional conditional branches. This is not a proof that all integers from 1 to any one hardcoded maximum are usable.

**Actual Android call-site evidence of numeric inputs:**
- `GDICAFINBED.IBIlCPMOIKN` (method index 1617, token `0x06000652`) at **`0x16F4F74`** and **`0x16F4FAC`** loads integer **83** immediately before calling `0x1530160` at **`0x16F4F8C`** and **`0x16F4FC4`**.
- At **`0x16F4FC8`** it passes **88** and **91** to the range-selection function `0x1679BBC`, then passes the selected return as the first parameter to `0x1530160` at **`0x16F5020`**.
- The actor caller `EFPJKAPKGOB.CKHFEGNHFJP` similarly uses **83** and a selected **88–91** in its two direct calls to `0x1530160` at `0x15A97A8` and `0x15A9858`.
- These Android native ID arguments match the same numbers in the independent PC mod. **83 and the 88–91 range are statically verified Android spawn arguments**. Their visible object labels, pickup/usage and exact effects still need actual runtime confirmation. They must not be relabeled as a general weapon catalog without that evidence.
- Eight direct native call sites for `CGLILJCFENK` were observed, belonging to those two identified caller methods. This establishes the genuine factory/caller path.

### Revised requested gate 1 and gate 2
Gate 1: **static factory + native call chain resolved** for positioned weapon/stock creation. Directly invoking it from GG remains unresolved. Gate 2: **Android code-confirmed argument values 83 and 88–91**, and **PC-only argument 0** for random Add; **furniture ID still unresolved**. No in-game spawn or pickup result has been claimed.


## Continued investigation: second stock manager and World path

### Separate furniture/item-style stock manager — native evidence
The Android class `CAIHMLHBPMF` (type index 136) implements its **own** parallel allocation routine:
- `CAIHMLHBPMF.HBALMHCPLKM(int,int)`, method index 1535, native RVA **`0x16D1B9C`**.
- It calls `CAIHMLHBPMF.LEHNPLAAMMJ` RVA **`0x16D1ED8`** at `0x16D1C44`, uses a manager-owned count and pointer array, allocates an object (`0x25BB12C`), and registers it.
- Direct callers are `CAIHMLHBPMF.HNABEHOCBNL` at RVA **`0x16C56A8`** and `CAIHMLHBPMF.APJMFPMAMOC` at **`0x16C5838`**.
- In the first caller, `mov w0,wzr` and `mov w1,w19` directly precede the call; the second caller loads `w0` from manager static `+0xC` and sets `w1=0`. These prove real call argument patterns **(0, loop-index)** and **(manager-defined type, 0)**; they do not establish that zero alone is a valid object ID.
- `CAIHMLHBPMF.MGABOLMHDLK` RVA `0x16D213C` initializes stock entries. Its body repeatedly calls `Stock.JFEMFOPPBIL` RVA `0x165957C` after allocating/registering a `Stock` object. One explicit call sets `w1=2`, `w2=14` and float placements, with fourteen additional stock initialization callsites. Those two integers are **not yet interpreted as item IDs**.

This is a **strong second stock-manager candidate**, likely the PC furniture/item counterpart, but category ownership has not been conclusively proven from the disassembly. Resolving manager static field ownership, its type table, and game-scene registration remains.

### Vehicle / World disambiguation
- `World.LAPKJLMHCGE` method index 1471, native RVA **`0x16A92FC`** takes five explicit parameters and has 11 direct callers.
- Native disassembly shows it checks a World static count at `+0x264`, resolves a selected index, calls `World.IJGNLIJACNN` RVA `0x16A966C`, and updates World static arrays at `+0x2A8` and `+0x2B0`. The adjacent method contains coordinate/position-dependent checks.
- This is **a World index/position update path, not a confirmed vehicle-instantiation function**. Do not present its indices as vehicle IDs.
- Vehicle model names in the asset bundle remain labels; the vehicle constructor, driving physics registration, and entity activation are unresolved.

### Implications for next validation
The source XAPK establishes at least **two separate object-allocation managers**, and numeric native weapon-factory arguments 83 and 88–91. No GameGuardian-only mechanism has yet been shown to call either native factory. A GG user test should be deferred until an executable in-game trigger is identified, or a developer native bridge is available; probing untyped memory addresses would not validate spawning.

## Execution-gate follow-up
Direct ARM64 inspection confirms CAIHMLHBPMF.HBALMHCPLKM (0x16D1B9C) calls CAIHMLHBPMF.LEHNPLAAMMJ (0x16D1ED8) with w0=0 and w1=requested type, allocates a managed object (0x25BB12C), and registers the result in its manager array. LEHNPLAAMMJ scans entries and handles zero/automatic selection differently from explicit indexing (0x16D1F3C–0x16D1FA8). This establishes a real allocator path but not a labeled furniture type or safe GG execution trigger.

Decision: no ready GG spawn test can be justified from static addresses alone. Need verified existing in-game creation trigger or authorized native APK bridge with Unity execution context. Writing Stock arrays is not equivalent to running factory logic. Conversation artifacts HT3_Spawn_Trigger_Gate_2026-11-04.md and HT3_Spawn_Trigger_Gate_Evidence.zip preserve reproducible evidence. The GG menu and installed game were not changed.

## Second-manager type/location mapping (2026-11-04)
Direct disassembly of `Stock.JFEMFOPPBIL` token `0x06000468`, RVA `0x165957C`, establishes argument meanings:
- `w1` writes to `Stock.type +0x14` at RVA `0x1659620`.
- `w2` writes to `Stock.location +0x2C` at RVA `0x16595E4`.
- The second manager initializer `CAIHMLHBPMF.MGABOLMHDLK` at RVA `0x16D213C` includes **15** calls with `Stock.type=1 or 2` and `Stock.location=14,18,23,24,46,48,49`. These location integers are NOT item IDs. Exact callsite/argument map exported as `HT3_Second_Manager_Stock_Init_Arguments.csv`.
- `CAIHMLHBPMF.AKKIOODJGNM`, RVA `0x16D1B94`, returns constant 1. `CAIHMLHBPMF.FLIJBGEJEID`, RVA `0x16D1AF4`, chooses values based on live manager range when a type is not specified. Neither behavior identifies a catalog of item names.
- The manager registers `Stock` objects; precise gameplay category (furniture vs other world-stock) remains unproven without tracing the resource materialization/scene-owned reference.

### Safe native invocation contract
A secure, developer-authorized implementation should queue `SpawnRequest(category, type_id, coordinates, heading, scale, request_id)` on the Unity main thread, verify Game scene and initialized IL2CPP manager, invoke the exact build-matched native factory with its real ABI, and return a `SpawnResult` only after checking the created index and registered scene object. Use type 83 solely as the first Android-code-confirmed *weapon argument*, not as a named inventory item. Avoid broad arbitrary native calls and blind `Stock` writes. An authorized Unity-side development build is preferable to an unverified injected bridge; earlier injected builds failed startup with native crashes. A **bridge design is documented**, but no working binary, dispatch integration, or successful spawn has been claimed.
