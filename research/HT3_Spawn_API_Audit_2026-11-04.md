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
